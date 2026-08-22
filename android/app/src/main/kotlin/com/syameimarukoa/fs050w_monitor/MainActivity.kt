package com.syameimarukoa.fs050w_monitor

import android.app.PictureInPictureParams
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.res.Configuration
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val PIP_CHANNEL = "com.syameimarukoa.fs050w_monitor/pip"
    private val OVERLAY_CHANNEL = "com.syameimarukoa.fs050w_monitor/overlay"
    private val LIFECYCLE_CHANNEL = "com.syameimarukoa.fs050w_monitor/lifecycle"

    private var pipMethodChannel: MethodChannel? = null
    private var overlayMethodChannel: MethodChannel? = null
    private var lifecycleMethodChannel: MethodChannel? = null

    private var autoPipEnabled = false
    private var pipNumerator = 16
    private var pipDenominator = 9

    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                Intent.ACTION_SCREEN_OFF -> {
                    lifecycleMethodChannel?.invokeMethod("onScreenStateChanged", false)
                }
                Intent.ACTION_SCREEN_ON -> {
                    lifecycleMethodChannel?.invokeMethod("onScreenStateChanged", true)
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        pipMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PIP_CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "isPipSupported" -> {
                        result.success(isPipSupported())
                    }
                    "enterPipMode" -> {
                        val num = call.argument<Int>("numerator") ?: 16
                        val den = call.argument<Int>("denominator") ?: 9
                        val success = enterPip(num, den)
                        result.success(success)
                    }
                    "setAutoEnterPip" -> {
                        autoPipEnabled = call.argument<Boolean>("enabled") ?: false
                        pipNumerator = call.argument<Int>("numerator") ?: 16
                        pipDenominator = call.argument<Int>("denominator") ?: 9
                        updateAutoEnterPip()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        overlayMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OVERLAY_CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "checkPermission" -> {
                        val canDraw = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            Settings.canDrawOverlays(this@MainActivity)
                        } else {
                            true
                        }
                        result.success(canDraw)
                    }
                    "requestPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val intent = Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName")
                            )
                            startActivity(intent)
                        }
                        result.success(true)
                    }
                    "startOverlay" -> {
                        val style = call.argument<String>("overlayStyle") ?: "card"
                        val opacity = call.argument<Double>("overlayOpacity")?.toFloat() ?: 0.85f
                        val scale = call.argument<Double>("overlayScale")?.toFloat() ?: 1.0f
                        val ratio = call.argument<String>("pipAspectRatio") ?: "16:9"
                        val curve = call.argument<String>("smoothGaugeCurve") ?: "easeOut"

                        val intent = Intent(this@MainActivity, OverlayService::class.java).apply {
                            action = OverlayService.ACTION_START_OVERLAY
                            putExtra("overlayStyle", style)
                            putExtra("overlayOpacity", opacity)
                            putExtra("overlayScale", scale)
                            putExtra("pipAspectRatio", ratio)
                            putExtra("smoothGaugeCurve", curve)
                        }
                        safeStartService(intent)
                        result.success(true)
                    }
                    "stopOverlay" -> {
                        val intent = Intent(this@MainActivity, OverlayService::class.java).apply {
                            action = OverlayService.ACTION_STOP_OVERLAY
                        }
                        safeStartService(intent)
                        result.success(true)
                    }
                    "updateOverlayData" -> {
                        val jsonData = call.argument<String>("jsonData") ?: ""
                        val style = call.argument<String>("overlayStyle")
                        val opacity = call.argument<Double>("overlayOpacity")?.toFloat()
                        val scale = call.argument<Double>("overlayScale")?.toFloat()
                        val ratio = call.argument<String>("pipAspectRatio")
                        val curve = call.argument<String>("smoothGaugeCurve")

                        val intent = Intent(this@MainActivity, OverlayService::class.java).apply {
                            action = OverlayService.ACTION_UPDATE_DATA
                            putExtra(OverlayService.EXTRA_JSON_DATA, jsonData)
                            if (style != null) putExtra("overlayStyle", style)
                            if (opacity != null) putExtra("overlayOpacity", opacity)
                            if (scale != null) putExtra("overlayScale", scale)
                            if (ratio != null) putExtra("pipAspectRatio", ratio)
                            if (curve != null) putExtra("smoothGaugeCurve", curve)
                        }
                        safeStartService(intent)
                        result.success(true)
                    }
                    "triggerLamp" -> {
                        val type = call.argument<String>("type") ?: "5g"
                        val shape = call.argument<String>("shape") ?: "bar"
                        val position = call.argument<String>("position") ?: "topCenter"
                        val color = call.argument<String>("color")

                        val intent = Intent(this@MainActivity, OverlayService::class.java).apply {
                            action = OverlayService.ACTION_TRIGGER_LAMP
                            putExtra(OverlayService.EXTRA_LAMP_TYPE, type)
                            putExtra(OverlayService.EXTRA_LAMP_SHAPE, shape)
                            putExtra(OverlayService.EXTRA_LAMP_POSITION, position)
                            if (color != null) putExtra(OverlayService.EXTRA_LAMP_COLOR, color)
                        }
                        safeStartService(intent)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        lifecycleMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LIFECYCLE_CHANNEL)

        val screenFilter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_SCREEN_ON)
        }
        registerReceiver(screenReceiver, screenFilter)

        val dialogFilter = IntentFilter(Intent.ACTION_CLOSE_SYSTEM_DIALOGS)
        @Suppress("DEPRECATION")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(systemDialogReceiver, dialogFilter, Context.RECEIVER_EXPORTED)
        } else {
            registerReceiver(systemDialogReceiver, dialogFilter)
        }
    }

    private var isHomeKeyPressed = false
    private var isRecentAppsPressed = false

    private val systemDialogReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == Intent.ACTION_CLOSE_SYSTEM_DIALOGS) {
                val reason = intent.getStringExtra("reason")
                if (reason == "homekey") {
                    isHomeKeyPressed = true
                    isRecentAppsPressed = false
                    if (autoPipEnabled && isPipSupported()) {
                        enterPip(pipNumerator, pipDenominator)
                    }
                } else if (reason == "recentapps") {
                    isRecentAppsPressed = true
                    isHomeKeyPressed = false
                }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        isHomeKeyPressed = false
        isRecentAppsPressed = false
    }

    override fun onDestroy() {
        try {
            unregisterReceiver(screenReceiver)
        } catch (_: Exception) {}
        try {
            unregisterReceiver(systemDialogReceiver)
        } catch (_: Exception) {}
        super.onDestroy()
    }

    private fun isPipSupported(): Boolean {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            packageManager.hasSystemFeature(android.content.pm.PackageManager.FEATURE_PICTURE_IN_PICTURE)
    }

    private fun enterPip(numerator: Int, denominator: Int): Boolean {
        if (!isPipSupported()) return false

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val clampedRational = sanitizeAspectRatio(numerator, denominator)
            val params = PictureInPictureParams.Builder()
                .setAspectRatio(clampedRational)
                .build()
            return enterPictureInPictureMode(params)
        }
        return false
    }

    private fun updateAutoEnterPip() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val clampedRational = sanitizeAspectRatio(pipNumerator, pipDenominator)
            val params = PictureInPictureParams.Builder()
                .setAspectRatio(clampedRational)
                .setAutoEnterEnabled(false) // Disable OS automatic enter to prevent triggering on Overview/Recent Apps
                .build()
            setPictureInPictureParams(params)
        }
    }

    private fun sanitizeAspectRatio(num: Int, den: Int): Rational {
        val floatRatio = num.toFloat() / den.toFloat()
        // Android PiP supports aspect ratio from 0.418410 (9:21.5) to 2.390000 (21.5:9)
        return when {
            floatRatio < 0.4185f -> Rational(9, 21) // 9:21 is ~0.4285
            floatRatio > 2.389f -> Rational(21, 9) // 21:9 is ~2.3333
            else -> Rational(num, den)
        }
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (autoPipEnabled && !isRecentAppsPressed && isPipSupported()) {
            enterPip(pipNumerator, pipDenominator)
        }
        isRecentAppsPressed = false
        isHomeKeyPressed = false
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        pipMethodChannel?.invokeMethod("onPipModeChanged", isInPictureInPictureMode)
    }

    private fun safeStartService(intent: Intent) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                ContextCompat.startForegroundService(this, intent)
            } else {
                startService(intent)
            }
        } catch (e: Exception) {
            try {
                startService(intent)
            } catch (e2: Exception) {
                e2.printStackTrace()
            }
        }
    }
}
