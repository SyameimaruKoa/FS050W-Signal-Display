package com.syameimarukoa.fs050w_signal_display

import android.animation.ValueAnimator
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.IBinder
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowManager
import android.widget.FrameLayout
import androidx.compose.ui.platform.ComposeView
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import androidx.compose.runtime.CompositionLocalProvider
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.syameimarukoa.fs050w_signal_display.data.VibratorHelper
import com.syameimarukoa.fs050w_signal_display.ui.overlay.OverlayRoot
import kotlin.math.abs

class OverlayService : Service() {

    private var windowManager: WindowManager? = null
    private var container: FrameLayout? = null
    private var composeView: ComposeView? = null
    private var params: WindowManager.LayoutParams? = null
    private var lampView: View? = null
    private var lampParams: WindowManager.LayoutParams? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    private var isExpanded = true
    private var screenWidth = 1080
    private var screenHeight = 1920
    private var userWidthPx: Int? = null

    private var initialX = 0
    private var initialY = 0
    private var initialTouchX = 0f
    private var initialTouchY = 0f
    private var lastTapAt = 0L

    private lateinit var owners: OverlayComposeOwners

    companion object {
        var instance: OverlayService? = null

        const val ACTION_START_OVERLAY = "com.syameimarukoa.fs050w_signal_display.START_OVERLAY"
        const val ACTION_STOP_OVERLAY = "com.syameimarukoa.fs050w_signal_display.STOP_OVERLAY"
        const val ACTION_UPDATE_DATA = "com.syameimarukoa.fs050w_signal_display.UPDATE_DATA"
        const val ACTION_TRIGGER_LAMP = "com.syameimarukoa.fs050w_signal_display.TRIGGER_LAMP"
        const val ACTION_TRIGGER_VIBRATION = "com.syameimarukoa.fs050w_signal_display.TRIGGER_VIBRATION"

        const val EXTRA_JSON_DATA = "extra_json_data"
        const val EXTRA_LAMP_TYPE = "extra_lamp_type"
        const val EXTRA_LAMP_SHAPE = "extra_lamp_shape"
        const val EXTRA_LAMP_POSITION = "extra_lamp_position"
        const val EXTRA_LAMP_COLOR = "extra_lamp_color"
        const val EXTRA_VIBRATION_TYPE = "extra_vibration_type"
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        owners = OverlayComposeOwners()
        updateScreenDimensions()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) return START_NOT_STICKY
        startForegroundIfNeeded()
        when (intent.action) {
            ACTION_START_OVERLAY -> showOverlay()
            ACTION_STOP_OVERLAY -> {
                hideOverlay()
                stopSelf()
            }
            ACTION_TRIGGER_LAMP -> {
                triggerLamp(
                    intent.getStringExtra(EXTRA_LAMP_TYPE) ?: "5g",
                    intent.getStringExtra(EXTRA_LAMP_SHAPE) ?: "bar",
                    intent.getStringExtra(EXTRA_LAMP_POSITION) ?: "topCenter",
                )
            }
            ACTION_TRIGGER_VIBRATION -> VibratorHelper.vibrate(
                this, intent.getStringExtra(EXTRA_VIBRATION_TYPE) ?: "5g",
            )
        }
        return START_NOT_STICKY
    }

    private fun startForegroundIfNeeded() {
        val channelId = "fs050w_overlay_channel"
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (nm.getNotificationChannel(channelId) == null) {
            nm.createNotificationChannel(
                NotificationChannel(channelId, "FS050W Signal Display", NotificationManager.IMPORTANCE_LOW)
                    .apply { setShowBadge(false) },
            )
        }
        val notification = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("FS050W Signal Display")
            .setContentText("オーバーレイ & イベントLEDランプ待機中")
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
        try {
            if (Build.VERSION.SDK_INT >= 34) {
                startForeground(1001, notification, android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
            } else {
                startForeground(1001, notification)
            }
        } catch (e: Exception) {
            try {
                startForeground(1001, notification)
            } catch (e2: Exception) {
                e2.printStackTrace()
            }
        }
    }

    private fun updateScreenDimensions() {
        val wm = windowManager ?: return
        val metrics = wm.maximumWindowMetrics
        screenWidth = metrics.bounds.width().coerceAtLeast(1)
        screenHeight = metrics.bounds.height().coerceAtLeast(1)
    }

    private fun dp(value: Float): Int = (value * resources.displayMetrics.density).toInt()

    private fun app() = application as Fs050wApp

    /** ComposeView in a Service needs a ViewTree LifecycleOwner; set reflectively so the
     * build stays compatible with AndroidX variants that expose it as a class or extension. */
    private fun attachComposeOwners(view: View) {
        try {
            val clazz = Class.forName("androidx.lifecycle.ViewTreeLifecycleOwner")
            val setter = clazz.methods.firstOrNull { it.name == "set" && it.parameterCount == 2 }
            setter?.invoke(null, view, owners)
        } catch (_: Exception) {
            // Older/newer AndroidX variants may not expose the static setter; composition
            // still works because LocalLifecycleOwner is provided explicitly below.
        }
    }

    private fun showOverlay() {
        if (container != null) return
        val type = WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        params = WindowManager.LayoutParams(
            userWidthPx ?: dp(280f),
            WindowManager.LayoutParams.WRAP_CONTENT,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = (screenWidth * 0.05).toInt()
            y = (screenHeight * 0.15).toInt()
        }

        val host = FrameLayout(this)
        val view = ComposeView(this).apply {
            attachComposeOwners(this)
            layoutParams = FrameLayout.LayoutParams(
                userWidthPx ?: dp(280f),
                FrameLayout.LayoutParams.WRAP_CONTENT,
            )
            setContent {
                CompositionLocalProvider(LocalLifecycleOwner provides owners) {
                    OverlayRoot(
                        repository = app().repository,
                        initialSettings = app().settingsStore.value,
                        expanded = isExpanded,
                        onToggleExpanded = { toggleExpanded() },
                    )
                }
            }
        }
        composeView = view
        host.addView(view)

        val resize = View(this).apply {
            layoutParams = FrameLayout.LayoutParams(dp(20f), dp(20f)).apply {
                gravity = Gravity.BOTTOM or Gravity.END
            }
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                setColor(Color.argb(90, 0, 229, 255))
                cornerRadius = dp(4f).toFloat()
            }
            setOnTouchListener { v, event -> handleResize(v, event) }
        }
        host.addView(resize)

        host.setOnTouchListener { _, event -> handleDrag(event) }
        container = host
        try {
            windowManager?.addView(host, params)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun hideOverlay() {
        container?.let {
            try {
                if (it.isAttachedToWindow) windowManager?.removeView(it)
            } catch (_: Exception) {
            }
        }
        container = null
        composeView = null
        params = null
        lampView?.let {
            try {
                if (it.isAttachedToWindow) windowManager?.removeView(it)
            } catch (_: Exception) {
            }
        }
        lampView = null
        lampParams = null
    }

    private fun recompose() {
        mainHandler.post {
            composeView?.setContent {
                CompositionLocalProvider(LocalLifecycleOwner provides owners) {
                    OverlayRoot(
                        repository = app().repository,
                        initialSettings = app().settingsStore.value,
                        expanded = isExpanded,
                        onToggleExpanded = { toggleExpanded() },
                    )
                }
            }
        }
    }

    private fun toggleExpanded() {
        isExpanded = !isExpanded
        val width = userWidthPx ?: dp(if (isExpanded) 280f else 120f)
        composeView?.layoutParams?.width = width
        recompose()
    }

    private fun handleResize(v: View, event: MotionEvent): Boolean {
        when (event.actionMasked) {
            MotionEvent.ACTION_MOVE -> {
                val current = composeView?.layoutParams ?: return true
                val next = (current.width + event.x).toInt().coerceIn(dp(120f), screenWidth - dp(32f))
                current.width = next
                composeView?.layoutParams = current
                userWidthPx = next
                params?.width = next
                params?.let { windowManager?.updateViewLayout(container, it) }
                composeView?.invalidate()
            }
        }
        return true
    }

    private fun handleDrag(event: MotionEvent): Boolean {
        val p = params ?: return false
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                initialX = p.x
                initialY = p.y
                initialTouchX = event.rawX
                initialTouchY = event.rawY
            }
            MotionEvent.ACTION_MOVE -> {
                p.x = initialX + (event.rawX - initialTouchX).toInt()
                p.y = initialY + (event.rawY - initialTouchY).toInt()
                try {
                    windowManager?.updateViewLayout(container, p)
                } catch (_: Exception) {
                }
            }
            MotionEvent.ACTION_UP -> {
                val moved = abs(event.rawX - initialTouchX) + abs(event.rawY - initialTouchY)
                if (moved < ViewConfiguration.get(this).scaledTouchSlop) {
                    val now = System.currentTimeMillis()
                    if (now - lastTapAt < 300L) {
                        openMainActivity()
                    } else if (event.y > (composeView?.height ?: 0) - dp(28f)) {
                        // resize handle area: handled by the dedicated view
                    } else {
                        toggleExpanded()
                    }
                    lastTapAt = now
                } else {
                    snapToEdge(p)
                }
            }
        }
        return true
    }

    private fun snapToEdge(p: WindowManager.LayoutParams) {
        val target = if (p.x < screenWidth / 2) dp(8f) else screenWidth - (composeView?.width ?: dp(280f)) - dp(8f)
        val animator = ValueAnimator.ofInt(p.x, target).apply {
            duration = 220
            addUpdateListener {
                p.x = it.animatedValue as Int
                try {
                    windowManager?.updateViewLayout(container, p)
                } catch (_: Exception) {
                }
            }
        }
        animator.start()
    }

    private fun openMainActivity() {
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        startActivity(intent)
    }

    private fun triggerLamp(type: String, lampShape: String, position: String) {
        if (!app().settingsStore.value.eventLampEnabled) return
        val color = when (type) {
            "handover" -> Color.parseColor("#FFD600")
            "critical", "battery_temp" -> Color.parseColor("#FF5252")
            else -> Color.parseColor("#00E5FF")
        }
        val w = if (lampShape == "dot") dp(10f) else dp(screenWidth / 4f)
        val h = if (lampShape == "dot") dp(10f) else dp(3f)
        lampParams = WindowManager.LayoutParams(
            w, h,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = when (position) {
                "topLeft" -> Gravity.TOP or Gravity.START
                "topRight" -> Gravity.TOP or Gravity.END
                else -> Gravity.TOP or Gravity.CENTER_HORIZONTAL
            }
            y = dp(2f)
        }
        val view = View(this).apply {
            background = GradientDrawable().apply {
                shape = if (lampShape == "dot") GradientDrawable.OVAL else GradientDrawable.RECTANGLE
                setColor(color)
                cornerRadius = dp(4f).toFloat()
            }
            alpha = 0f
        }
        lampView = view
        try {
            windowManager?.addView(view, lampParams)
        } catch (_: Exception) {
            return
        }
        val fade = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 350
            addUpdateListener { view.alpha = it.animatedValue as Float }
        }
        fade.start()
        val blinks = if (type == "critical" || type == "battery_temp") 3 else 1
        repeat(blinks) { index ->
            mainHandler.postDelayed({
                view.animate().alpha(0.2f).setDuration(180).withEndAction {
                    view.animate().alpha(1f).setDuration(180)
                }
            }, 600L + index * 500L)
        }
        mainHandler.postDelayed({
            view.animate().alpha(0f).setDuration(400).withEndAction {
                try {
                    if (view.isAttachedToWindow) windowManager?.removeView(view)
                } catch (_: Exception) {
                }
                if (lampView === view) {
                    lampView = null
                    lampParams = null
                }
            }
        }, 2600L)
    }

    override fun onDestroy() {
        hideOverlay()
        instance = null
        super.onDestroy()
    }

    private class OverlayComposeOwners : LifecycleOwner {
        private val lifecycleRegistry = LifecycleRegistry(this).apply {
            currentState = Lifecycle.State.RESUMED
        }

        override val lifecycle: Lifecycle get() = lifecycleRegistry
    }
}
