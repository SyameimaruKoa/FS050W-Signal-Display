package com.syameimarukoa.fs050w_signal_display

import android.app.PictureInPictureParams
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.res.Configuration
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.util.Rational
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.syameimarukoa.fs050w_signal_display.data.SignalRepository
import com.syameimarukoa.fs050w_signal_display.data.SettingsStore
import com.syameimarukoa.fs050w_signal_display.ui.LocalRepository
import com.syameimarukoa.fs050w_signal_display.ui.MainScreen
import com.syameimarukoa.fs050w_signal_display.ui.theme.Fs050wTheme

class MainActivity : ComponentActivity() {
    private lateinit var repository: SignalRepository
    private lateinit var settingsStore: SettingsStore

    private var autoPipEnabled = false
    private var pipNumerator = 16
    private var pipDenominator = 9
    private var isHomeKeyPressed = false
    private var isRecentAppsPressed = false

    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                Intent.ACTION_SCREEN_OFF -> repository.setScreenState(false)
                Intent.ACTION_SCREEN_ON -> repository.setScreenState(true)
            }
        }
    }

    private val systemDialogReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action != Intent.ACTION_CLOSE_SYSTEM_DIALOGS) return
            when (intent.getStringExtra("reason")) {
                "homekey" -> isHomeKeyPressed = true
                "recentapps" -> isRecentAppsPressed = true
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        val app = application as Fs050wApp
        repository = app.repository
        settingsStore = app.settingsStore

        setContent {
            val settings by repository.settings.collectAsStateWithLifecycle()
            LaunchedEffect(settings.keepScreenOn) {
                applyKeepScreenOn(settings.keepScreenOn)
            }
            CompositionLocalProvider(LocalRepository provides repository) {
                Fs050wTheme(settings) {
                    MainScreen(
                        onEnterPip = { enterPip(pipNumerator, pipDenominator) },
                        onOverlayChanged = { enabled ->
                            if (enabled) startOverlay() else stopOverlay()
                        },
                    )
                }
            }
        }

        val initial = settingsStore.value
        syncPipSettings(initial)
        applyKeepScreenOn(initial.keepScreenOn)
        if (initial.overlayEnabled) startOverlay()

        registerReceiver(screenReceiver, IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_SCREEN_ON)
        })
        @Suppress("DEPRECATION")
        registerReceiver(systemDialogReceiver, IntentFilter(Intent.ACTION_CLOSE_SYSTEM_DIALOGS))
    }

    override fun onResume() {
        super.onResume()
        isHomeKeyPressed = false
        isRecentAppsPressed = false
        repository.setScreenState(true)
        syncPipSettings(settingsStore.value)
        if (settingsStore.value.overlayEnabled) startOverlay()
    }

    override fun onPause() {
        super.onPause()
        val overlayActive = settingsStore.value.overlayEnabled
        if (!overlayActive && !repository.isPipMode.value) {
            repository.stopPolling()
        }
    }

    override fun onDestroy() {
        try {
            unregisterReceiver(screenReceiver)
            unregisterReceiver(systemDialogReceiver)
        } catch (_: Exception) {
        }
        repository.logout()
        super.onDestroy()
    }

    private fun syncPipSettings(settings: com.syameimarukoa.fs050w_signal_display.domain.model.AppSettings) {
        autoPipEnabled = settings.autoPipOnHome
        val parts = settings.pipAspectRatio.split(":")
        pipNumerator = parts.getOrNull(0)?.toIntOrNull() ?: 16
        pipDenominator = parts.getOrNull(1)?.toIntOrNull() ?: 9
        val params = PictureInPictureParams.Builder()
            .setAspectRatio(sanitizeAspectRatio(pipNumerator, pipDenominator))
            .setAutoEnterEnabled(false)
            .build()
        setPictureInPictureParams(params)
    }

    private fun sanitizeAspectRatio(num: Int, den: Int): Rational {
        val ratio = num.toFloat() / den.toFloat()
        return when {
            ratio < 0.4185f -> Rational(9, 21)
            ratio > 2.389f -> Rational(21, 9)
            else -> Rational(num, den)
        }
    }

    private fun enterPip(num: Int, den: Int): Boolean {
        if (!packageManager.hasSystemFeature(android.content.pm.PackageManager.FEATURE_PICTURE_IN_PICTURE)) return false
        val params = PictureInPictureParams.Builder()
            .setAspectRatio(sanitizeAspectRatio(num, den))
            .build()
        return enterPictureInPictureMode(params)
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (autoPipEnabled && !isRecentAppsPressed) {
            enterPip(pipNumerator, pipDenominator)
        }
        isRecentAppsPressed = false
        isHomeKeyPressed = false
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        repository.setPipMode(isInPictureInPictureMode)
    }

    private fun applyKeepScreenOn(enabled: Boolean) {
        if (enabled) {
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
    }

    private fun startOverlay() {
        if (!Settings.canDrawOverlays(this)) return
        val s = settingsStore.value
        val intent = Intent(this, OverlayService::class.java).apply {
            action = OverlayService.ACTION_START_OVERLAY
            putExtra("overlayStyle", s.overlayStyle)
            putExtra("overlayOpacity", s.overlayOpacity.toFloat())
            putExtra("overlayScale", s.overlayScale.toFloat())
            putExtra("pipAspectRatio", s.pipAspectRatio)
            putExtra("smoothGaugeCurve", s.smoothGaugeCurve)
        }
        ContextCompat.startForegroundService(this, intent)
    }

    private fun stopOverlay() {
        val intent = Intent(this, OverlayService::class.java).apply {
            action = OverlayService.ACTION_STOP_OVERLAY
        }
        ContextCompat.startForegroundService(this, intent)
    }
}
