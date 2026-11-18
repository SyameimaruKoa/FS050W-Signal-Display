package com.syameimarukoa.fs050w_signal_display.data

import com.syameimarukoa.fs050w_signal_display.domain.model.AppSettings
import com.syameimarukoa.fs050w_signal_display.domain.util.CryptoUtils
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.util.concurrent.TimeUnit

enum class ConnectionStatus { DISCONNECTED, CONNECTING, AUTHENTICATED, UNAUTHENTICATED_MODE, ERROR }

sealed interface PollOutcome {
    data class Success(
        val params: JSONObject,
        val deviceState: JSONObject?,
        val latencyMs: Int?,
    ) : PollOutcome

    data class Failure(val message: String, val connecting: Boolean) : PollOutcome
}

/** Port of ApiService: session handling, challenge-response login and router polling. */
class RouterApi(initialSettings: AppSettings) {
    private val client = OkHttpClient.Builder()
        .callTimeout(4, TimeUnit.SECONDS)
        .connectTimeout(4, TimeUnit.SECONDS)
        .readTimeout(4, TimeUnit.SECONDS)
        .build()

    var settings: AppSettings = initialSettings
        private set

    var status: ConnectionStatus = ConnectionStatus.DISCONNECTED
        private set

    var errorMessage: String? = null
        private set

    var isLoggedIn: Boolean = false
        private set

    var lastLatencyMs: Int? = null
        private set

    val isLockedOut: Boolean
        get() {
            val until = lockoutUntil ?: return false
            return System.currentTimeMillis() < until
        }

    val lockoutRemainingSeconds: Int
        get() {
            val until = lockoutUntil ?: return 0
            return ((until - System.currentTimeMillis()) / 1000).toInt().coerceIn(0, 999)
        }

    private var csrfToken: String? = null
    private var sessionCookie: String? = null
    private var prikey: String? = null
    private var closing = false
    private var consecutiveErrorCount = 0
    private var consecutiveLoginFailures = 0
    private var lastLoginAttempt: Long? = null
    private var lockoutUntil: Long? = null
    private var lastIp: String = initialSettings.routerIp
    private var lastPassword: String = initialSettings.webPassword

    fun updateSettings(newSettings: AppSettings) {
        val changed = lastIp != newSettings.routerIp || lastPassword != newSettings.webPassword
        settings = newSettings
        lastIp = newSettings.routerIp
        lastPassword = newSettings.webPassword
        if (changed) {
            resetSession()
            consecutiveErrorCount = 0
            lastLoginAttempt = null
            lockoutUntil = null
        }
    }

    private fun resetSession() {
        csrfToken = null
        sessionCookie = null
        prikey = null
        isLoggedIn = false
        lastLoginAttempt = null
    }

    suspend fun testConnection(ip: String, password: String): Boolean = io {
        try {
            val base = "http://$ip"
            val tokenResponse = executeBlocking(Request.Builder().url("$base/goform/x_csrf_token").get().build())
            tokenResponse.use { response ->
                if (response.code != 200) {
                    false
                } else {
                    val csrf = response.header("x-csrf-token")
                    val cookie = response.headers("set-cookie").firstOrNull()?.substringBefore(";").orEmpty()
                    val headers = mutableMapOf<String, String>()
                    if (!csrf.isNullOrEmpty()) headers["X-Csrf-Token"] = csrf
                    if (cookie.isNotEmpty()) headers["Cookie"] = cookie
                    val body = JSONObject()
                        .put("keys", org.json.JSONArray().put("mnet_sysmode").put("mnet_rsrp"))
                        .toString()
                    val paramResponse = postBlocking("$base/goform/get_mgdb_params", headers, body)
                    paramResponse.use { param ->
                        if (param.code != 200) true
                        else JSONObject(param.body?.string().orEmpty()).optInt("retcode") == 0
                    }
                }
            }
        } catch (_: Exception) {
            false
        }
    }

    suspend fun logout() {
        if (closing) return
        closing = true
        val csrf = csrfToken
        val cookie = sessionCookie
        val wasLoggedIn = isLoggedIn
        val ip = settings.routerIp
        resetSession()
        status = ConnectionStatus.DISCONNECTED
        if (!wasLoggedIn || csrf == null || cookie == null || ip.isEmpty()) return
        try {
            post("http://$ip/action/logout", mapOf("X-Csrf-Token" to csrf, "Cookie" to cookie), "{}").use { response ->
                if (response.code != 200) AppLogger.warn("Logout request returned status ${response.code}")
                else AppLogger.info("Logged out from router: session closed")
            }
        } catch (e: Exception) {
            AppLogger.warn("Logout request failed: ${e.message}")
        }
    }

    suspend fun pollOnce(): PollOutcome {
        if (closing) return PollOutcome.Failure("Router client is closing", false)
        return try {
            val ip = settings.routerIp
            if (ip.isEmpty()) {
                status = ConnectionStatus.DISCONNECTED
                errorMessage = "ルーターIPが未設定です (設定画面で入力してください)"
                return PollOutcome.Failure(errorMessage!!, false)
            }

            if (csrfToken == null || sessionCookie == null) {
                if (consecutiveErrorCount >= 2) {
                    status = ConnectionStatus.CONNECTING
                }
                if (!fetchCsrfToken(ip)) {
                    return handleFailure("ルーター ($ip) に接続できません")
                }
            }

            val hasPassword = settings.webPassword.isNotEmpty()
            if (hasPassword && !isLoggedIn) {
                val now = System.currentTimeMillis()
                if (isLockedOut) {
                    isLoggedIn = false
                    status = ConnectionStatus.UNAUTHENTICATED_MODE
                    errorMessage = "ルーター一時ロック中 (残り ${lockoutRemainingSeconds} 秒)"
                } else {
                    if (lockoutUntil != null) {
                        lockoutUntil = null
                        csrfToken = null
                        sessionCookie = null
                        if (!fetchCsrfToken(ip)) return handleFailure("ルーター ($ip) に接続できません")
                    }
                    val canAttempt = lastLoginAttempt == null || now - lastLoginAttempt!! >= 5000
                    if (canAttempt) {
                        lastLoginAttempt = now
                        AppLogger.info("Attempting authentication with router ($ip)...")
                        if (performLogin(ip)) {
                            isLoggedIn = true
                            status = ConnectionStatus.AUTHENTICATED
                            errorMessage = null
                            consecutiveLoginFailures = 0
                            AppLogger.info("Authentication succeeded: Full parameter mode active")
                        } else {
                            isLoggedIn = false
                            consecutiveLoginFailures++
                            status = ConnectionStatus.UNAUTHENTICATED_MODE
                            if (consecutiveLoginFailures >= 3 && !isLockedOut) {
                                errorMessage = "ログイン認証に失敗しました (パスワードを確認してください)"
                            }
                            AppLogger.warn("Login failed (attempt #$consecutiveLoginFailures). Falling back to unauthenticated mode.")
                        }
                    }
                }
            } else if (!hasPassword) {
                isLoggedIn = false
                status = ConnectionStatus.UNAUTHENTICATED_MODE
            }

            var params = fetchParams(ip)
            if (params == null && isLoggedIn) {
                AppLogger.warn("Authenticated fetch failed. Resetting session and retrying login once...")
                resetSession()
                if (fetchCsrfToken(ip)) {
                    isLoggedIn = performLogin(ip)
                    params = fetchParams(ip)
                }
            }
            if (params == null && csrfToken != null) {
                isLoggedIn = false
                params = fetchParams(ip)
            }

            if (params != null) {
                consecutiveErrorCount = 0
                if (isLoggedIn) errorMessage = null
                val deviceState = if (isLoggedIn) fetchDeviceState(ip) else null
                status = if (isLoggedIn) ConnectionStatus.AUTHENTICATED else ConnectionStatus.UNAUTHENTICATED_MODE
                PollOutcome.Success(params, deviceState, lastLatencyMs)
            } else {
                handleFailure()
            }
        } catch (e: Exception) {
            handleFailure(e.message ?: "Unknown error")
        }
    }

    private fun handleFailure(message: String = "ルーターからのデータ取得に失敗しました (自動再試行中)"): PollOutcome.Failure {
        consecutiveErrorCount++
        errorMessage = message
        val connecting = consecutiveErrorCount >= 3
        if (connecting) status = ConnectionStatus.CONNECTING
        return PollOutcome.Failure(message, connecting)
    }

    private suspend fun fetchCsrfToken(ip: String): Boolean {
        for (endpoint in listOf("/goform/x_csrf_token", "/public/x_csrf_token")) {
            try {
                execute(Request.Builder().url("http://$ip$endpoint").get().build()).use { response ->
                    if (response.code == 200) {
                        updateHeaders(response)
                        if (csrfToken != null && sessionCookie != null) {
                            AppLogger.debug("CSRF token fetched successfully via $endpoint")
                            return true
                        }
                    }
                }
            } catch (e: Exception) {
                AppLogger.warn("Failed to reach $endpoint: ${e.message}")
            }
        }
        return false
    }

    private suspend fun performLogin(ip: String): Boolean {
        val csrf = csrfToken ?: return false
        val cookie = sessionCookie ?: return false
        try {
            val prikeyResponse = post(
                "http://$ip/goform/get_private_key",
                mapOf("X-Csrf-Token" to csrf, "Cookie" to cookie),
                "{}",
            )
            prikeyResponse.use { response ->
                if (response.code != 200) return false
                updateHeaders(response)
                val json = JSONObject(response.body?.string().orEmpty())
                val key = json.opt("prikey")?.toString()
                if (key.isNullOrEmpty()) return false
                prikey = key
            }

            val hashed = CryptoUtils.computeLoginPasswordHash(settings.webPassword, prikey!!)
            val body = JSONObject()
                .put("username", CryptoUtils.USERNAME)
                .put("password", hashed)
                .put("prikey", prikey)
                .toString()
            val loginResponse = post(
                "http://$ip/goform/login2",
                mapOf("X-Csrf-Token" to csrfToken!!, "Cookie" to sessionCookie!!),
                body,
            )
            loginResponse.use { response ->
                if (response.code == 200) {
                    updateHeaders(response)
                    val json = JSONObject(response.body?.string().orEmpty())
                    val retcode = json.optInt("retcode")
                    if (retcode == 0) {
                        lockoutUntil = null
                        return true
                    }
                    val remainSecs = json.opt("remain_secs")?.toString()?.toIntOrNull() ?: 0
                    val remainTimes = json.opt("remain_times")?.toString()?.toIntOrNull() ?: 0
                    if (remainSecs > 0) {
                        lockoutUntil = System.currentTimeMillis() + (remainSecs + 1) * 1000L
                        AppLogger.warn("FS050W router temporary lockout active (${remainSecs}s remaining, $remainTimes attempts left)")
                    } else {
                        AppLogger.warn("Login rejected by router (retcode: $retcode, remain_times: $remainTimes)")
                    }
                }
            }
        } catch (e: Exception) {
            AppLogger.warn("Exception during login: ${e.message}")
        }
        return false
    }

    private suspend fun fetchDeviceState(ip: String): JSONObject? {
        val headers = authHeaders()
        return try {
            post("http://$ip/action/get_device_state", headers, "{}").use { response ->
                val body = response.body?.string().orEmpty()
                if (response.code == 200 && !body.startsWith("<!DOCTYPE")) {
                    updateHeaders(response)
                    val json = JSONObject(body)
                    if (json.optInt("retcode") == 0) {
                        val data = json.opt("data")
                        if (data is JSONObject) data else json
                    } else null
                } else null
            }
        } catch (e: Exception) {
            AppLogger.warn("Network error on /action/get_device_state: ${e.message}")
            null
        }
    }

    private suspend fun fetchParams(ip: String): JSONObject? {
        val keys = org.json.JSONArray().apply { kValidParamKeys.forEach { put(it) } }
        val body = JSONObject().put("keys", keys).toString()

        if (isLoggedIn) {
            try {
                val headers = authHeaders()
                val start = System.currentTimeMillis()
                val response = post("http://$ip/action/get_mgdb_params", headers, body)
                response.use { resp ->
                    lastLatencyMs = (System.currentTimeMillis() - start).toInt()
                    val text = resp.body?.string().orEmpty()
                    if (resp.code == 200 && !text.startsWith("<!DOCTYPE")) {
                        updateHeaders(resp)
                        val json = JSONObject(text)
                        if (json.optInt("retcode") == 0) {
                            val data = json.opt("data")
                            return if (data is JSONObject) data else json
                        }
                    } else if (resp.code == 401 || resp.code == 403 || text.startsWith("<!DOCTYPE")) {
                        AppLogger.warn("Authenticated session expired (status: ${resp.code})")
                        isLoggedIn = false
                        return null
                    }
                }
            } catch (e: Exception) {
                AppLogger.warn("Network error on /action/get_mgdb_params: ${e.message}")
                return null
            }
        }

        for (endpoint in listOf("/public/get_mgdb_params", "/goform/get_mgdb_params", "/action/get_mgdb_params")) {
            try {
                val start = System.currentTimeMillis()
                val response = post("http://$ip$endpoint", authHeaders(), body)
                response.use { resp ->
                    lastLatencyMs = (System.currentTimeMillis() - start).toInt()
                    val text = resp.body?.string().orEmpty()
                    if (resp.code == 200 && !text.startsWith("<!DOCTYPE")) {
                        updateHeaders(resp)
                        val json = JSONObject(text)
                        if (json.optInt("retcode") == 0) {
                            val data = json.opt("data")
                            return if (data is JSONObject) data else json
                        }
                    }
                }
            } catch (e: Exception) {
                AppLogger.warn("Network error on $endpoint: ${e.message}")
            }
        }
        return null
    }

    private fun authHeaders(): Map<String, String> = buildMap {
        put("Content-Type", "application/json")
        csrfToken?.let { put("X-Csrf-Token", it) }
        sessionCookie?.let { put("Cookie", it) }
    }

    private fun updateHeaders(response: okhttp3.Response) {
        response.header("x-csrf-token")?.takeIf { it.isNotEmpty() }?.let { csrfToken = it }
        val cookies = response.headers("set-cookie")
        // Prefer the router's session cookie across all Set-Cookie headers. Other
        // cookies (tracking, login-page hints) must not overwrite the session.
        val session = cookies.mapNotNull { Regex("-webs-session-=[^;]+").find(it)?.value }.firstOrNull()
        if (session != null) {
            sessionCookie = session
        } else if (sessionCookie == null) {
            sessionCookie = cookies.firstOrNull()?.substringBefore(";")
        }
    }

    private suspend fun post(url: String, headers: Map<String, String>, body: String): okhttp3.Response = io {
        postBlocking(url, headers, body)
    }

    private fun postBlocking(url: String, headers: Map<String, String>, body: String): okhttp3.Response {
        val builder = Request.Builder().url(url)
        headers.forEach { (key, value) -> builder.header(key, value) }
        return executeBlocking(builder.post(body.toRequestBody(JSON_MEDIA_TYPE)).build())
    }

    private suspend fun execute(request: Request): okhttp3.Response = io { executeBlocking(request) }

    private fun executeBlocking(request: Request): okhttp3.Response = client.newCall(request).execute()

    private suspend inline fun <T> io(crossinline block: () -> T): T = withContext(Dispatchers.IO) { block() }

    companion object {
        private val JSON_MEDIA_TYPE = "application/json; charset=utf-8".toMediaType()

        private val kValidParamKeys = listOf(
            "mnet_rsrp", "mnet_rssi", "mnet_rsrq", "mnet_sinr", "mnet_snr",
            "mnet_wnw_pci", "mnet_wnw_band", "mnet_wnw_pspci", "mnet_wnw_psband",
            "mnet_endc_rsrp", "mnet_endc_snr", "mnet_endc_rsrq", "mnet_sysmode",
            "mnet_sig_level_num", "mnet_operator_name", "mnet_acqorder",
            "wifi_state_0", "wifi_freq_0", "wifi_5g_sub_freq", "wifi_client_0", "wifi_work_status",
            "device_battery_level_percent", "device_battery_exist", "device_battery_level",
            "device_battery_capacity", "device_battery_current", "device_battery_temperature",
            "device_battery_voltage", "device_battery_charge_status", "device_charge_long_life",
            "battery_percent", "battery_charging",
        )
    }
}
