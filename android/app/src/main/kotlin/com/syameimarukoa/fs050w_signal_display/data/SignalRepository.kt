package com.syameimarukoa.fs050w_signal_display.data

import com.syameimarukoa.fs050w_signal_display.domain.model.AppSettings
import com.syameimarukoa.fs050w_signal_display.domain.model.SignalData
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

/** Application state holder: polling lifecycle, signal history and derived UI state. */
class SignalRepository(
    private val settingsStore: SettingsStore,
    private val eventDetector: EventDetector,
    private val eventActions: EventActions,
) {
    private val api = RouterApi(settingsStore.value)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var pollJob: Job? = null
    private var screenOn = true
    private var lastSignal: SignalData? = null

    val settings: StateFlow<AppSettings> = settingsStore.settings
    private val _currentSignal = MutableStateFlow<SignalData?>(null)
    val currentSignal: StateFlow<SignalData?> = _currentSignal.asStateFlow()

    private val _history = MutableStateFlow<List<SignalData>>(emptyList())
    val history: StateFlow<List<SignalData>> = _history.asStateFlow()

    private val _status = MutableStateFlow(ConnectionStatus.DISCONNECTED)
    val status: StateFlow<ConnectionStatus> = _status.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    private val _isLoggedIn = MutableStateFlow(false)
    val isLoggedIn: StateFlow<Boolean> = _isLoggedIn.asStateFlow()

    private val _isConnecting = MutableStateFlow(false)
    val isConnecting: StateFlow<Boolean> = _isConnecting.asStateFlow()

    private val _isPolling = MutableStateFlow(false)
    val isPolling: StateFlow<Boolean> = _isPolling.asStateFlow()

    private val _isPipMode = MutableStateFlow(false)
    val isPipMode: StateFlow<Boolean> = _isPipMode.asStateFlow()

    /** Flutter 版 PiPDetectorShell と同じ: PiP 状態を更新するだけ。
     *  ポーリングの開始/停止はライフサイクル（resumed/paused）側が担う。 */
    fun setPipMode(active: Boolean) {
        _isPipMode.value = active
    }

    private val _lockoutRemainingSeconds = MutableStateFlow(0)
    val lockoutRemainingSeconds: StateFlow<Int> = _lockoutRemainingSeconds.asStateFlow()

    fun startPolling() {
        if (pollJob?.isActive == true) return
        _isPolling.value = true
        pollJob = scope.launch {
            while (isActive && screenOn) {
                performPoll()
                val interval = if (api.isLoggedIn) {
                    settingsStore.value.foregroundIntervalSeconds
                } else {
                    settingsStore.value.unauthIntervalSeconds
                }
                delay(interval.coerceIn(1, 10) * 1000L)
            }
        }
    }

    fun stopPolling() {
        pollJob?.cancel()
        pollJob = null
        _isPolling.value = false
    }

    fun restartPolling() {
        stopPolling()
        api.updateSettings(settingsStore.value)
        startPolling()
    }

    fun setScreenState(on: Boolean) {
        if (screenOn == on) return
        screenOn = on
        if (on) {
            AppLogger.info("Screen ON detected: Resuming polling loop immediately")
            startPolling()
        } else {
            AppLogger.info("Screen OFF detected: Pausing polling loop")
            stopPolling()
        }
    }

    fun updateSettings(newSettings: AppSettings) {
        settingsStore.persist(newSettings)
        api.updateSettings(newSettings)
        if (_isPolling.value) restartPolling()
    }

    suspend fun testConnection(ip: String, password: String): Boolean = api.testConnection(ip, password)

    fun logout() {
        stopPolling()
        scope.launch { api.logout() }
    }

    private suspend fun performPoll() {
        when (val outcome = api.pollOnce()) {
            is PollOutcome.Success -> {
                _status.value = api.status
                _errorMessage.value = api.errorMessage
                _isLoggedIn.value = api.isLoggedIn
                _isConnecting.value = false
                _lockoutRemainingSeconds.value = api.lockoutRemainingSeconds

                val signal = SignalData.fromApiResponse(
                    json = outcome.params,
                    deviceStateJson = outcome.deviceState,
                    previousData = lastSignal,
                    adjust5gSnr = settingsStore.value.adjust5gSnr,
                    routerLatencyMs = outcome.latencyMs,
                )
                lastSignal = signal
                eventDetector.handle(signal, settingsStore.value, eventActions)
                _currentSignal.value = signal
                _history.value = (_history.value + signal).takeLast(MAX_HISTORY)
            }
            is PollOutcome.Failure -> {
                _status.value = api.status
                _errorMessage.value = outcome.message
                _isLoggedIn.value = api.isLoggedIn
                _isConnecting.value = outcome.connecting
                _lockoutRemainingSeconds.value = api.lockoutRemainingSeconds
            }
        }
    }

    companion object {
        private const val MAX_HISTORY = 600
    }
}
