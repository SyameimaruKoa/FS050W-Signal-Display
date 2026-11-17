package com.syameimarukoa.fs050w_signal_display.domain.model

import org.json.JSONObject
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.util.Locale
import kotlin.math.abs
import kotlin.math.roundToInt

private val LOCALE_ROOT: Locale = Locale.ROOT
private val TIME_FORMATTER: DateTimeFormatter = DateTimeFormatter.ofPattern("HH:mm:ss.SSS")

/** Parsed router snapshot. Mirrors the Flutter SignalData model and its dBm conversions. */
data class SignalData(
    val timestamp: LocalDateTime = LocalDateTime.now(),
    val sysmode: String = "lte",
    val operatorName: String = "--",

    val lteRsrp: Double? = null,
    val lteRssi: Double? = null,
    val lteRsrq: Double? = null,
    val lteSinr: Double? = null,
    val lteBand: Int? = null,
    val ltePci: Int? = null,

    val nrRsrp: Double? = null,
    val nrRsrq: Double? = null,
    val nrSnr: Double? = null,
    val nrBand: Int? = null,
    val nrPci: Int? = null,

    val batteryPercent: Int? = null,
    val isCharging: Boolean = false,
    val batteryLevel: Int? = null,
    val batteryCapacity: Int? = null,
    val batteryCurrent: Int? = null,
    val isBatteryPresent: Boolean = true,
    val batteryTemperature: Double? = null,
    val batteryVoltage: Double? = null,
    val batteryChargeStatus: String? = null,
    val isLongLifeCharging: Boolean = false,

    val uptimeSeconds: Int? = null,
    val totalRamBytes: Int? = null,
    val usageRamBytes: Int? = null,
    val freeRamBytes: Int? = null,
    val cpuUsagePercent: Int? = null,
    val processCount: Int? = null,

    val connectionMode: Fs050wConnectionMode = Fs050wConnectionMode.DISCONNECTED,
    val isSa: Boolean = false,
    val handoverDescription: String? = null,

    val routerLatencyMs: Int? = null,
    val preferNetMode: String? = null,
    val wifiState: String? = null,
    val wifiFreq: String? = null,
    val wifiSubFreq: String? = null,
    val wifiClientCount: Int? = null,
    val wifiWorkStatus: String? = null,
) {
    val is5gDisabledByConfig: Boolean
        get() = preferNetMode != null && preferNetMode!!.isNotEmpty() &&
            !preferNetMode!!.lowercase().contains("5g")

    val isWifiEnabled: Boolean
        get() = wifiState == "ap_enable" || (wifiWorkStatus == "open" && wifiState != "ap_disable")

    val wifiFreqDisplay: String
        get() = when (wifiFreq) {
            "5g" -> {
                val sub = if (!wifiSubFreq.isNullOrEmpty()) " (${wifiSubFreq!!.uppercase()})" else ""
                "5GHz$sub"
            }
            "2.4g" -> "2.4GHz"
            else -> wifiFreq ?: "--"
        }

    val scaledBatteryPercent: Int?
        get() {
            val percent = batteryPercent ?: return null
            return if (isLongLifeCharging) ((percent / 70.0) * 100).roundToInt() else percent
        }

    val batteryPercentDisplay: String
        get() {
            if (!isBatteryPresent) return "--"
            val percent = batteryPercent ?: return "--"
            return if (isLongLifeCharging) "$scaledBatteryPercent% (実$percent%)" else "$percent%"
        }

    val remainingTimeHHMM: String?
        get() {
            if (!isBatteryPresent || batteryPercent == null) return null
            val cap = batteryCapacity ?: return null
            val current = batteryCurrent ?: return null
            if (abs(current.toDouble()) <= 30) return null
            val target = if (isLongLifeCharging) 70 else 100
            val minutes: Int
            if (isCharging) {
                if (batteryPercent!! >= target) return null
                val remainingMah = (cap * ((target - batteryPercent!!) / 100.0)).roundToInt()
                if (current <= 0) return null
                val effective = current.coerceIn(1, 1000)
                minutes = ((remainingMah / effective.toDouble()) * 60).roundToInt()
            } else {
                val remainingMah = (cap * (batteryPercent!! / 100.0)).roundToInt()
                minutes = ((remainingMah / abs(current.toDouble())) * 60).roundToInt()
            }
            if (minutes <= 0) return null
            val hours = minutes / 60
            val mins = minutes % 60
            return "$hours:${mins.toString().padStart(2, '0')}"
        }

    val estimatedTimeDisplay: String
        get() {
            if (!isBatteryPresent || batteryPercent == null) return "--"
            val cap = batteryCapacity
            val current = batteryCurrent
            val target = if (isLongLifeCharging) 70 else 100
            if (cap != null && current != null && abs(current.toDouble()) > 30) {
                val minutes: Int
                if (isCharging) {
                    if (batteryPercent!! >= target) return "充電完了"
                    val remainingMah = (cap * ((target - batteryPercent!!) / 100.0)).roundToInt()
                    if (current <= 0) return "充電完了"
                    minutes = ((remainingMah / current.coerceIn(1, 1000).toDouble()) * 60).roundToInt()
                    if (minutes <= 0) return "充電完了"
                } else {
                    val remainingMah = (cap * (batteryPercent!! / 100.0)).roundToInt()
                    minutes = ((remainingMah / abs(current.toDouble())) * 60).roundToInt()
                    if (minutes <= 0) return "--"
                }
                val hours = minutes / 60
                val mins = minutes % 60
                return if (hours > 0) "約 ${hours}時間${mins}分" else "約 ${mins}分"
            }
            return if (isCharging) {
                if (batteryPercent!! >= target) "充電完了" else "充電中..."
            } else {
                "バッテリー駆動中"
            }
        }

    val formattedUptime: String
        get() {
            val sec = uptimeSeconds ?: return "--"
            val days = sec / 86400
            val hours = (sec % 86400) / 3600
            val mins = (sec % 3600) / 60
            val secs = sec % 60
            return when {
                days > 0 -> "$days日 $hours時間 $mins分"
                hours > 0 -> "$hours時間 $mins分 $secs秒"
                else -> "$mins分 $secs秒"
            }
        }

    val formattedRamUsage: String
        get() {
            val used = usageRamBytes ?: return "--"
            val total = totalRamBytes ?: return "--"
            if (total == 0) return "--"
            val usedMb = (used / 1048576.0).roundToInt()
            val totalMb = (total / 1048576.0).roundToInt()
            val percent = (used / total.toDouble()) * 100
            return "$usedMb MB / $totalMb MB (${"%.1f".format(LOCALE_ROOT, percent)}%)"
        }

    companion object {
        fun formatTime(time: LocalDateTime): String = time.format(TIME_FORMATTER)

        fun normalizeOperatorName(raw: String): String {
            val trimmed = raw.trim()
            val clean = trimmed.replace(" ", "")
            return when (clean) {
                "44011", "44053" -> "Rakuten"
                "44010", "44001" -> "NTT DOCOMO"
                "44050", "44051", "44052", "44054" -> "au"
                "44020", "44000" -> "SoftBank"
                else -> if (trimmed.isEmpty()) "--" else trimmed
            }
        }

        fun fromApiResponse(
            json: JSONObject,
            deviceStateJson: JSONObject? = null,
            previousData: SignalData? = null,
            adjust5gSnr: Boolean = true,
            routerLatencyMs: Int? = null,
        ): SignalData {
            val rawMap = if (json.has("data") && json.opt("data") is JSONObject) json.getJSONObject("data") else json
            val sysmode = (optString(rawMap, "mnet_sysmode") ?: previousData?.sysmode ?: "lte").lowercase()
            val isSa = sysmode == "nr5g"
            val rawOp = optString(rawMap, "mnet_operator_name")
                ?: optString(rawMap, "operator_name")
                ?: optString(rawMap, "sim_spn")
                ?: previousData?.operatorName
                ?: "--"
            val operatorName = normalizeOperatorName(
                if (rawOp == "--" && previousData != null && previousData.operatorName != "--") previousData.operatorName else rawOp
            )

            val rawLteRsrp = parseInt(rawMap, "mnet_rsrp")
            val rawLteRssi = parseInt(rawMap, "mnet_rssi")
            val rawLteRsrq = parseInt(rawMap, "mnet_rsrq")
            val lteSinrVal = parseDouble(rawMap, "mnet_sinr")
            val lteBandVal = parseBand(rawMap, "mnet_wnw_band")
            val ltePciVal = parseInt(rawMap, "mnet_wnw_pci")

            val rawEndcRsrp = parseInt(rawMap, "mnet_endc_rsrp")
            val rawEndcRsrq = parseInt(rawMap, "mnet_endc_rsrq")
            val rawEndcSnr = parseInt(rawMap, "mnet_endc_snr")
            val endcBandVal = parseBand(rawMap, "mnet_wnw_psband")
            val endcPciVal = parseInt(rawMap, "mnet_wnw_pspci")

            var lteRsrp: Double? = null
            var lteRssi: Double? = null
            var lteRsrq: Double? = null
            var lteSinr: Double? = null
            var lteBand: Int? = null
            var ltePci: Int? = null
            var nrRsrp: Double? = null
            var nrRsrq: Double? = null
            var nrSnr: Double? = null
            var nrBand: Int? = null
            var nrPci: Int? = null

            if (isSa) {
                nrRsrp = if (rawLteRsrp != null) rawLteRsrp - 157.0
                else if (rawEndcRsrp != null && rawEndcRsrp > 0) rawEndcRsrp - 157.0
                else previousData?.nrRsrp

                nrRsrq = if (rawLteRsrq != null) ((rawLteRsrq - 1.0) / 2.0) - 43.0
                else if (rawEndcRsrq != null && rawEndcRsrq > 0) ((rawEndcRsrq - 1.0) / 2.0) - 43.0
                else previousData?.nrRsrq

                nrSnr = lteSinrVal
                    ?: if (rawEndcSnr != null && rawEndcSnr > 0) {
                        if (adjust5gSnr) ((rawEndcSnr - 1.0) / 2.0) - 23.0 else rawEndcSnr.toDouble()
                    } else previousData?.nrSnr

                nrBand = lteBandVal ?: endcBandVal ?: previousData?.nrBand
                val resolvedNrPci = ltePciVal ?: endcPciVal
                nrPci = if (resolvedNrPci != null && resolvedNrPci > 0) resolvedNrPci
                else if (resolvedNrPci == 0) null else previousData?.nrPci
            } else if (sysmode == "lte") {
                lteRsrp = if (rawLteRsrp != null) rawLteRsrp - 141.0 else previousData?.lteRsrp
                lteRssi = if (rawLteRssi != null) rawLteRssi - 111.0 else previousData?.lteRssi
                lteRsrq = if (rawLteRsrq != null) (rawLteRsrq - 40.0) / 2.0 else previousData?.lteRsrq
                lteSinr = lteSinrVal ?: previousData?.lteSinr
                lteBand = lteBandVal ?: previousData?.lteBand
                ltePci = resolvePci(ltePciVal, previousData?.ltePci)
            } else {
                lteRsrp = if (rawLteRsrp != null) rawLteRsrp - 141.0 else previousData?.lteRsrp
                lteRssi = if (rawLteRssi != null) rawLteRssi - 111.0 else previousData?.lteRssi
                lteRsrq = if (rawLteRsrq != null) (rawLteRsrq - 40.0) / 2.0 else previousData?.lteRsrq
                lteSinr = lteSinrVal ?: previousData?.lteSinr
                lteBand = lteBandVal ?: previousData?.lteBand
                ltePci = resolvePci(ltePciVal, previousData?.ltePci)

                nrRsrp = when {
                    rawEndcRsrp != null && rawEndcRsrp > 0 -> rawEndcRsrp - 157.0
                    rawEndcRsrp == 0 || rawMap.has("mnet_endc_rsrp") -> null
                    else -> previousData?.nrRsrp
                }
                nrRsrq = when {
                    rawEndcRsrq != null && rawEndcRsrq > 0 -> ((rawEndcRsrq - 1.0) / 2.0) - 43.0
                    rawEndcRsrq == 0 || rawMap.has("mnet_endc_rsrq") -> null
                    else -> previousData?.nrRsrq
                }
                nrSnr = when {
                    rawEndcSnr != null && rawEndcSnr > 0 ->
                        if (adjust5gSnr) ((rawEndcSnr - 1.0) / 2.0) - 23.0 else rawEndcSnr.toDouble()
                    rawEndcSnr == 0 || rawMap.has("mnet_endc_snr") -> null
                    else -> previousData?.nrSnr
                }

                val is5gInactive = (rawMap.has("mnet_endc_rsrp") && rawEndcRsrp == 0) || endcPciVal == 0
                if (is5gInactive) {
                    nrBand = null
                    nrPci = null
                } else {
                    nrBand = resolvePci(endcBandVal, previousData?.nrBand)
                    nrPci = resolvePci(endcPciVal, previousData?.nrPci)
                }
            }

            val rawExist = optString(rawMap, "device_battery_exist")?.lowercase()
            val isBatteryPresent = if (rawExist == null) (previousData?.isBatteryPresent ?: true)
            else rawExist == "present" || rawExist == "1"

            val rawLevelPercent = parseInt(rawMap, "device_battery_level_percent") ?: parseInt(rawMap, "battery_percent")
            val rawLevel = parseInt(rawMap, "device_battery_level")
            val rawCap = parseInt(rawMap, "device_battery_capacity") ?: previousData?.batteryCapacity
            val rawCurr = parseInt(rawMap, "device_battery_current") ?: previousData?.batteryCurrent
            var rawTemp = parseDouble(rawMap, "device_battery_temperature") ?: previousData?.batteryTemperature
            if (rawTemp != null && (rawTemp < -30 || rawTemp > 100)) rawTemp = null
            val rawVolt = parseDouble(rawMap, "device_battery_voltage") ?: previousData?.batteryVoltage
            val rawChargeStatus = optString(rawMap, "device_battery_charge_status")?.lowercase()
                ?: previousData?.batteryChargeStatus
            val rawLongLife = optString(rawMap, "device_charge_long_life")?.lowercase()
                ?: if (previousData?.isLongLifeCharging == true) "enable" else "disable"
            val isLongLife = rawLongLife == "enable" || rawLongLife == "1"

            var batteryPercent: Int? = null
            var isCharging = false
            var resolvedLevel = rawLevel
            var resolvedCap = rawCap
            var resolvedCurr = rawCurr
            var resolvedTemp = rawTemp
            var resolvedVolt = rawVolt
            var resolvedChargeStatus = rawChargeStatus

            if (isBatteryPresent) {
                batteryPercent = rawLevelPercent
                if (batteryPercent == null && rawLevel != null && rawLevel > 4) {
                    batteryPercent = rawLevel.coerceIn(0, 100)
                }
                batteryPercent = batteryPercent ?: previousData?.batteryPercent
                isCharging = rawChargeStatus == "charging" ||
                    optString(rawMap, "battery_charging") == "1" ||
                    (rawCurr != null && rawCurr > 0) ||
                    (previousData?.isCharging ?: false)
            } else {
                batteryPercent = null
                resolvedLevel = null
                resolvedCap = null
                resolvedCurr = null
                resolvedTemp = null
                resolvedVolt = null
                resolvedChargeStatus = null
                isCharging = false
            }

            val devState = deviceStateJson
                ?: if (rawMap.has("uptime") && !rawMap.isNull("uptime")) rawMap else null
            val uptimeSec = parseInt(devState, "uptime") ?: previousData?.uptimeSeconds
            val totalRam = parseInt(devState, "totalram") ?: previousData?.totalRamBytes
            val usageRam = parseInt(devState, "usageram") ?: previousData?.usageRamBytes
            val freeRam = parseInt(devState, "freeram") ?: previousData?.freeRamBytes
            val cpuUsage = parseInt(devState, "cpuusage") ?: previousData?.cpuUsagePercent
            val procs = parseInt(devState, "procs") ?: previousData?.processCount

            val isNrActive = (nrRsrp != null && nrRsrp < 0) || (nrBand != null && nrBand > 0)
            val isSub6 = com.syameimarukoa.fs050w_signal_display.domain.util.FrequencyCalculator.isSub6Band(nrBand)

            val mode = when {
                isSa -> if (isSub6) Fs050wConnectionMode.NR5G_SUB6 else Fs050wConnectionMode.NR5G
                sysmode == "lte" -> Fs050wConnectionMode.LTE
                sysmode == "nsa" -> if (isNrActive) {
                    if (isSub6) Fs050wConnectionMode.NR5G_SUB6 else Fs050wConnectionMode.NR5G
                } else Fs050wConnectionMode.NSA_READY
                else -> Fs050wConnectionMode.LTE
            }

            val handover: String? = if (isSa) {
                if (previousData != null && nrPci != null && nrPci > 0 &&
                    previousData.nrPci != null && previousData.nrPci!! > 0 && nrPci != previousData.nrPci
                ) {
                    val bandStr = if (nrBand != null && nrBand > 0) "n$nrBand" else ""
                    "5G PCI ${previousData.nrPci} → $nrPci ($bandStr)"
                } else null
            } else {
                if (previousData != null && ltePci != null && ltePci > 0 &&
                    previousData.ltePci != null && previousData.ltePci!! > 0 && ltePci != previousData.ltePci
                ) {
                    val bandStr = if (lteBand != null && lteBand > 0) "B$lteBand" else ""
                    "4G PCI ${previousData.ltePci} → $ltePci ($bandStr)"
                } else if (previousData != null && nrPci != null && nrPci > 0 &&
                    previousData.nrPci != null && previousData.nrPci!! > 0 && nrPci != previousData.nrPci
                ) {
                    val bandStr = if (nrBand != null && nrBand > 0) "n$nrBand" else ""
                    "5G PCI ${previousData.nrPci} → $nrPci ($bandStr)"
                } else null
            }

            return SignalData(
                timestamp = LocalDateTime.now(),
                sysmode = sysmode,
                operatorName = operatorName,
                lteRsrp = lteRsrp,
                lteRssi = lteRssi,
                lteRsrq = lteRsrq,
                lteSinr = lteSinr,
                lteBand = lteBand,
                ltePci = ltePci,
                nrRsrp = nrRsrp,
                nrRsrq = nrRsrq,
                nrSnr = nrSnr,
                nrBand = nrBand,
                nrPci = nrPci,
                batteryPercent = batteryPercent,
                isCharging = isCharging,
                batteryLevel = resolvedLevel,
                batteryCapacity = resolvedCap,
                batteryCurrent = resolvedCurr,
                isBatteryPresent = isBatteryPresent,
                batteryTemperature = resolvedTemp,
                batteryVoltage = resolvedVolt,
                batteryChargeStatus = resolvedChargeStatus,
                isLongLifeCharging = isLongLife,
                uptimeSeconds = uptimeSec,
                totalRamBytes = totalRam,
                usageRamBytes = usageRam,
                freeRamBytes = freeRam,
                cpuUsagePercent = cpuUsage,
                processCount = procs,
                connectionMode = mode,
                isSa = isSa,
                handoverDescription = handover,
                routerLatencyMs = routerLatencyMs ?: previousData?.routerLatencyMs,
                preferNetMode = optString(rawMap, "mnet_acqorder") ?: previousData?.preferNetMode,
                wifiState = optString(rawMap, "wifi_state_0") ?: previousData?.wifiState,
                wifiFreq = optString(rawMap, "wifi_freq_0") ?: previousData?.wifiFreq,
                wifiSubFreq = optString(rawMap, "wifi_5g_sub_freq") ?: previousData?.wifiSubFreq,
                wifiClientCount = parseInt(rawMap, "wifi_client_0") ?: previousData?.wifiClientCount,
                wifiWorkStatus = optString(rawMap, "wifi_work_status") ?: previousData?.wifiWorkStatus,
            )
        }

        private fun resolvePci(value: Int?, previous: Int?): Int? = when {
            value != null && value > 0 -> value
            value == 0 -> null
            else -> previous
        }

        private fun optString(json: JSONObject?, key: String): String? {
            if (json == null || !json.has(key) || json.isNull(key)) return null
            return json.opt(key)?.toString()
        }

        private fun parseInt(json: JSONObject?, key: String): Int? {
            if (json == null || !json.has(key) || json.isNull(key)) return null
            return when (val value = json.opt(key)) {
                is Int -> value
                is String -> value.trim().takeIf { it.isNotEmpty() && it != "--" }?.toIntOrNull()
                else -> null
            }
        }

        private fun parseDouble(json: JSONObject?, key: String): Double? {
            if (json == null || !json.has(key) || json.isNull(key)) return null
            return when (val value = json.opt(key)) {
                is Double -> value
                is Int -> value.toDouble()
                is Float -> value.toDouble()
                is Long -> value.toDouble()
                is String -> value.trim().takeIf { it.isNotEmpty() && it != "--" }?.toDoubleOrNull()
                else -> null
            }
        }

        private fun parseBand(json: JSONObject?, key: String): Int? {
            val raw = optString(json, key) ?: return null
            val clean = raw.filter { it.isDigit() }
            if (clean.isEmpty()) return null
            val parsed = clean.toIntOrNull() ?: return null
            return if (parsed > 0) parsed else null
        }
    }
}
