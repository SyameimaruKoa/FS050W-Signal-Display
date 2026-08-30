package com.syameimarukoa.fs050w_signal_display

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.animation.ValueAnimator
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.res.Resources
import android.graphics.*
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.Vibrator
import android.os.VibratorManager
import android.os.VibrationEffect
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.style.ForegroundColorSpan
import android.text.style.StyleSpan
import android.util.DisplayMetrics
import android.util.TypedValue
import android.view.*
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import org.json.JSONObject
import kotlin.math.max
import kotlin.math.min

class OverlayService : Service() {

    private var windowManager: WindowManager? = null

    // Floating Widget View & Params
    private var overlayContainer: FrameLayout? = null
    private var overlayLayoutParams: WindowManager.LayoutParams? = null

    // LED Lamp View & Params
    private var lampContainer: FrameLayout? = null
    private var lampLayoutParams: WindowManager.LayoutParams? = null
    private var lampHideHandler = Handler(Looper.getMainLooper())
    private var lampBlinkAnimator: ValueAnimator? = null

    // State Variables
    private var isExpanded = true
    private var overlayStyle = "card" // "card" or "compact"
    private var overlayOpacity = 0.85f
    private var overlayScale = 1.0f
    private var aspectRatioStr = "16:9"
    private var smoothGaugeCurve = "easeOut"

    // Signal Data Cache
    private var lastSignalJson: JSONObject? = null

    // Gesture and Touch Tracking
    private var initialX = 0
    private var initialY = 0
    private var initialTouchX = 0f
    private var initialTouchY = 0f
    private var isResizing = false
    private var initialWidth = 0
    private var initialHeight = 0
    private var snapAnimator: ValueAnimator? = null

    // Screen Dimensions
    private var screenWidth = 1080
    private var screenHeight = 2400

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

        fun applyCurve(ratio: Double, curveType: String): Double {
            val r = ratio.coerceIn(0.0, 1.0)
            return when (curveType) {
                "easeOut" -> 1.0 - (1.0 - r) * (1.0 - r)
                "easeIn" -> r * r
                "easeInOut" -> if (r < 0.5) 2.0 * r * r else 1.0 - (-2.0 * r + 2.0) * (-2.0 * r + 2.0) / 2.0
                "linear" -> r
                else -> 1.0 - (1.0 - r) * (1.0 - r)
            }
        }

        fun getRsrpColor(rsrp: Double?): Int {
            if (rsrp == null || rsrp.isNaN() || rsrp <= -200) return Color.parseColor("#757575")
            return when {
                rsrp >= -80.0 -> Color.parseColor("#2196F3")
                rsrp >= -90.0 -> Color.parseColor("#4CAF50")
                rsrp >= -100.0 -> Color.parseColor("#8BC34A")
                rsrp >= -110.0 -> Color.parseColor("#FF9800")
                rsrp >= -120.0 -> Color.parseColor("#F44336")
                else -> Color.parseColor("#9C27B0")
            }
        }

        fun getRsrqColor(rsrq: Double?): Int {
            if (rsrq == null || rsrq.isNaN() || rsrq <= -200) return Color.parseColor("#757575")
            return when {
                rsrq >= -10.0 -> Color.parseColor("#2196F3")
                rsrq >= -15.0 -> Color.parseColor("#4CAF50")
                rsrq >= -18.0 -> Color.parseColor("#8BC34A")
                rsrq >= -20.0 -> Color.parseColor("#FF9800")
                rsrq >= -22.0 -> Color.parseColor("#F44336")
                else -> Color.parseColor("#9C27B0")
            }
        }

        fun getSinrColor(sinr: Double?): Int {
            if (sinr == null || sinr.isNaN() || sinr <= -200) return Color.parseColor("#757575")
            return when {
                sinr >= 20.0 -> Color.parseColor("#2196F3")
                sinr >= 13.0 -> Color.parseColor("#4CAF50")
                sinr >= 0.0 -> Color.parseColor("#8BC34A")
                sinr >= -3.0 -> Color.parseColor("#FF9800")
                sinr >= -6.0 -> Color.parseColor("#F44336")
                else -> Color.parseColor("#9C27B0")
            }
        }

        fun getTempColor(temp: Double?): Int {
            if (temp == null || temp.isNaN()) return Color.WHITE
            return when {
                temp >= 45.0 -> Color.parseColor("#F44336")
                temp >= 42.0 -> Color.parseColor("#FF9800")
                temp >= 38.0 -> Color.parseColor("#4CAF50")
                else -> Color.parseColor("#00E5FF")
            }
        }

        fun getLatencyColor(latencyMs: Int?): Int {
            if (latencyMs == null) return Color.parseColor("#757575")
            return when {
                latencyMs <= 50 -> Color.parseColor("#00E676")
                latencyMs <= 150 -> Color.parseColor("#FFD600")
                else -> Color.parseColor("#FF5252")
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        updateScreenDimensions()
    }

    private fun updateScreenDimensions() {
        val dm = Resources.getSystem().displayMetrics
        screenWidth = dm.widthPixels
        screenHeight = dm.heightPixels
    }

    private fun startForegroundIfNeeded() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channelId = "fs050w_overlay_channel"
            val channelName = "FS050W Signal Display"
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (nm.getNotificationChannel(channelId) == null) {
                val channel = NotificationChannel(
                    channelId,
                    channelName,
                    NotificationManager.IMPORTANCE_LOW
                ).apply {
                    description = "電波オーバーレイおよびイベントLEDランプの常時表示サービス"
                    setShowBadge(false)
                }
                nm.createNotificationChannel(channel)
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
    }

    fun updateDataDirectly(
        jsonStr: String,
        style: String?,
        opacity: Float?,
        scale: Float?,
        curve: String?
    ) {
        if (style != null && style != overlayStyle) {
            overlayStyle = style
            currentModeViewType = null
        }
        if (opacity != null) {
            overlayOpacity = opacity
        }
        if (scale != null && userCustomWidthPx == null) {
            overlayScale = scale
        }
        if (curve != null) {
            smoothGaugeCurve = curve
        }
        if (jsonStr.isNotEmpty()) {
            try {
                lastSignalJson = JSONObject(jsonStr)
            } catch (_: Exception) {}
        }
        Handler(Looper.getMainLooper()).post {
            updateFloatingViewContent()
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) return START_NOT_STICKY
        startForegroundIfNeeded()

        when (intent.action) {
            ACTION_START_OVERLAY -> {
                parseConfigFromIntent(intent)
                showFloatingOverlay()
            }
            ACTION_STOP_OVERLAY -> {
                hideFloatingOverlay()
                stopSelf()
            }
            ACTION_UPDATE_DATA -> {
                parseConfigFromIntent(intent)
                val jsonStr = intent.getStringExtra(EXTRA_JSON_DATA)
                if (jsonStr != null) {
                    try {
                        lastSignalJson = JSONObject(jsonStr)
                    } catch (_: Exception) {}
                }
                updateFloatingViewContent()
            }
            ACTION_TRIGGER_LAMP -> {
                val lampType = intent.getStringExtra(EXTRA_LAMP_TYPE) ?: "5g"
                val shape = intent.getStringExtra(EXTRA_LAMP_SHAPE) ?: "bar"
                val position = intent.getStringExtra(EXTRA_LAMP_POSITION) ?: "topCenter"
                val colorHex = intent.getStringExtra(EXTRA_LAMP_COLOR)
                triggerEventLamp(lampType, shape, position, colorHex)
            }
            ACTION_TRIGGER_VIBRATION -> {
                val vibType = intent.getStringExtra(EXTRA_VIBRATION_TYPE) ?: "5g"
                vibrateDevice(vibType)
            }
        }

        return START_NOT_STICKY
    }

    // UI References & ViewHolders for Flicker-Free In-Place Updates
    private var currentModeViewType: String? = null // "pill", "card", "compact"
    private var userCustomWidthPx: Int? = null

    private class MetricCellHolder(
        val rootCell: FrameLayout,
        val barView: View,
        val labelView: TextView,
        val label: String,
        val unit: String,
        val minVal: Double,
        val maxVal: Double,
        val defaultBarColor: Int
    ) {
        fun update(
            value: Double?,
            customPrefix: String? = null,
            smoothColor: Boolean = false,
            curveType: String = "easeOut"
        ) {
            val displayLabel = if (customPrefix != null) "$customPrefix $label" else label
            val textValue = if (value != null && !value.isNaN() && value > -200) {
                val formatted = String.format("%.1f", value)
                "$displayLabel: $formatted $unit"
            } else {
                "$displayLabel: -- $unit"
            }
            labelView.text = textValue

            val rawRatio = if (value != null && !value.isNaN() && value > -200) {
                ((value - minVal) / (maxVal - minVal)).coerceIn(0.0, 1.0)
            } else {
                0.0
            }
            val normalized = applyCurve(rawRatio, curveType).toFloat()

            if (smoothColor && value != null && !value.isNaN() && value > -200) {
                barView.setBackgroundColor(calculateSmoothColor(rawRatio, curveType))
            } else {
                barView.setBackgroundColor(defaultBarColor)
            }

            val totalWidth = rootCell.width
            if (totalWidth > 0) {
                val barW = (totalWidth * normalized).toInt()
                val lp = barView.layoutParams
                if (lp != null && lp.width != barW) {
                    lp.width = barW
                    barView.layoutParams = lp
                }
            } else {
                rootCell.post {
                    if (rootCell.isAttachedToWindow) {
                        val w = rootCell.width
                        val barW = (w * normalized).toInt()
                        val lp = barView.layoutParams
                        if (lp != null && lp.width != barW) {
                            lp.width = barW
                            barView.layoutParams = lp
                        }
                    }
                }
            }
        }

        private fun calculateSmoothColor(ratio: Double, curveType: String): Int {
            val curvedRatio = applyCurve(ratio, curveType)
            val r = curvedRatio.coerceIn(0.0, 1.0)
            val cCritical = Color.parseColor("#9C27B0")
            val cVeryWeak = Color.parseColor("#F44336")
            val cWeak = Color.parseColor("#FF9800")
            val cModerate = Color.parseColor("#8BC34A")
            val cGood = Color.parseColor("#4CAF50")
            val cExcellent = Color.parseColor("#2196F3")

            return when {
                r < 0.20 -> interpolateColor(cCritical, cVeryWeak, (r / 0.20).toFloat())
                r < 0.40 -> interpolateColor(cVeryWeak, cWeak, ((r - 0.20) / 0.20).toFloat())
                r < 0.60 -> interpolateColor(cWeak, cModerate, ((r - 0.40) / 0.20).toFloat())
                r < 0.80 -> interpolateColor(cModerate, cGood, ((r - 0.60) / 0.20).toFloat())
                else -> interpolateColor(cGood, cExcellent, ((r - 0.80) / 0.20).toFloat())
            }
        }

        private fun interpolateColor(c1: Int, c2: Int, t: Float): Int {
            val a = (Color.alpha(c1) + (Color.alpha(c2) - Color.alpha(c1)) * t).toInt()
            val r = (Color.red(c1) + (Color.red(c2) - Color.red(c1)) * t).toInt()
            val g = (Color.green(c1) + (Color.green(c2) - Color.green(c1)) * t).toInt()
            val b = (Color.blue(c1) + (Color.blue(c2) - Color.blue(c1)) * t).toInt()
            return Color.argb(a, r, g, b)
        }
    }

    private class DualRefMetricsHolder(
        val rootLayout: LinearLayout,
        val cell1: FrameLayout,
        val barView1: View,
        val labelView1: TextView,
        val valView1: TextView,
        val label1: String,
        val unit1: String,
        val min1: Double,
        val max1: Double,
        val cell2: FrameLayout,
        val barView2: View,
        val labelView2: TextView,
        val valView2: TextView,
        val label2: String,
        val unit2: String,
        val min2: Double,
        val max2: Double
    ) {
        fun update(value1: Double?, value2: Double?, curveType: String = "easeOut") {
            val hasVal1 = value1 != null && !value1.isNaN() && value1 > -200
            val v1Str = if (hasVal1) String.format("%.1f", value1) else "--"
            val color1 = if (label1 == "RQ") getRsrqColor(value1) else getSinrColor(value1)

            valView1.text = v1Str
            valView1.setTextColor(color1)

            val rawRatio1 = if (hasVal1) ((value1!! - min1) / (max1 - min1)).coerceIn(0.0, 1.0) else 0.0
            val norm1 = applyCurve(rawRatio1, curveType).toFloat()

            val bgAlpha = 45
            barView1.setBackgroundColor(Color.argb(bgAlpha, Color.red(color1), Color.green(color1), Color.blue(color1)))
            val border1 = (cell1.background as? GradientDrawable)
            border1?.setStroke(
                1,
                if (rawRatio1 > 0) Color.argb(90, Color.red(color1), Color.green(color1), Color.blue(color1))
                else Color.parseColor("#1FFFFFFF")
            )

            val hasVal2 = value2 != null && !value2.isNaN() && value2 > -200
            val v2Str = if (hasVal2) {
                if (value2!! > 0) String.format("+%.1f", value2) else String.format("%.1f", value2)
            } else {
                "--"
            }
            val color2 = if (label2 == "SNR" || label2 == "SINR") getSinrColor(value2) else getRsrqColor(value2)

            valView2.text = v2Str
            valView2.setTextColor(color2)

            val rawRatio2 = if (hasVal2) ((value2!! - min2) / (max2 - min2)).coerceIn(0.0, 1.0) else 0.0
            val norm2 = applyCurve(rawRatio2, curveType).toFloat()

            barView2.setBackgroundColor(Color.argb(bgAlpha, Color.red(color2), Color.green(color2), Color.blue(color2)))
            val border2 = (cell2.background as? GradientDrawable)
            border2?.setStroke(
                1,
                if (rawRatio2 > 0) Color.argb(90, Color.red(color2), Color.green(color2), Color.blue(color2))
                else Color.parseColor("#1FFFFFFF")
            )

            val w1 = cell1.width
            if (w1 > 0) {
                val bw1 = (w1 * norm1).toInt()
                val lp1 = barView1.layoutParams
                if (lp1 != null && lp1.width != bw1) {
                    lp1.width = bw1
                    barView1.layoutParams = lp1
                }
            } else {
                cell1.post {
                    if (cell1.isAttachedToWindow) {
                        val bw1 = (cell1.width * norm1).toInt()
                        val lp1 = barView1.layoutParams
                        if (lp1 != null && lp1.width != bw1) {
                            lp1.width = bw1
                            barView1.layoutParams = lp1
                        }
                    }
                }
            }

            val w2 = cell2.width
            if (w2 > 0) {
                val bw2 = (w2 * norm2).toInt()
                val lp2 = barView2.layoutParams
                if (lp2 != null && lp2.width != bw2) {
                    lp2.width = bw2
                    barView2.layoutParams = lp2
                }
            } else {
                cell2.post {
                    if (cell2.isAttachedToWindow) {
                        val bw2 = (cell2.width * norm2).toInt()
                        val lp2 = barView2.layoutParams
                        if (lp2 != null && lp2.width != bw2) {
                            lp2.width = bw2
                            barView2.layoutParams = lp2
                        }
                    }
                }
            }
        }
    }

    private class AntennaPictViewHolder(
        val container: LinearLayout,
        val barViews: List<View>,
        val badgeTextView: TextView
    ) {
        fun update(barCount: Int, modeBadge: String, themeColor: Int) {
            badgeTextView.text = modeBadge
            badgeTextView.setTextColor(themeColor)
            val bg = GradientDrawable().apply {
                setColor(Color.argb(38, Color.red(themeColor), Color.green(themeColor), Color.blue(themeColor)))
                cornerRadius = 8f
                setStroke(1, Color.argb(150, Color.red(themeColor), Color.green(themeColor), Color.blue(themeColor)))
            }
            container.background = bg
            barViews.forEachIndexed { index, bar ->
                val isActive = index < barCount
                bar.setBackgroundColor(if (isActive) themeColor else Color.parseColor("#33FFFFFF"))
            }
        }
    }

    private class PillViewHolder(
        val pillLayout: LinearLayout,
        val pictHolder: AntennaPictViewHolder,
        val badgeText: TextView,
        val batteryText: TextView
    )

    private class CardViewHolder(
        val mainCard: FrameLayout,
        val badgeView: TextView,
        val opView: TextView,
        val loginView: TextView,
        val batteryView: TextView,
        val nrHeader: TextView,
        val nrRsrpCell: MetricCellHolder,
        val nrRefCell: DualRefMetricsHolder,
        val lteHeader: TextView,
        val lteRsrpCell: MetricCellHolder,
        val lteRefCell: DualRefMetricsHolder
    )

    private class CompactViewHolder(
        val mainCard: FrameLayout,
        val statusView: TextView,
        val loginView: TextView,
        val batteryView: TextView,
        val nrCell: MetricCellHolder,
        val lteCell: MetricCellHolder
    )

    private var pillHolder: PillViewHolder? = null
    private var cardHolder: CardViewHolder? = null
    private var compactHolder: CompactViewHolder? = null

    private fun parseConfigFromIntent(intent: Intent) {
        if (intent.hasExtra("overlayStyle")) {
            val newStyle = intent.getStringExtra("overlayStyle") ?: overlayStyle
            if (newStyle != overlayStyle) {
                overlayStyle = newStyle
                currentModeViewType = null
            }
        }
        if (intent.hasExtra("overlayOpacity")) {
            overlayOpacity = intent.getFloatExtra("overlayOpacity", overlayOpacity)
        }
        if (intent.hasExtra("overlayScale") && userCustomWidthPx == null) {
            overlayScale = intent.getFloatExtra("overlayScale", overlayScale)
        }
        if (intent.hasExtra("smoothGaugeCurve")) {
            smoothGaugeCurve = intent.getStringExtra("smoothGaugeCurve") ?: smoothGaugeCurve
        }
    }

    // ----------------------------------------------------
    // Floating Overlay Widget
    // ----------------------------------------------------
    private fun showFloatingOverlay() {
        if (overlayContainer != null) {
            updateFloatingViewContent()
            return
        }

        val overlayType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        overlayLayoutParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            overlayType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = (screenWidth * 0.05).toInt()
            y = (screenHeight * 0.15).toInt()
        }

        updateScreenDimensions()
        val container = FrameLayout(this)
        overlayContainer = container

        buildOverlayView()

        try {
            windowManager?.addView(overlayContainer, overlayLayoutParams)
        } catch (e: Exception) {
            e.printStackTrace()
        }
        updateFloatingViewContent()
    }

    private fun hideFloatingOverlay() {
        snapAnimator?.cancel()
        snapAnimator = null
        if (overlayContainer != null) {
            try {
                if (overlayContainer?.isAttachedToWindow == true) {
                    windowManager?.removeView(overlayContainer)
                }
            } catch (_: Exception) {}
            overlayContainer = null
            overlayLayoutParams = null
            pillHolder = null
            cardHolder = null
            compactHolder = null
            currentModeViewType = null
        }
    }

    private fun dpToPx(dp: Float): Int {
        return android.util.TypedValue.applyDimension(
            android.util.TypedValue.COMPLEX_UNIT_DIP,
            dp,
            Resources.getSystem().displayMetrics
        ).toInt()
    }

    private fun buildOverlayView() {
        val container = overlayContainer ?: return
        container.removeAllViews()

        if (!isExpanded) {
            currentModeViewType = "pill"
            val pillView = createMiniPillView()
            container.addView(pillView)
            setupTouchAndGesture(container, isHandle = false)
            updateFloatingViewContent()
            return
        }

        val baseWidthDp = 280f * overlayScale
        val widthPx = userCustomWidthPx ?: dpToPx(baseWidthDp)

        val mainCard = FrameLayout(this).apply {
            layoutParams = FrameLayout.LayoutParams(
                widthPx,
                FrameLayout.LayoutParams.WRAP_CONTENT
            )
            val bgDrawable = GradientDrawable().apply {
                setColor(Color.parseColor("#121212"))
                cornerRadius = dpToPx(12f).toFloat()
                setStroke(dpToPx(1f), Color.parseColor("#3300ADB5"))
            }
            background = bgDrawable
            alpha = overlayOpacity
            clipToOutline = true
        }

        // Inner Content
        if (overlayStyle == "compact") {
            currentModeViewType = "compact"
            val contentView = createCompactContentView(mainCard)
            mainCard.addView(contentView)
        } else {
            currentModeViewType = "card"
            val contentView = createCardContentView(mainCard)
            mainCard.addView(contentView)
        }

        // Resize Handle (◢) at Bottom-Right
        val resizeHandle = createResizeHandleView()
        val handleParams = FrameLayout.LayoutParams(dpToPx(24f), dpToPx(24f)).apply {
            gravity = Gravity.BOTTOM or Gravity.END
        }
        mainCard.addView(resizeHandle, handleParams)

        container.addView(mainCard)

        setupTouchAndGesture(mainCard, isHandle = false)
        setupResizeHandleTouch(resizeHandle, mainCard)

        updateFloatingViewContent()
    }

    private fun updateFloatingViewContent() {
        if (overlayContainer == null) return

        val requiredType = if (!isExpanded) "pill" else overlayStyle
        if (currentModeViewType != requiredType) {
            buildOverlayView()
            return
        }

        val json = lastSignalJson
        val opNameRaw = json?.optString("operatorName", "Rakuten") ?: "Rakuten"
        val opName = if (opNameRaw == "null" || opNameRaw.isBlank() || opNameRaw == "--") {
            if (json?.optBoolean("isConnecting", false) == true) "--" else "Rakuten"
        } else {
            opNameRaw
        }
        val modeBadgeRaw = json?.optString("modeBadge", json.optString("connectionModeBadge", "5G+")) ?: "5G+"
        val modeBadge = if (modeBadgeRaw == "null" || modeBadgeRaw.isBlank()) "5G+" else modeBadgeRaw
        val isConnecting = json?.optBoolean("isConnecting", false) ?: false
        val isLoggedIn = json?.optBoolean("isLoggedIn", false) ?: false
        val notationRaw = json?.optString("generationNotation", "4g_5g") ?: "4g_5g"
        val notation = if (notationRaw == "null" || notationRaw.isBlank()) "4g_5g" else notationRaw
        val smoothColor = json?.optBoolean("smoothGaugeColor", false) ?: false

        val isLteNr = notation == "lte_nr"
        val nrLabel = if (isLteNr) "NR" else "5G"
        val lteLabel = if (isLteNr) "LTE" else "4G"

        val isSub6 = modeBadge.contains("+")
        val badge = if (isSub6) "$nrLabel+" else if (modeBadge.contains("5G") || modeBadge.contains("NR")) nrLabel else if (modeBadge.contains("4G") || modeBadge.contains("LTE")) lteLabel else modeBadge

        val rawNrBand = json?.optString("nrBand", "--") ?: "--"
        val nrBand = if (rawNrBand == "0" || rawNrBand == "n0" || rawNrBand == "null" || rawNrBand.isBlank()) "--" else rawNrBand
        val rawNrPci = json?.optString("nrPci", "--") ?: "--"
        val nrPci = if (rawNrPci == "0" || rawNrPci == "null" || rawNrPci.isBlank()) "--" else rawNrPci
        val nrRsrp = json?.optDouble("nrRsrp", Double.NaN)
        val nrRsrq = json?.optDouble("nrRsrq", Double.NaN)
        val nrSnr = json?.optDouble("nrSnr", Double.NaN)

        val rawLteBand = json?.optString("lteBand", "--") ?: "--"
        val lteBand = if (rawLteBand == "0" || rawLteBand == "B0" || rawLteBand == "null" || rawLteBand.isBlank()) "--" else rawLteBand
        val rawLtePci = json?.optString("ltePci", "--") ?: "--"
        val ltePci = if (rawLtePci == "0" || rawLtePci == "null" || rawLtePci.isBlank()) "--" else rawLtePci
        val lteRsrp = json?.optDouble("lteRsrp", Double.NaN)
        val lteRsrq = json?.optDouble("lteRsrq", Double.NaN)
        val lteSinr = json?.optDouble("lteSinr", Double.NaN)

        val isBatteryPresent = json?.optBoolean("isBatteryPresent", true) ?: true
        val batteryPercent = if (json?.has("batteryPercent") == true && !json.isNull("batteryPercent")) json.optInt("batteryPercent") else null
        val isCharging = json?.optBoolean("isCharging", false) ?: false
        val tempVal = if (json?.has("batteryTemperature") == true && !json.isNull("batteryTemperature")) json.optDouble("batteryTemperature") else null
        val remainingTimeRaw = if (json?.has("remainingTimeHHMM") == true && !json.isNull("remainingTimeHHMM")) json.optString("remainingTimeHHMM", "") else ""
        val remainingTimeStr = if (remainingTimeRaw == "null") "" else remainingTimeRaw
        val latencyMs = if (json?.has("routerLatencyMs") == true && !json.isNull("routerLatencyMs")) json.optInt("routerLatencyMs") else null
        val is5gDisabled = json?.optBoolean("is5gDisabledByConfig", false) ?: false
        val isDelayed = latencyMs != null && latencyMs > 150

        val batSb = StringBuilder()
        if (!isBatteryPresent) {
            batSb.append("AC給電")
            if (tempVal != null && !tempVal.isNaN()) {
                batSb.append(" ").append(tempVal.toInt()).append("℃")
            }
        } else {
            if (batteryPercent != null) {
                batSb.append("🔋").append(batteryPercent).append("%")
                if (isCharging) batSb.append("⚡")
            }
            if (tempVal != null && !tempVal.isNaN()) {
                if (batSb.isNotEmpty()) batSb.append(" ")
                batSb.append(tempVal.toInt()).append("℃")
            }
            if (remainingTimeStr.isNotEmpty()) {
                if (batSb.isNotEmpty()) batSb.append(" ")
                batSb.append(remainingTimeStr)
            }
        }
        val batterySummary = batSb.toString()

        val mainRsrp = if (nrRsrp != null && !nrRsrp.isNaN() && nrRsrp > -150) nrRsrp else lteRsrp
        val barCount = when {
            mainRsrp == null || mainRsrp.isNaN() || mainRsrp <= -120.0 -> 0
            mainRsrp <= -110.0 -> 1
            mainRsrp <= -100.0 -> 2
            mainRsrp <= -90.0 -> 3
            else -> 4
        }
        val themeColor = if (badge.contains("5G") || badge.contains("NR")) Color.parseColor("#00E5FF") else Color.parseColor("#2196F3")

        if (!isExpanded) {
            val holder = pillHolder ?: return
            val mainSnr = if (nrSnr != null && !nrSnr.isNaN()) nrSnr else lteSinr

            val rpStr = if (mainRsrp != null && !mainRsrp.isNaN() && mainRsrp > -150) "${mainRsrp.toInt()}" else "--"
            val snrStr = if (mainSnr != null && !mainSnr.isNaN()) String.format("%.0f", mainSnr) else "--"

            val rpColor = getRsrpColor(mainRsrp)
            val snrColor = getSinrColor(mainSnr)

            holder.pictHolder.update(barCount, if (isConnecting) "..." else badge, themeColor)

            val ssb = SpannableStringBuilder()
            val rpStart = ssb.length
            ssb.append(rpStr)
            ssb.setSpan(
                ForegroundColorSpan(rpColor),
                rpStart,
                ssb.length,
                Spanned.SPAN_EXCLUSIVE_EXCLUSIVE
            )
            ssb.append(" / ")
            val snrStart = ssb.length
            ssb.append(snrStr)
            ssb.setSpan(
                ForegroundColorSpan(snrColor),
                snrStart,
                ssb.length,
                Spanned.SPAN_EXCLUSIVE_EXCLUSIVE
            )

            if (latencyMs != null) {
                val latStart = ssb.length
                ssb.append(" ${latencyMs}ms")
                ssb.setSpan(
                    ForegroundColorSpan(getLatencyColor(latencyMs)),
                    latStart,
                    ssb.length,
                    Spanned.SPAN_EXCLUSIVE_EXCLUSIVE
                )
            }

            holder.badgeText.text = ssb

            val pillBatSb = SpannableStringBuilder()
            if (!isBatteryPresent) {
                pillBatSb.append("AC給電")
                if (tempVal != null && !tempVal.isNaN()) {
                    pillBatSb.append(" ")
                    val tempStart = pillBatSb.length
                    pillBatSb.append("${tempVal.toInt()}℃")
                    pillBatSb.setSpan(
                        ForegroundColorSpan(getTempColor(tempVal)),
                        tempStart,
                        pillBatSb.length,
                        Spanned.SPAN_EXCLUSIVE_EXCLUSIVE
                    )
                }
            } else {
                if (batteryPercent != null) {
                    pillBatSb.append("🔋").append(batteryPercent.toString()).append("%")
                    if (isCharging) pillBatSb.append("⚡")
                }
                if (tempVal != null && !tempVal.isNaN()) {
                    if (pillBatSb.isNotEmpty()) pillBatSb.append(" ")
                    val tempStart = pillBatSb.length
                    pillBatSb.append("${tempVal.toInt()}℃")
                    pillBatSb.setSpan(
                        ForegroundColorSpan(getTempColor(tempVal)),
                        tempStart,
                        pillBatSb.length,
                        Spanned.SPAN_EXCLUSIVE_EXCLUSIVE
                    )
                }
            }

            if (pillBatSb.isNotEmpty()) {
                holder.batteryText.visibility = View.VISIBLE
                holder.batteryText.text = pillBatSb
            } else {
                holder.batteryText.visibility = View.GONE
            }
            holder.pillLayout.alpha = overlayOpacity
            return
        }

        if (overlayStyle == "card") {
            val holder = cardHolder ?: return
            holder.mainCard.alpha = overlayOpacity
            holder.badgeView.text = if (isConnecting) "[ 接続中... ]" else "[ $modeBadge ]"
            holder.badgeView.setTextColor(if (isConnecting) Color.YELLOW else Color.parseColor("#00E5FF"))

            val opText = if (isDelayed) "${latencyMs}ms" else opName
            val latColor = getLatencyColor(latencyMs)
            holder.opView.text = opText
            holder.opView.setTextColor(if (isDelayed) latColor else Color.LTGRAY)
            if (latencyMs != null && opText.isNotBlank() && opText != "--") {
                val opBg = GradientDrawable().apply {
                    setColor(Color.argb(0x33, Color.red(latColor), Color.green(latColor), Color.blue(latColor)))
                    cornerRadius = dpToPx(3f).toFloat()
                    setStroke(dpToPx(0.8f), Color.argb(0x88, Color.red(latColor), Color.green(latColor), Color.blue(latColor)))
                }
                holder.opView.background = opBg
                holder.opView.setPadding(dpToPx(4f), dpToPx(1f), dpToPx(4f), dpToPx(1f))
            } else {
                holder.opView.background = null
                holder.opView.setPadding(0, 0, 0, 0)
            }

            holder.loginView.visibility = if (!isLoggedIn && !isConnecting) View.VISIBLE else View.GONE
            if (batterySummary.isNotEmpty()) {
                holder.batteryView.visibility = View.VISIBLE
                holder.batteryView.text = batterySummary
            } else {
                holder.batteryView.visibility = View.GONE
            }

            val nrTitle = if (nrBand == "--" && nrPci == "--") {
                if (modeBadge.contains("+")) "$nrLabel+ (--)" else "$nrLabel (--)"
            } else {
                if (modeBadge.contains("+")) "$nrLabel+ ($nrBand/$nrPci)" else "$nrLabel ($nrBand/$nrPci)"
            }

            if (is5gDisabled) {
                holder.nrHeader.text = "$nrLabel (5Gは無効です)"
                holder.nrHeader.setTextColor(Color.GRAY)
                holder.nrRsrpCell.rootCell.visibility = View.GONE
                holder.nrRefCell.rootLayout.visibility = View.GONE
            } else {
                holder.nrRsrpCell.rootCell.visibility = View.VISIBLE
                holder.nrRefCell.rootLayout.visibility = View.VISIBLE
                holder.nrHeader.setTextColor(Color.parseColor("#00E5FF"))
                holder.nrHeader.text = nrTitle
                holder.nrRsrpCell.update(nrRsrp, smoothColor = smoothColor, curveType = smoothGaugeCurve)
                holder.nrRefCell.update(nrRsrq, nrSnr, curveType = smoothGaugeCurve)
            }

            val lteTitle = if (lteBand == "--" && ltePci == "--") {
                "$lteLabel (--)"
            } else {
                "$lteLabel ($lteBand/$ltePci)"
            }

            holder.lteHeader.text = lteTitle
            holder.lteRsrpCell.update(lteRsrp, smoothColor = smoothColor, curveType = smoothGaugeCurve)
            holder.lteRefCell.update(lteRsrq, lteSinr, curveType = smoothGaugeCurve)
        } else {
            val holder = compactHolder ?: return
            holder.mainCard.alpha = overlayOpacity
            val statusText = if (isDelayed) "[$modeBadge] ${latencyMs}ms" else "[$modeBadge] $opName"
            holder.statusView.text = statusText
            holder.statusView.setTextColor(if (isDelayed) getLatencyColor(latencyMs) else Color.WHITE)

            holder.loginView.visibility = if (!isLoggedIn && !isConnecting) View.VISIBLE else View.GONE
            if (batterySummary.isNotEmpty()) {
                holder.batteryView.visibility = View.VISIBLE
                holder.batteryView.text = batterySummary
            } else {
                holder.batteryView.visibility = View.GONE
            }

            if (is5gDisabled) {
                holder.nrCell.rootCell.visibility = View.GONE
            } else {
                holder.nrCell.rootCell.visibility = View.VISIBLE
                val nrTitle = if (modeBadge.contains("+")) {
                    if (nrBand == "--") "$nrLabel+ --" else "$nrLabel+ $nrBand"
                } else {
                    if (nrBand == "--") "$nrLabel --" else "$nrLabel $nrBand"
                }
                holder.nrCell.update(nrRsrp, customPrefix = nrTitle, smoothColor = smoothColor, curveType = smoothGaugeCurve)
            }

            val lteTitle = if (lteBand == "--") "$lteLabel --" else "$lteLabel $lteBand"
            holder.lteCell.update(lteRsrp, customPrefix = lteTitle, smoothColor = smoothColor, curveType = smoothGaugeCurve)
        }
    }

    private fun createAntennaPictView(): Pair<View, AntennaPictViewHolder> {
        val container = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dpToPx(4f), dpToPx(2f), dpToPx(4f), dpToPx(2f))
            val bg = GradientDrawable().apply {
                setColor(Color.parseColor("#2200E5FF"))
                cornerRadius = dpToPx(4f).toFloat()
                setStroke(dpToPx(0.8f), Color.parseColor("#6600E5FF"))
            }
            background = bg
        }

        val barsLayout = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.BOTTOM
        }

        val barViews = mutableListOf<View>()
        for (i in 0..3) {
            val barH = dpToPx(3.5f + (i * 2.5f))
            val bar = View(this).apply {
                layoutParams = LinearLayout.LayoutParams(dpToPx(2f), barH).apply {
                    setMargins(dpToPx(0.5f), 0, dpToPx(0.5f), 0)
                }
                setBackgroundColor(Color.parseColor("#00E5FF"))
            }
            barViews.add(bar)
            barsLayout.addView(bar)
        }

        val badgeText = TextView(this).apply {
            text = "5G"
            textSize = 9f
            setTextColor(Color.parseColor("#00E5FF"))
            typeface = Typeface.DEFAULT_BOLD
            setPadding(dpToPx(3f), 0, 0, 0)
        }

        container.addView(barsLayout)
        container.addView(badgeText)

        return Pair(container, AntennaPictViewHolder(container, barViews, badgeText))
    }

    private fun createMiniPillView(): View {
        val pill = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dpToPx(6f), dpToPx(4f), dpToPx(8f), dpToPx(4f))
            val bg = GradientDrawable().apply {
                setColor(Color.parseColor("#1E1E1E"))
                cornerRadius = dpToPx(18f).toFloat()
                setStroke(dpToPx(1.2f), Color.parseColor("#00E5FF"))
            }
            background = bg
            alpha = overlayOpacity
        }

        val (pictView, pictHolder) = createAntennaPictView()

        val labelText = TextView(this).apply {
            text = "RP:-- SNR:--"
            textSize = 10f
            setTextColor(Color.WHITE)
            typeface = Typeface.DEFAULT_BOLD
            setPadding(dpToPx(4f), 0, 0, 0)
        }

        val batteryText = TextView(this).apply {
            text = "🔋--%"
            textSize = 9.5f
            setTextColor(Color.LTGRAY)
            typeface = Typeface.MONOSPACE
            setPadding(dpToPx(4f), 0, 0, 0)
        }

        pill.addView(pictView)
        pill.addView(labelText)
        pill.addView(batteryText)

        pillHolder = PillViewHolder(pill, pictHolder, labelText, batteryText)
        return pill
    }

    private fun createCardContentView(mainCard: FrameLayout): View {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dpToPx(8f), dpToPx(6f), dpToPx(8f), dpToPx(6f))
        }

        // Header Row
        val header = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        }

        val badgeView = TextView(this).apply {
            text = "[ 5G+ ]"
            textSize = 10f
            setTextColor(Color.parseColor("#00E5FF"))
            typeface = Typeface.DEFAULT_BOLD
            isSingleLine = true
            maxLines = 1
            val bg = GradientDrawable().apply {
                setColor(Color.parseColor("#2200E5FF"))
                cornerRadius = dpToPx(4f).toFloat()
            }
            background = bg
            setPadding(dpToPx(4f), dpToPx(1f), dpToPx(4f), dpToPx(1f))
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        }

        val opView = TextView(this).apply {
            text = "Rakuten"
            textSize = 10f
            setTextColor(Color.LTGRAY)
            typeface = Typeface.DEFAULT_BOLD
            isSingleLine = true
            maxLines = 1
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                setMargins(dpToPx(4f), 0, 0, 0)
            }
        }

        val loginView = TextView(this).apply {
            text = "要ログイン"
            textSize = 8.5f
            setTextColor(Color.parseColor("#FFB300"))
            typeface = Typeface.DEFAULT_BOLD
            isSingleLine = true
            maxLines = 1
            val bg = GradientDrawable().apply {
                setColor(Color.parseColor("#22FFB300"))
                cornerRadius = dpToPx(3f).toFloat()
            }
            background = bg
            setPadding(dpToPx(3f), dpToPx(1f), dpToPx(3f), dpToPx(1f))
            visibility = View.GONE
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                setMargins(dpToPx(4f), 0, 0, 0)
            }
        }

        val spacer = View(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                0,
                0,
                1f
            )
        }

        val batteryView = TextView(this).apply {
            text = "🔋--%"
            textSize = 9.5f
            setTextColor(Color.WHITE)
            typeface = Typeface.MONOSPACE
            gravity = Gravity.END or Gravity.CENTER_VERTICAL
            isSingleLine = true
            maxLines = 1
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                setMargins(dpToPx(4f), 0, 0, 0)
            }
        }

        header.addView(badgeView)
        header.addView(opView)
        header.addView(loginView)
        header.addView(spacer)
        header.addView(batteryView)
        root.addView(header)

        // 5G Header & Metric Cells
        val nrHeader = TextView(this).apply {
            text = "5G (n77/--)"
            textSize = 9.5f
            setTextColor(Color.parseColor("#00E5FF"))
            typeface = Typeface.DEFAULT_BOLD
            isSingleLine = true
            maxLines = 1
            ellipsize = android.text.TextUtils.TruncateAt.END
            setPadding(0, dpToPx(4f), 0, dpToPx(2f))
        }
        root.addView(nrHeader)

        val nrRsrpCell = createMetricCellHolder("RSRP", "dBm", -120.0, -70.0, Color.parseColor("#00ADB5"))
        val nrRefCell = createDualRefMetricsHolder("RQ", "dB", "SNR", "dB", -22.0, -3.0, -6.0, 24.0)

        root.addView(nrRsrpCell.rootCell)
        root.addView(nrRefCell.rootLayout)

        // 4G Header & Metric Cells
        val lteHeader = TextView(this).apply {
            text = "4G (B3/--)"
            textSize = 9.5f
            setTextColor(Color.parseColor("#64B5F6"))
            typeface = Typeface.DEFAULT_BOLD
            isSingleLine = true
            maxLines = 1
            ellipsize = android.text.TextUtils.TruncateAt.END
            setPadding(0, dpToPx(4f), 0, dpToPx(2f))
        }
        root.addView(lteHeader)

        val lteRsrpCell = createMetricCellHolder("RSRP", "dBm", -120.0, -70.0, Color.parseColor("#2196F3"))
        val lteRefCell = createDualRefMetricsHolder("RQ", "dB", "SINR", "dB", -22.0, -3.0, -6.0, 24.0)

        root.addView(lteRsrpCell.rootCell)
        root.addView(lteRefCell.rootLayout)

        cardHolder = CardViewHolder(
            mainCard = mainCard,
            badgeView = badgeView,
            opView = opView,
            loginView = loginView,
            batteryView = batteryView,
            nrHeader = nrHeader,
            nrRsrpCell = nrRsrpCell,
            nrRefCell = nrRefCell,
            lteHeader = lteHeader,
            lteRsrpCell = lteRsrpCell,
            lteRefCell = lteRefCell
        )

        return root
    }

    private fun createCompactContentView(mainCard: FrameLayout): View {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dpToPx(6f), dpToPx(4f), dpToPx(6f), dpToPx(4f))
        }

        val header = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                setMargins(0, 0, 0, dpToPx(2f))
            }
        }

        val statusView = TextView(this).apply {
            text = "[5G+] Rakuten"
            textSize = 9.5f
            setTextColor(Color.parseColor("#00E5FF"))
            typeface = Typeface.DEFAULT_BOLD
            isSingleLine = true
            maxLines = 1
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        }

        val loginView = TextView(this).apply {
            text = "要ログイン"
            textSize = 8.5f
            setTextColor(Color.parseColor("#FFB300"))
            typeface = Typeface.DEFAULT_BOLD
            isSingleLine = true
            maxLines = 1
            val bg = GradientDrawable().apply {
                setColor(Color.parseColor("#22FFB300"))
                cornerRadius = dpToPx(3f).toFloat()
            }
            background = bg
            setPadding(dpToPx(3f), dpToPx(0.5f), dpToPx(3f), dpToPx(0.5f))
            visibility = View.GONE
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                setMargins(dpToPx(4f), 0, 0, 0)
            }
        }

        val spacer = View(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                0,
                0,
                1f
            )
        }

        val batteryView = TextView(this).apply {
            text = "🔋--%"
            textSize = 9f
            setTextColor(Color.WHITE)
            typeface = Typeface.MONOSPACE
            gravity = Gravity.END or Gravity.CENTER_VERTICAL
            isSingleLine = true
            maxLines = 1
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                setMargins(dpToPx(4f), 0, 0, 0)
            }
        }

        header.addView(statusView)
        header.addView(loginView)
        header.addView(spacer)
        header.addView(batteryView)
        root.addView(header)

        val nrCell = createMetricCellHolder("RSRP", "dBm", -120.0, -70.0, Color.parseColor("#00E5FF"))
        val lteCell = createMetricCellHolder("RSRP", "dBm", -120.0, -70.0, Color.parseColor("#2196F3"))

        root.addView(nrCell.rootCell)
        root.addView(lteCell.rootCell)

        compactHolder = CompactViewHolder(
            mainCard = mainCard,
            statusView = statusView,
            loginView = loginView,
            batteryView = batteryView,
            nrCell = nrCell,
            lteCell = lteCell
        )

        return root
    }

    private fun createDualRefMetricsHolder(
        label1: String,
        unit1: String,
        label2: String,
        unit2: String,
        min1: Double = -22.0,
        max1: Double = -3.0,
        min2: Double = -6.0,
        max2: Double = 24.0
    ): DualRefMetricsHolder {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dpToPx(15f)
            ).apply {
                setMargins(0, dpToPx(1f), 0, dpToPx(1f))
            }
        }

        // Sub-card 1 (RQ)
        val cell1 = FrameLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.MATCH_PARENT, 1f).apply {
                setMargins(dpToPx(1f), 0, dpToPx(1.5f), 0)
            }
            val bg = GradientDrawable().apply {
                setColor(Color.parseColor("#0AFFFFFF"))
                cornerRadius = dpToPx(3f).toFloat()
                setStroke(dpToPx(0.5f), Color.parseColor("#1FFFFFFF"))
            }
            background = bg
            clipToOutline = true
        }
        val barView1 = View(this).apply {
            layoutParams = FrameLayout.LayoutParams(0, FrameLayout.LayoutParams.MATCH_PARENT, Gravity.START)
        }
        cell1.addView(barView1)

        val content1 = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT)
            setPadding(dpToPx(3.5f), 0, dpToPx(3.5f), 0)
        }
        val labelView1 = TextView(this).apply {
            text = label1
            textSize = 7.5f
            setTextColor(Color.parseColor("#88FFFFFF"))
            typeface = Typeface.DEFAULT_BOLD
            isSingleLine = true
            maxLines = 1
        }
        val valView1 = TextView(this).apply {
            text = "--"
            textSize = 8.5f
            setTextColor(Color.parseColor("#757575"))
            typeface = Typeface.MONOSPACE
            gravity = Gravity.END or Gravity.CENTER_VERTICAL
            isSingleLine = true
            maxLines = 1
            ellipsize = android.text.TextUtils.TruncateAt.END
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        }
        content1.addView(labelView1)
        content1.addView(valView1)
        cell1.addView(content1)

        // Sub-card 2 (SNR / SINR)
        val cell2 = FrameLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.MATCH_PARENT, 1f).apply {
                setMargins(dpToPx(1.5f), 0, dpToPx(1f), 0)
            }
            val bg = GradientDrawable().apply {
                setColor(Color.parseColor("#0AFFFFFF"))
                cornerRadius = dpToPx(3f).toFloat()
                setStroke(dpToPx(0.5f), Color.parseColor("#1FFFFFFF"))
            }
            background = bg
            clipToOutline = true
        }
        val barView2 = View(this).apply {
            layoutParams = FrameLayout.LayoutParams(0, FrameLayout.LayoutParams.MATCH_PARENT, Gravity.START)
        }
        cell2.addView(barView2)

        val content2 = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT)
            setPadding(dpToPx(3.5f), 0, dpToPx(3.5f), 0)
        }
        val labelView2 = TextView(this).apply {
            text = label2
            textSize = 7.5f
            setTextColor(Color.parseColor("#88FFFFFF"))
            typeface = Typeface.DEFAULT_BOLD
            isSingleLine = true
            maxLines = 1
        }
        val valView2 = TextView(this).apply {
            text = "--"
            textSize = 8.5f
            setTextColor(Color.parseColor("#757575"))
            typeface = Typeface.MONOSPACE
            gravity = Gravity.END or Gravity.CENTER_VERTICAL
            isSingleLine = true
            maxLines = 1
            ellipsize = android.text.TextUtils.TruncateAt.END
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        }
        content2.addView(labelView2)
        content2.addView(valView2)
        cell2.addView(content2)

        root.addView(cell1)
        root.addView(cell2)

        return DualRefMetricsHolder(
            rootLayout = root,
            cell1 = cell1,
            barView1 = barView1,
            labelView1 = labelView1,
            valView1 = valView1,
            label1 = label1,
            unit1 = unit1,
            min1 = min1,
            max1 = max1,
            cell2 = cell2,
            barView2 = barView2,
            labelView2 = labelView2,
            valView2 = valView2,
            label2 = label2,
            unit2 = unit2,
            min2 = min2,
            max2 = max2
        )
    }

    private fun createMetricCellHolder(
        label: String,
        unit: String,
        minVal: Double,
        maxVal: Double,
        barColor: Int
    ): MetricCellHolder {
        val cell = FrameLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dpToPx(16f)
            ).apply {
                setMargins(dpToPx(1f), dpToPx(1f), dpToPx(1f), dpToPx(1f))
            }
            val bg = GradientDrawable().apply {
                setColor(Color.parseColor("#1AFFFFFF"))
                cornerRadius = dpToPx(3f).toFloat()
            }
            background = bg
            clipToOutline = true
        }

        val barView = View(this).apply {
            layoutParams = FrameLayout.LayoutParams(0, FrameLayout.LayoutParams.MATCH_PARENT)
            setBackgroundColor(barColor)
            alpha = 0.35f
        }
        cell.addView(barView)

        val labelView = TextView(this).apply {
            text = "$label: -- $unit"
            textSize = 8.5f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER_VERTICAL or Gravity.START
            isSingleLine = true
            maxLines = 1
            ellipsize = android.text.TextUtils.TruncateAt.END
            setPadding(dpToPx(4f), 0, dpToPx(4f), 0)
        }
        cell.addView(labelView)

        return MetricCellHolder(
            rootCell = cell,
            barView = barView,
            labelView = labelView,
            label = label,
            unit = unit,
            minVal = minVal,
            maxVal = maxVal,
            defaultBarColor = barColor
        )
    }

    private fun createResizeHandleView(): View {
        return object : View(this) {
            private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.parseColor("#88FFFFFF")
                style = Paint.Style.STROKE
                strokeWidth = dpToPx(1.5f).toFloat()
            }

            override fun onDraw(canvas: Canvas) {
                super.onDraw(canvas)
                val w = width.toFloat()
                val h = height.toFloat()
                // Draw bottom-right triangle lines ◢
                canvas.drawLine(w - dpToPx(4f), h - dpToPx(12f), w - dpToPx(12f), h - dpToPx(4f), paint)
                canvas.drawLine(w - dpToPx(4f), h - dpToPx(7f), w - dpToPx(7f), h - dpToPx(4f), paint)
            }
        }
    }

    // ----------------------------------------------------
    // Gesture & Touch Listeners
    // ----------------------------------------------------
    private fun setupTouchAndGesture(targetView: View, isHandle: Boolean) {
        val gestureDetector = GestureDetector(this, object : GestureDetector.SimpleOnGestureListener() {
            override fun onSingleTapConfirmed(e: MotionEvent): Boolean {
                // Toggle expand / fold
                isExpanded = !isExpanded
                currentModeViewType = null
                buildOverlayView()
                return true
            }

            override fun onDoubleTap(e: MotionEvent): Boolean {
                // Return to Main App
                val intent = Intent(this@OverlayService, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                }
                startActivity(intent)
                return true
            }
        })

        targetView.setOnTouchListener { _, event ->
            if (gestureDetector.onTouchEvent(event)) {
                return@setOnTouchListener true
            }

            val params = overlayLayoutParams ?: return@setOnTouchListener false

            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialX = params.x
                    initialY = params.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = (event.rawX - initialTouchX).toInt()
                    val dy = (event.rawY - initialTouchY).toInt()
                    val overlayH = overlayContainer?.height ?: dpToPx(120f)
                    val maxY = max(0, screenHeight - overlayH - dpToPx(10f))
                    params.x = initialX + dx
                    params.y = (initialY + dy).coerceIn(0, maxY)
                    try {
                        windowManager?.updateViewLayout(overlayContainer, params)
                    } catch (_: Exception) {}
                    true
                }
                MotionEvent.ACTION_UP -> {
                    snapToNearestEdge()
                    true
                }
                else -> false
            }
        }
    }

    private fun setupResizeHandleTouch(handleView: View, cardView: View) {
        handleView.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    isResizing = true
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    initialWidth = cardView.width
                    initialHeight = cardView.height
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    if (isResizing) {
                        val dx = (event.rawX - initialTouchX).toInt()
                        val newWidth = max(dpToPx(190f), min(screenWidth - dpToPx(20f), initialWidth + dx))

                        val cardParams = cardView.layoutParams
                        cardParams.width = newWidth
                        cardParams.height = FrameLayout.LayoutParams.WRAP_CONTENT
                        cardView.layoutParams = cardParams

                        userCustomWidthPx = newWidth
                        overlayScale = (newWidth.toFloat() / dpToPx(280f)).coerceIn(0.6f, 2.0f)

                        // リアルタイムに各セルのバー幅を更新
                        updateFloatingViewContent()
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    isResizing = false
                    userCustomWidthPx = cardView.width
                    true
                }
                else -> false
            }
        }
    }

    private fun snapToNearestEdge() {
        val params = overlayLayoutParams ?: return
        val currentX = params.x
        val targetX = if (currentX + (overlayContainer?.width ?: 0) / 2 < screenWidth / 2) {
            dpToPx(8f) // Snap Left
        } else {
            screenWidth - (overlayContainer?.width ?: 0) - dpToPx(8f) // Snap Right
        }

        val overlayH = overlayContainer?.height ?: dpToPx(120f)
        val maxY = max(0, screenHeight - overlayH - dpToPx(10f))
        params.y = params.y.coerceIn(0, maxY)

        snapAnimator?.cancel()
        snapAnimator = ValueAnimator.ofInt(currentX, targetX).apply {
            duration = 200
            addUpdateListener { anim ->
                if (overlayContainer != null && overlayContainer?.isAttachedToWindow == true) {
                    params.x = anim.animatedValue as Int
                    try {
                        windowManager?.updateViewLayout(overlayContainer, params)
                    } catch (_: Exception) {}
                }
            }
        }
        snapAnimator?.start()
    }

    // ----------------------------------------------------
    // Event LED Lamp Overlay & Native Vibration
    // ----------------------------------------------------
    private fun triggerEventLamp(type: String, shape: String, position: String, customColor: String?) {
        val color = when {
            customColor != null -> Color.parseColor(customColor)
            type == "5g" -> Color.parseColor("#00E5FF") // Emerald Cyan
            type == "handover" -> Color.parseColor("#FFB300") // Amber Gold
            type == "critical" -> Color.parseColor("#FF1744") // Red
            type == "battery_temp" -> Color.parseColor("#FF3D00") // Deep Orange-Red
            else -> Color.parseColor("#00E5FF")
        }

        showLampOverlay(color, shape, position, isBlinking = (type == "critical" || type == "battery_temp"))
    }

    private fun vibrateDevice(type: String) {
        try {
            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
                vibratorManager?.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            }

            if (vibrator == null || !vibrator.hasVibrator()) return

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                when (type) {
                    "5g" -> {
                        // 5G Sub6: Double crisp vibration (70ms on, 60ms off, 70ms on)
                        val timings = longArrayOf(0, 70, 60, 70)
                        val amplitudes = intArrayOf(0, 255, 0, 255)
                        val effect = VibrationEffect.createWaveform(timings, amplitudes, -1)
                        vibrator.vibrate(effect)
                    }
                    "handover" -> {
                        // Handover: Medium single vibration (80ms)
                        val effect = VibrationEffect.createOneShot(80, 180)
                        vibrator.vibrate(effect)
                    }
                    "critical" -> {
                        // Critical warning: Strong alert double pulse (150ms on, 100ms off, 150ms on)
                        val timings = longArrayOf(0, 150, 100, 150)
                        val amplitudes = intArrayOf(0, 255, 0, 255)
                        val effect = VibrationEffect.createWaveform(timings, amplitudes, -1)
                        vibrator.vibrate(effect)
                    }
                    "battery_temp" -> {
                        // Battery Overheat: 3 alert pulses (200ms on, 100ms off, 200ms on, 100ms off, 200ms on)
                        val timings = longArrayOf(0, 200, 100, 200, 100, 200)
                        val amplitudes = intArrayOf(0, 255, 0, 255, 0, 255)
                        val effect = VibrationEffect.createWaveform(timings, amplitudes, -1)
                        vibrator.vibrate(effect)
                    }
                    else -> {
                        val effect = VibrationEffect.createOneShot(60, VibrationEffect.DEFAULT_AMPLITUDE)
                        vibrator.vibrate(effect)
                    }
                }
            } else {
                @Suppress("DEPRECATION")
                when (type) {
                    "5g" -> vibrator.vibrate(longArrayOf(0, 70, 60, 70), -1)
                    "handover" -> vibrator.vibrate(80)
                    "critical" -> vibrator.vibrate(longArrayOf(0, 150, 100, 150), -1)
                    "battery_temp" -> vibrator.vibrate(longArrayOf(0, 200, 100, 200, 100, 200), -1)
                    else -> vibrator.vibrate(60)
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun showLampOverlay(color: Int, shape: String, position: String, isBlinking: Boolean) {
        lampHideHandler.removeCallbacksAndMessages(null)
        lampBlinkAnimator?.cancel()
        lampBlinkAnimator = null

        if (lampContainer == null) {
            val overlayType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            }

            val gravityFlag = when (position) {
                "topLeft" -> Gravity.TOP or Gravity.START
                "topRight" -> Gravity.TOP or Gravity.END
                else -> Gravity.TOP or Gravity.CENTER_HORIZONTAL
            }

            lampLayoutParams = WindowManager.LayoutParams(
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                overlayType,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = gravityFlag
                x = if (position == "topLeft" || position == "topRight") dpToPx(16f) else 0
                y = 0 // 画面最上端（ステータスバーを完全に無視して絶対物理最上部に密着配置）
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
                }
            }

            val container = FrameLayout(this)
            lampContainer = container

            try {
                windowManager?.addView(lampContainer, lampLayoutParams)
            } catch (e: Exception) {
                e.printStackTrace()
                return
            }
        }

        updateScreenDimensions()
        val container = lampContainer ?: return
        container.removeAllViews()

        // Lamp Shape: bar (画面幅1/4の3dpスリムバー) or dot (8dp インジケータサイズ真円)
        val lampView = View(this).apply {
            val w = if (shape == "dot") dpToPx(8f) else (screenWidth / 4)
            val h = if (shape == "dot") dpToPx(8f) else dpToPx(3f)
            layoutParams = FrameLayout.LayoutParams(w, h)
            val drawable = GradientDrawable().apply {
                setColor(color)
                cornerRadius = if (shape == "dot") dpToPx(4f).toFloat() else dpToPx(1.5f).toFloat()
            }
            background = drawable
            alpha = 0.0f
        }
        container.addView(lampView)

        // Fade in -> Hold -> Fade out (Total 3.0 seconds)
        if (isBlinking) {
            lampBlinkAnimator = ValueAnimator.ofFloat(0.2f, 1.0f).apply {
                duration = 300
                repeatMode = ValueAnimator.REVERSE
                repeatCount = 9
                addUpdateListener { anim ->
                    lampView.alpha = anim.animatedValue as Float
                }
                start()
            }
        } else {
            lampView.animate()
                .alpha(1.0f)
                .setDuration(300)
                .setListener(null)
                .start()
        }

        lampHideHandler.postDelayed({
            lampView.animate()
                .alpha(0.0f)
                .setDuration(400)
                .setListener(object : AnimatorListenerAdapter() {
                    override fun onAnimationEnd(animation: Animator) {
                        removeLampOverlay()
                    }
                })
                .start()
        }, 2600)
    }

    private fun removeLampOverlay() {
        lampHideHandler.removeCallbacksAndMessages(null)
        lampBlinkAnimator?.cancel()
        lampBlinkAnimator = null
        if (lampContainer != null) {
            try {
                if (lampContainer?.isAttachedToWindow == true) {
                    windowManager?.removeView(lampContainer)
                }
            } catch (_: Exception) {}
            lampContainer = null
            lampLayoutParams = null
        }
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        instance = null
        hideFloatingOverlay()
        removeLampOverlay()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    override fun onDestroy() {
        instance = null
        hideFloatingOverlay()
        removeLampOverlay()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        super.onDestroy()
    }
}
