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

    private fun parseConfigFromIntent(intent: Intent) {
        if (intent.hasExtra("overlayStyle")) {
            overlayStyle = intent.getStringExtra("overlayStyle") ?: overlayStyle
        }
        if (intent.hasExtra("overlayOpacity")) {
            overlayOpacity = intent.getFloatExtra("overlayOpacity", overlayOpacity)
        }
        if (intent.hasExtra("overlayScale")) {
            overlayScale = intent.getFloatExtra("overlayScale", overlayScale)
        }
        if (intent.hasExtra("pipAspectRatio")) {
            aspectRatioStr = intent.getStringExtra("pipAspectRatio") ?: aspectRatioStr
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
        if (overlayContainer != null) {
            try {
                windowManager?.removeView(overlayContainer)
            } catch (_: Exception) {}
            overlayContainer = null
            overlayLayoutParams = null
        }
    }

    private fun getAspectRatioValue(): Float {
        return when (aspectRatioStr) {
            "16:9" -> 16f / 9f
            "9:16" -> 9f / 16f
            "1:1" -> 1f
            "4:3" -> 4f / 3f
            "3:4" -> 3f / 4f
            "21:9" -> 21f / 9f
            "9:21" -> 9f / 21f
            else -> 16f / 9f
        }
    }

    private fun dpToPx(dp: Float): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            dp,
            resources.displayMetrics
        ).toInt()
    }

    private fun buildOverlayView() {
        val container = overlayContainer ?: return
        container.removeAllViews()

        if (!isExpanded) {
            // Folded Mini Pill (約 110dp x 36dp)
            val pillView = createMiniPillView()
            container.addView(pillView)
            setupTouchAndGesture(container, isHandle = false)
            return
        }

        val ratio = getAspectRatioValue()
        val baseWidthDp = if (ratio >= 1.0f) 280f * overlayScale else 200f * overlayScale
        val widthPx = dpToPx(baseWidthDp)

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
        val contentView = if (overlayStyle == "compact") {
            createCompactContentView()
        } else {
            createCardContentView(ratio)
        }
        mainCard.addView(contentView)

        // Resize Handle (◢) at Bottom-Right
        val resizeHandle = createResizeHandleView()
        val handleParams = FrameLayout.LayoutParams(dpToPx(24f), dpToPx(24f)).apply {
            gravity = Gravity.BOTTOM or Gravity.END
        }
        mainCard.addView(resizeHandle, handleParams)

        container.addView(mainCard)

        setupTouchAndGesture(mainCard, isHandle = false)
        setupResizeHandleTouch(resizeHandle, mainCard)
    }

    private fun updateFloatingViewContent() {
        if (overlayContainer != null) {
            buildOverlayView()
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

        val json = lastSignalJson
        val modeBadge = json?.optString("connectionModeBadge", "5G") ?: "5G"
        val isSub6 = modeBadge.contains("+")
        val badge = if (isSub6) "5G+" else if (modeBadge.contains("5G")) "5G" else if (modeBadge.contains("4G")) "4G" else modeBadge

        val nrRsrp = json?.optDouble("nrRsrp", Double.NaN)
        val lteRsrp = json?.optDouble("lteRsrp", Double.NaN)
        val mainRsrp = if (nrRsrp != null && !nrRsrp.isNaN() && nrRsrp > -150) nrRsrp else lteRsrp

        val nrSnr = json?.optDouble("nrSnr", Double.NaN)
        val lteSinr = json?.optDouble("lteSinr", Double.NaN)
        val mainSnr = if (nrSnr != null && !nrSnr.isNaN()) nrSnr else lteSinr

        val rpStr = if (mainRsrp != null && !mainRsrp.isNaN() && mainRsrp > -150) "${mainRsrp.toInt()}" else "--"
        val snrStr = if (mainSnr != null && !mainSnr.isNaN()) String.format("%.0f", mainSnr) else "--"

        val iconText = TextView(this).apply {
            text = "📶"
            textSize = 11f
        }
        val labelText = TextView(this).apply {
            text = " $badge RP:$rpStr SNR:$snrStr"
            textSize = 11f
            setTextColor(Color.WHITE)
            typeface = Typeface.DEFAULT_BOLD
        }

        pill.addView(iconText)
        pill.addView(labelText)
        return pill
    }

    private fun createCardContentView(ratio: Float): View {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dpToPx(8f), dpToPx(6f), dpToPx(8f), dpToPx(6f))
        }

        val json = lastSignalJson
        val opName = json?.optString("operatorName", "Rakuten") ?: "Rakuten"
        val modeBadge = json?.optString("connectionModeBadge", "5G+") ?: "5G+"
        val isConnecting = json?.optBoolean("isConnecting", false) ?: false

        // Header Row
        val header = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }

        val badgeView = TextView(this).apply {
            text = if (isConnecting) "[ 接続中... ]" else "[ $modeBadge ]"
            textSize = 10f
            setTextColor(if (isConnecting) Color.YELLOW else Color.parseColor("#00E5FF"))
            typeface = Typeface.DEFAULT_BOLD
            val bg = GradientDrawable().apply {
                setColor(Color.parseColor("#2200E5FF"))
                cornerRadius = dpToPx(4f).toFloat()
            }
            background = bg
            setPadding(dpToPx(4f), dpToPx(1f), dpToPx(4f), dpToPx(1f))
        }

        val opView = TextView(this).apply {
            text = "  $opName"
            textSize = 10f
            setTextColor(Color.LTGRAY)
            typeface = Typeface.DEFAULT_BOLD
        }

        header.addView(badgeView)
        header.addView(opView)
        root.addView(header)

        // Metrics Section based on Aspect Ratio
        val isHorizontal = ratio >= 1.0f

        val nrBand = json?.optString("nrBand", "n77") ?: "n77"
        val nrPci = json?.optString("nrPci", "384") ?: "384"
        val nrRsrp = json?.optDouble("nrRsrp", -85.0)
        val nrRsrq = json?.optDouble("nrRsrq", -11.0)
        val nrSnr = json?.optDouble("nrSnr", 15.0)

        val lteBand = json?.optString("lteBand", "B3") ?: "B3"
        val ltePci = json?.optString("ltePci", "63") ?: "63"
        val lteRsrp = json?.optDouble("lteRsrp", -78.0)
        val lteRsrq = json?.optDouble("lteRsrq", -9.0)
        val lteSinr = json?.optDouble("lteSinr", 18.0)

        val nrTitle = if (modeBadge.contains("+")) "5G+ ($nrBand/$nrPci)" else "5G ($nrBand/$nrPci)"
        val lteTitle = "4G ($lteBand/$ltePci)"

        if (isHorizontal) {
            // Horizontal: 2 Columns (Left: 5G, Right: 4G)
            val columnsLayout = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                )
            }

            val col5g = createMetricColumn(nrTitle, nrRsrp, nrRsrq, nrSnr, is5g = true)
            val col4g = createMetricColumn(lteTitle, lteRsrp, lteRsrq, lteSinr, is5g = false)

            col5g.layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1.0f)
            col4g.layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1.0f)

            columnsLayout.addView(col5g)
            columnsLayout.addView(col4g)
            root.addView(columnsLayout)
        } else {
            // Vertical: 2 Rows (Top: 5G, Bottom: 4G)
            val row5g = createMetricRow(nrTitle, nrRsrp, nrRsrq, nrSnr, is5g = true)
            val row4g = createMetricRow(lteTitle, lteRsrp, lteRsrq, lteSinr, is5g = false)

            root.addView(row5g)
            root.addView(row4g)
        }

        return root
    }

    private fun createCompactContentView(): View {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dpToPx(8f), dpToPx(4f), dpToPx(8f), dpToPx(4f))
        }

        val json = lastSignalJson
        val opName = json?.optString("operatorName", "Rakuten") ?: "Rakuten"
        val modeBadge = json?.optString("connectionModeBadge", "5G+") ?: "5G+"

        val nrBand = json?.optString("nrBand", "n77") ?: "n77"
        val nrRsrp = json?.optDouble("nrRsrp", -85.0)

        val lteBand = json?.optString("lteBand", "B3") ?: "B3"
        val lteRsrp = json?.optDouble("lteRsrp", -78.0)

        // Line 1: Status
        val l1 = TextView(this).apply {
            text = "[$modeBadge] $opName"
            textSize = 10f
            setTextColor(Color.parseColor("#00E5FF"))
            typeface = Typeface.DEFAULT_BOLD
        }
        root.addView(l1)

        val nrTitle = if (modeBadge.contains("+")) "5G+ $nrBand" else "5G $nrBand"

        // Line 2: 5G Metrics with bar
        val l2 = createCompactMetricCell(nrTitle, "RSRP", nrRsrp, -140.0, -50.0, Color.parseColor("#00E5FF"))
        root.addView(l2)

        // Line 3: 4G Metrics with bar
        val l3 = createCompactMetricCell("4G $lteBand", "RSRP", lteRsrp, -140.0, -50.0, Color.parseColor("#2196F3"))
        root.addView(l3)

        return root
    }

    private fun createMetricColumn(title: String, rsrp: Double?, rsrq: Double?, snr: Double?, is5g: Boolean): View {
        val col = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dpToPx(2f), dpToPx(2f), dpToPx(2f), dpToPx(2f))
        }

        val header = TextView(this).apply {
            text = title
            textSize = 9f
            setTextColor(if (is5g) Color.parseColor("#00E5FF") else Color.parseColor("#64B5F6"))
            typeface = Typeface.DEFAULT_BOLD
        }
        col.addView(header)

        val accentColor = if (is5g) Color.parseColor("#00ADB5") else Color.parseColor("#1976D2")
        col.addView(createProgressBarCell("RSRP", rsrp, "dBm", -140.0, -50.0, accentColor))
        col.addView(createProgressBarCell("RSRQ", rsrq, "dB", -25.0, -3.0, accentColor))
        col.addView(createProgressBarCell(if (is5g) "SNR" else "SINR", snr, "dB", -10.0, 30.0, accentColor))

        return col
    }

    private fun createMetricRow(title: String, rsrp: Double?, rsrq: Double?, snr: Double?, is5g: Boolean): View {
        val row = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dpToPx(2f), dpToPx(2f), dpToPx(2f), dpToPx(2f))
        }

        val header = TextView(this).apply {
            text = title
            textSize = 9f
            setTextColor(if (is5g) Color.parseColor("#00E5FF") else Color.parseColor("#64B5F6"))
            typeface = Typeface.DEFAULT_BOLD
        }
        row.addView(header)

        val metricsRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
        }

        val accentColor = if (is5g) Color.parseColor("#00ADB5") else Color.parseColor("#1976D2")
        val c1 = createProgressBarCell("RSRP", rsrp, "dBm", -140.0, -50.0, accentColor).apply {
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        }
        val c2 = createProgressBarCell("RSRQ", rsrq, "dB", -25.0, -3.0, accentColor).apply {
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        }
        val c3 = createProgressBarCell(if (is5g) "SNR" else "SINR", snr, "dB", -10.0, 30.0, accentColor).apply {
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        }

        metricsRow.addView(c1)
        metricsRow.addView(c2)
        metricsRow.addView(c3)
        row.addView(metricsRow)

        return row
    }

    private fun createProgressBarCell(
        label: String,
        value: Double?,
        unit: String,
        minVal: Double,
        maxVal: Double,
        barColor: Int
    ): View {
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

        val normalized = if (value != null && !value.isNaN()) {
            ((value - minVal) / (maxVal - minVal)).coerceIn(0.0, 1.0).toFloat()
        } else {
            0.0f
        }

        val barView = View(this).apply {
            layoutParams = FrameLayout.LayoutParams(0, FrameLayout.LayoutParams.MATCH_PARENT).apply {
                width = 0 // will update on measure
            }
            setBackgroundColor(barColor)
            alpha = 0.35f
        }
        cell.addView(barView)

        // Text Overlay
        val textValue = if (value != null && !value.isNaN()) {
            val formatted = String.format("%.1f", value)
            "$label: $formatted $unit"
        } else {
            "$label: -- $unit"
        }

        val labelView = TextView(this).apply {
            text = textValue
            textSize = 8.5f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER_VERTICAL or Gravity.START
            setPadding(dpToPx(4f), 0, 0, 0)
        }
        cell.addView(labelView)

        cell.post {
            val totalWidth = cell.width
            val barW = (totalWidth * normalized).toInt()
            val lp = barView.layoutParams
            lp.width = barW
            barView.layoutParams = lp
        }

        return cell
    }

    private fun createCompactMetricCell(
        prefix: String,
        label: String,
        value: Double?,
        minVal: Double,
        maxVal: Double,
        barColor: Int
    ): View {
        return createProgressBarCell("$prefix $label", value, "dBm", minVal, maxVal, barColor)
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
                    params.x = initialX + dx
                    params.y = initialY + dy
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
            val params = overlayLayoutParams ?: return@setOnTouchListener false

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
                        val ratio = getAspectRatioValue()
                        val newWidth = max(dpToPx(160f), min(screenWidth - dpToPx(20f), initialWidth + dx))
                        val newHeight = (newWidth / ratio).toInt()

                        val cardParams = cardView.layoutParams
                        cardParams.width = newWidth
                        cardParams.height = FrameLayout.LayoutParams.WRAP_CONTENT
                        cardView.layoutParams = cardParams

                        overlayScale = (newWidth.toFloat() / dpToPx(280f)).coerceIn(0.7f, 1.8f)
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    isResizing = false
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

        val animator = ValueAnimator.ofInt(currentX, targetX).apply {
            duration = 200
            addUpdateListener { anim ->
                params.x = anim.animatedValue as Int
                try {
                    windowManager?.updateViewLayout(overlayContainer, params)
                } catch (_: Exception) {}
            }
        }
        animator.start()
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
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = gravityFlag
                y = dpToPx(4f)
                if (position == "topLeft") x = dpToPx(16f)
                if (position == "topRight") x = dpToPx(16f)
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

        val container = lampContainer ?: return
        container.removeAllViews()

        // Lamp Shape: bar (50px x 4px) or dot (8px x 8px)
        val lampView = View(this).apply {
            val w = if (shape == "dot") dpToPx(8f) else dpToPx(50f)
            val h = if (shape == "dot") dpToPx(8f) else dpToPx(4f)
            layoutParams = FrameLayout.LayoutParams(w, h)
            val drawable = GradientDrawable().apply {
                setColor(color)
                cornerRadius = if (shape == "dot") dpToPx(4f).toFloat() else dpToPx(2f).toFloat()
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
        if (lampContainer != null) {
            try {
                windowManager?.removeView(lampContainer)
            } catch (_: Exception) {}
            lampContainer = null
            lampLayoutParams = null
        }
    }

    override fun onDestroy() {
        hideFloatingOverlay()
        removeLampOverlay()
        super.onDestroy()
    }
}
