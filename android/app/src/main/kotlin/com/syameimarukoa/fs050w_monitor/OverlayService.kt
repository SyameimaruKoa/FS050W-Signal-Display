package com.syameimarukoa.fs050w_monitor

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.animation.ValueAnimator
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.*
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.DisplayMetrics
import android.util.TypedValue
import android.view.*
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
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
        const val ACTION_START_OVERLAY = "com.syameimarukoa.fs050w_monitor.START_OVERLAY"
        const val ACTION_STOP_OVERLAY = "com.syameimarukoa.fs050w_monitor.STOP_OVERLAY"
        const val ACTION_UPDATE_DATA = "com.syameimarukoa.fs050w_monitor.UPDATE_DATA"
        const val ACTION_TRIGGER_LAMP = "com.syameimarukoa.fs050w_monitor.TRIGGER_LAMP"

        const val EXTRA_JSON_DATA = "extra_json_data"
        const val EXTRA_LAMP_TYPE = "extra_lamp_type"
        const val EXTRA_LAMP_SHAPE = "extra_lamp_shape"
        const val EXTRA_LAMP_POSITION = "extra_lamp_position"
        const val EXTRA_LAMP_COLOR = "extra_lamp_color"

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
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        updateScreenDimensions()
    }

    private fun updateScreenDimensions() {
        val dm = resources.displayMetrics
        screenWidth = dm.widthPixels
        screenHeight = dm.heightPixels
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) return START_NOT_STICKY

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

    private class PillViewHolder(
        val pillLayout: LinearLayout,
        val badgeText: TextView
    )

    private class CardViewHolder(
        val mainCard: FrameLayout,
        val badgeView: TextView,
        val opView: TextView,
        val nrHeader: TextView,
        val nrRsrpCell: MetricCellHolder,
        val nrRsrqCell: MetricCellHolder,
        val nrSnrCell: MetricCellHolder,
        val lteHeader: TextView,
        val lteRsrpCell: MetricCellHolder,
        val lteRsrqCell: MetricCellHolder,
        val lteSinrCell: MetricCellHolder
    )

    private class CompactViewHolder(
        val mainCard: FrameLayout,
        val statusView: TextView,
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

        val container = FrameLayout(this)
        overlayContainer = container

        buildOverlayView()

        try {
            windowManager?.addView(overlayContainer, overlayLayoutParams)
        } catch (e: Exception) {
            e.printStackTrace()
        }
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
            resources.displayMetrics
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
        val opName = json?.optString("operatorName", "Rakuten") ?: "Rakuten"
        val modeBadge = json?.optString("connectionModeBadge", "5G+") ?: "5G+"
        val isConnecting = json?.optBoolean("isConnecting", false) ?: false
        val notation = json?.optString("generationNotation", "4g_5g") ?: "4g_5g"
        val smoothColor = json?.optBoolean("smoothGaugeColor", false) ?: false

        val isLteNr = notation == "lte_nr"
        val nrLabel = if (isLteNr) "NR" else "5G"
        val lteLabel = if (isLteNr) "LTE" else "4G"

        val isSub6 = modeBadge.contains("+")
        val badge = if (isSub6) "$nrLabel+" else if (modeBadge.contains("5G") || modeBadge.contains("NR")) nrLabel else if (modeBadge.contains("4G") || modeBadge.contains("LTE")) lteLabel else modeBadge

        val nrBand = json?.optString("nrBand", "--") ?: "--"
        val nrPci = json?.optString("nrPci", "--") ?: "--"
        val nrRsrp = json?.optDouble("nrRsrp", Double.NaN)
        val nrRsrq = json?.optDouble("nrRsrq", Double.NaN)
        val nrSnr = json?.optDouble("nrSnr", Double.NaN)

        val lteBand = json?.optString("lteBand", "--") ?: "--"
        val ltePci = json?.optString("ltePci", "--") ?: "--"
        val lteRsrp = json?.optDouble("lteRsrp", Double.NaN)
        val lteRsrq = json?.optDouble("lteRsrq", Double.NaN)
        val lteSinr = json?.optDouble("lteSinr", Double.NaN)

        if (!isExpanded) {
            val holder = pillHolder ?: return
            val mainRsrp = if (nrRsrp != null && !nrRsrp.isNaN() && nrRsrp > -150) nrRsrp else lteRsrp
            val mainSnr = if (nrSnr != null && !nrSnr.isNaN()) nrSnr else lteSinr

            val rpStr = if (mainRsrp != null && !mainRsrp.isNaN() && mainRsrp > -150) "${mainRsrp.toInt()}" else "--"
            val snrStr = if (mainSnr != null && !mainSnr.isNaN()) String.format("%.0f", mainSnr) else "--"

            holder.badgeText.text = " $badge RP:$rpStr SNR:$snrStr"
            holder.pillLayout.alpha = overlayOpacity
            return
        }

        if (overlayStyle == "card") {
            val holder = cardHolder ?: return
            holder.mainCard.alpha = overlayOpacity
            holder.badgeView.text = if (isConnecting) "[ 接続中... ]" else "[ $modeBadge ]"
            holder.badgeView.setTextColor(if (isConnecting) Color.YELLOW else Color.parseColor("#00E5FF"))
            holder.opView.text = "  $opName"

            val nrTitle = if (modeBadge.contains("+")) "$nrLabel+ ($nrBand/$nrPci)" else "$nrLabel ($nrBand/$nrPci)"
            val lteTitle = "$lteLabel ($lteBand/$ltePci)"

            holder.nrHeader.text = nrTitle
            holder.lteHeader.text = lteTitle

            holder.nrRsrpCell.update(nrRsrp, smoothColor = smoothColor, curveType = smoothGaugeCurve)
            holder.nrRsrqCell.update(nrRsrq, smoothColor = smoothColor, curveType = smoothGaugeCurve)
            holder.nrSnrCell.update(nrSnr, smoothColor = smoothColor, curveType = smoothGaugeCurve)

            holder.lteRsrpCell.update(lteRsrp, smoothColor = smoothColor, curveType = smoothGaugeCurve)
            holder.lteRsrqCell.update(lteRsrq, smoothColor = smoothColor, curveType = smoothGaugeCurve)
            holder.lteSinrCell.update(lteSinr, smoothColor = smoothColor, curveType = smoothGaugeCurve)
        } else {
            val holder = compactHolder ?: return
            holder.mainCard.alpha = overlayOpacity
            holder.statusView.text = "[$modeBadge] $opName"

            val nrTitle = if (modeBadge.contains("+")) "$nrLabel+ $nrBand" else "$nrLabel $nrBand"
            val lteTitle = "$lteLabel $lteBand"

            holder.nrCell.update(nrRsrp, customPrefix = nrTitle, smoothColor = smoothColor, curveType = smoothGaugeCurve)
            holder.lteCell.update(lteRsrp, customPrefix = lteTitle, smoothColor = smoothColor, curveType = smoothGaugeCurve)
        }
    }

    private fun createMiniPillView(): View {
        val pill = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dpToPx(10f), dpToPx(6f), dpToPx(10f), dpToPx(6f))
            val bg = GradientDrawable().apply {
                setColor(Color.parseColor("#1E1E1E"))
                cornerRadius = dpToPx(18f).toFloat()
                setStroke(dpToPx(1.2f), Color.parseColor("#00E5FF"))
            }
            background = bg
            alpha = overlayOpacity
        }

        val iconText = TextView(this).apply {
            text = "📶"
            textSize = 11f
        }
        val labelText = TextView(this).apply {
            text = " 5G RP:-- SNR:--"
            textSize = 11f
            setTextColor(Color.WHITE)
            typeface = Typeface.DEFAULT_BOLD
        }

        pill.addView(iconText)
        pill.addView(labelText)

        pillHolder = PillViewHolder(pill, labelText)
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
        }

        val badgeView = TextView(this).apply {
            text = "[ 5G+ ]"
            textSize = 10f
            setTextColor(Color.parseColor("#00E5FF"))
            typeface = Typeface.DEFAULT_BOLD
            val bg = GradientDrawable().apply {
                setColor(Color.parseColor("#2200E5FF"))
                cornerRadius = dpToPx(4f).toFloat()
            }
            background = bg
            setPadding(dpToPx(4f), dpToPx(1f), dpToPx(4f), dpToPx(1f))
        }

        val opView = TextView(this).apply {
            text = "  Rakuten"
            textSize = 10f
            setTextColor(Color.LTGRAY)
            typeface = Typeface.DEFAULT_BOLD
        }

        header.addView(badgeView)
        header.addView(opView)
        root.addView(header)

        // 5G Header & Metric Cells
        val nrHeader = TextView(this).apply {
            text = "5G (n77/--)"
            textSize = 9.5f
            setTextColor(Color.parseColor("#00E5FF"))
            typeface = Typeface.DEFAULT_BOLD
            setPadding(0, dpToPx(4f), 0, dpToPx(2f))
        }
        root.addView(nrHeader)

        val nrRsrpCell = createMetricCellHolder("RSRP", "dBm", -120.0, -70.0, Color.parseColor("#00ADB5"))
        val nrRsrqCell = createMetricCellHolder("RSRQ", "dB", -22.0, -8.0, Color.parseColor("#00ADB5"))
        val nrSnrCell = createMetricCellHolder("SNR", "dB", -6.0, 24.0, Color.parseColor("#00ADB5"))

        root.addView(nrRsrpCell.rootCell)
        root.addView(nrRsrqCell.rootCell)
        root.addView(nrSnrCell.rootCell)

        // 4G Header & Metric Cells
        val lteHeader = TextView(this).apply {
            text = "4G (B3/--)"
            textSize = 9.5f
            setTextColor(Color.parseColor("#64B5F6"))
            typeface = Typeface.DEFAULT_BOLD
            setPadding(0, dpToPx(4f), 0, dpToPx(2f))
        }
        root.addView(lteHeader)

        val lteRsrpCell = createMetricCellHolder("RSRP", "dBm", -120.0, -70.0, Color.parseColor("#2196F3"))
        val lteRsrqCell = createMetricCellHolder("RSRQ", "dB", -22.0, -8.0, Color.parseColor("#2196F3"))
        val lteSinrCell = createMetricCellHolder("SINR", "dB", -6.0, 24.0, Color.parseColor("#2196F3"))

        root.addView(lteRsrpCell.rootCell)
        root.addView(lteRsrqCell.rootCell)
        root.addView(lteSinrCell.rootCell)

        cardHolder = CardViewHolder(
            mainCard = mainCard,
            badgeView = badgeView,
            opView = opView,
            nrHeader = nrHeader,
            nrRsrpCell = nrRsrpCell,
            nrRsrqCell = nrRsrqCell,
            nrSnrCell = nrSnrCell,
            lteHeader = lteHeader,
            lteRsrpCell = lteRsrpCell,
            lteRsrqCell = lteRsrqCell,
            lteSinrCell = lteSinrCell
        )

        return root
    }

    private fun createCompactContentView(mainCard: FrameLayout): View {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dpToPx(6f), dpToPx(4f), dpToPx(6f), dpToPx(4f))
        }

        val statusView = TextView(this).apply {
            text = "[5G+] Rakuten"
            textSize = 9.5f
            setTextColor(Color.parseColor("#00E5FF"))
            typeface = Typeface.DEFAULT_BOLD
            setPadding(0, 0, 0, dpToPx(2f))
        }
        root.addView(statusView)

        val nrCell = createMetricCellHolder("RSRP", "dBm", -120.0, -70.0, Color.parseColor("#00E5FF"))
        val lteCell = createMetricCellHolder("RSRP", "dBm", -120.0, -70.0, Color.parseColor("#2196F3"))

        root.addView(nrCell.rootCell)
        root.addView(lteCell.rootCell)

        compactHolder = CompactViewHolder(
            mainCard = mainCard,
            statusView = statusView,
            nrCell = nrCell,
            lteCell = lteCell
        )

        return root
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
            setPadding(dpToPx(4f), 0, 0, 0)
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
                        val newWidth = max(dpToPx(160f), min(screenWidth - dpToPx(20f), initialWidth + dx))

                        val cardParams = cardView.layoutParams
                        cardParams.width = newWidth
                        cardParams.height = FrameLayout.LayoutParams.WRAP_CONTENT
                        cardView.layoutParams = cardParams

                        userCustomWidthPx = newWidth
                        overlayScale = (newWidth.toFloat() / dpToPx(280f)).coerceIn(0.7f, 2.0f)

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
    // Event LED Lamp Overlay (Top of Screen)
    // ----------------------------------------------------
    private fun triggerEventLamp(type: String, shape: String, position: String, customColor: String?) {
        val color = when {
            customColor != null -> Color.parseColor(customColor)
            type == "5g" -> Color.parseColor("#00E5FF") // Emerald Cyan
            type == "handover" -> Color.parseColor("#FFB300") // Amber Gold
            type == "critical" -> Color.parseColor("#FF1744") // Red
            else -> Color.parseColor("#00E5FF")
        }

        showLampOverlay(color, shape, position, isBlinking = (type == "critical"))
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

        // Lamp Shape: bar (画面幅半分の3dpスリムバー) or dot (8dp インジケータサイズ真円)
        val lampView = View(this).apply {
            val w = if (shape == "dot") dpToPx(8f) else (screenWidth / 2)
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
        hideFloatingOverlay()
        removeLampOverlay()
        stopSelf()
    }

    override fun onDestroy() {
        hideFloatingOverlay()
        removeLampOverlay()
        super.onDestroy()
    }
}
