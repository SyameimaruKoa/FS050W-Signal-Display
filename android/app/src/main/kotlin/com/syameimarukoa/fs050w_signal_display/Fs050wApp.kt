package com.syameimarukoa.fs050w_signal_display

import android.app.Application
import android.content.Intent
import androidx.core.content.ContextCompat
import com.syameimarukoa.fs050w_signal_display.data.AppLogger
import com.syameimarukoa.fs050w_signal_display.data.EventActions
import com.syameimarukoa.fs050w_signal_display.data.EventDetector
import com.syameimarukoa.fs050w_signal_display.data.SettingsStore
import com.syameimarukoa.fs050w_signal_display.data.SignalRepository
import com.syameimarukoa.fs050w_signal_display.data.VibratorHelper

class Fs050wApp : Application() {
    lateinit var settingsStore: SettingsStore
        private set
    lateinit var repository: SignalRepository
        private set

    override fun onCreate() {
        super.onCreate()
        settingsStore = SettingsStore(this)
        repository = SignalRepository(
            settingsStore = settingsStore,
            eventDetector = EventDetector(),
            eventActions = object : EventActions {
                override fun vibrate(type: String) = VibratorHelper.vibrate(this@Fs050wApp, type)

                override fun triggerLamp(type: String) {
                    val settings = settingsStore.value
                    if (!settings.eventLampEnabled) return
                    val intent = Intent(this@Fs050wApp, OverlayService::class.java).apply {
                        action = OverlayService.ACTION_TRIGGER_LAMP
                        putExtra(OverlayService.EXTRA_LAMP_TYPE, type)
                        putExtra(OverlayService.EXTRA_LAMP_SHAPE, settings.eventLampShape)
                        putExtra(OverlayService.EXTRA_LAMP_POSITION, settings.eventLampPosition)
                    }
                    try {
                        ContextCompat.startForegroundService(this@Fs050wApp, intent)
                    } catch (e: Exception) {
                        AppLogger.warn("Could not start lamp service: ${e.message}")
                    }
                }
            },
        )
    }
}
