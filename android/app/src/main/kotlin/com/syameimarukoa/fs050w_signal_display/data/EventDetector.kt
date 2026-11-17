package com.syameimarukoa.fs050w_signal_display.data

import com.syameimarukoa.fs050w_signal_display.domain.model.AppSettings
import com.syameimarukoa.fs050w_signal_display.domain.model.Fs050wConnectionMode
import com.syameimarukoa.fs050w_signal_display.domain.model.SignalData

interface EventActions {
    fun vibrate(type: String)
    fun triggerLamp(type: String)
}

/** Detects event transitions that previously lived in NotificationService. */
class EventDetector {
    private var lastConnectionMode: Fs050wConnectionMode? = null
    private var lastHandoverKey: String? = null
    private var wasCritical = false
    private var wasOverheated = false

    fun handle(signal: SignalData, settings: AppSettings, actions: EventActions) {
        if (signal.connectionMode == Fs050wConnectionMode.NR5G_SUB6 &&
            lastConnectionMode != Fs050wConnectionMode.NR5G_SUB6
        ) {
            actions.vibrate("5g")
            if (settings.eventLampEnabled) actions.triggerLamp("5g")
        }
        lastConnectionMode = signal.connectionMode

        if (signal.handoverDescription != null) {
            if (lastHandoverKey != signal.handoverDescription) {
                if (settings.vibrateOnHandover) actions.vibrate("handover")
                if (settings.eventLampEnabled) actions.triggerLamp("handover")
                lastHandoverKey = signal.handoverDescription
            }
        } else {
            lastHandoverKey = null
        }

        val isCritical = (signal.lteRsrp != null && signal.lteRsrp!! <= -115.0) ||
            (signal.nrRsrp != null && signal.nrRsrp!! <= -115.0)
        if (settings.vibrateOnCriticalSignal && isCritical && !wasCritical) {
            actions.vibrate("critical")
            if (settings.eventLampEnabled) actions.triggerLamp("critical")
        }
        wasCritical = isCritical

        if (settings.batteryTempWarningEnabled && signal.batteryTemperature != null) {
            val isOverheated = signal.batteryTemperature!! >= settings.batteryTempWarningThreshold
            if (isOverheated && !wasOverheated) {
                actions.vibrate("battery_temp")
                if (settings.eventLampEnabled) actions.triggerLamp("battery_temp")
            }
            wasOverheated = isOverheated
        } else {
            wasOverheated = false
        }
    }
}
