package com.syameimarukoa.fs050w_signal_display.ui.graph

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.syameimarukoa.fs050w_signal_display.domain.model.ConnectionModeHelper
import com.syameimarukoa.fs050w_signal_display.domain.model.SignalData
import com.syameimarukoa.fs050w_signal_display.domain.util.ColorGauge
import com.syameimarukoa.fs050w_signal_display.ui.LocalRepository
import com.syameimarukoa.fs050w_signal_display.ui.components.Fs050wTopAppBar
import com.syameimarukoa.fs050w_signal_display.ui.components.SignalColors
import com.syameimarukoa.fs050w_signal_display.ui.components.argbColor
import java.time.Duration
import java.time.LocalDateTime
import java.util.Locale
import kotlin.math.max

private data class ChartConfig(
    val title: String,
    val unit: String,
    val minY: Double,
    val maxY: Double,
    val thresholds: List<ColorGauge.MetricThreshold>,
    val yLabels: List<Double>,
    val hasZeroLine: Boolean = false,
    val get4g: (SignalData) -> Double?,
    val get5g: (SignalData) -> Double?,
    val label4g: String = "4G",
    val label5g: String = "5G",
)

@Composable
fun GraphScreen(onEnterPip: () -> Unit, onOpenLogs: () -> Unit, onOpenHud: () -> Unit) {
    val repo = LocalRepository.current
    val history by repo.history.collectAsStateWithLifecycle()
    val settings by repo.settings.collectAsStateWithLifecycle()
    var spanMinutes by remember { mutableIntStateOf(settings.graphSpanMinutes) }
    val now = LocalDateTime.now()
    val cutoff = now.minusMinutes(spanMinutes.toLong())
    val visible = remember(history, spanMinutes) {
        val index = history.indexOfFirst { it.timestamp.isAfter(cutoff) }
        when {
            index > 0 -> listOf(history[index - 1]) + history.drop(index)
            index == 0 -> history
            else -> emptyList()
        }
    }

    val label4g = ConnectionModeHelper.getGenerationName(false, settings.generationNotation)
    val label5g = ConnectionModeHelper.getGenerationName(true, settings.generationNotation)

    val configs = listOf(
        ChartConfig("1. RSRP", "dBm", -130.0, -70.0,
            ColorGauge.rsrpThresholds, listOf(-80.0, -90.0, -100.0, -110.0, -120.0),
            get4g = { it.lteRsrp }, get5g = { it.nrRsrp }, label4g = label4g, label5g = label5g),
        ChartConfig("2. RSRQ", "dB", -24.0, -8.0,
            ColorGauge.rsrqThresholds, listOf(-10.0, -15.0, -18.0, -20.0, -22.0),
            get4g = { it.lteRsrq }, get5g = { it.nrRsrq }, label4g = label4g, label5g = label5g),
        ChartConfig("3. SNR / SINR", "dB", -10.0, 25.0,
            ColorGauge.sinrThresholds, listOf(20.0, 13.0, 0.0, -3.0, -6.0), hasZeroLine = true,
            get4g = { it.lteSinr }, get5g = { it.nrSnr }, label4g = label4g, label5g = label5g),
        ChartConfig("4. Router Ping", "ms", 0.0, 200.0,
            emptyList(), listOf(50.0, 100.0, 150.0, 200.0),
            get4g = { it.routerLatencyMs?.toDouble() }, get5g = { null },
            label4g = "ルーター", label5g = ""),
    )

    Column(modifier = Modifier.fillMaxSize()) {
        Fs050wTopAppBar(onEnterPip, onOpenLogs, onOpenHud, onOpenDetail = {})
        Column(
            modifier = Modifier
                .fillMaxSize()
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 12.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text("表示スパン:", style = MaterialTheme.typography.bodyMedium)
            listOf(1, 3, 5, 10).forEach { minutes ->
                FilterChip(
                    selected = spanMinutes == minutes,
                    onClick = { spanMinutes = minutes },
                    label = { Text("${minutes}分") },
                    colors = androidx.compose.material3.FilterChipDefaults.filterChipColors(
                        selectedContainerColor = SignalColors.cyan.copy(alpha = 0.25f),
                        selectedLabelColor = SignalColors.cyan,
                    ),
                )
            }
        }
            configs.forEach { config ->
                ChartCard(config, visible, cutoff, now, spanMinutes * 60.0)
            }
        }
    }
}

@Composable
private fun ChartCard(
    config: ChartConfig,
    data: List<SignalData>,
    startTime: LocalDateTime,
    endTime: LocalDateTime,
    spanSeconds: Double,
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerLow),
        shape = androidx.compose.foundation.shape.RoundedCornerShape(8.dp),
        border = androidx.compose.foundation.BorderStroke(0.6.dp, Color.White.copy(alpha = 0.12f)),
    ) {
        Column(modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp)) {
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(config.title, fontSize = 12.5.sp, fontWeight = androidx.compose.ui.text.font.FontWeight.Bold)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    LegendDot(SignalColors.blue, config.label4g)
                    if (config.label5g.isNotEmpty()) LegendDot(SignalColors.cyan, config.label5g)
                }
            }
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(102.dp)
                    .padding(top = 4.dp),
            ) {
                val textMeasurer = rememberTextMeasurer()
                val axisColor = Color(0xAAFFFFFF)
                val gridColor = Color(0x33FFFFFF)
                Canvas(modifier = Modifier.fillMaxSize()) {
                    val w = size.width
                    val h = size.height
                    val left = 54f
                    val bottom = 34f
                    val plotW = w - left - 8f
                    val plotH = h - bottom - 8f
                    val range = config.maxY - config.minY

                    fun yOf(v: Double) = (plotH - ((v - config.minY) / range * plotH)).toFloat() + 8f
                    fun xOf(t: LocalDateTime) =
                        (Duration.between(startTime, t).toMillis() / 1000.0 / spanSeconds * plotW).toFloat() + left

                    // 水平グリッド線と Y 軸ラベル
                    config.yLabels.forEach { value ->
                        val y = yOf(value)
                        val threshold = config.thresholds.firstOrNull { it.value == value }
                        if (threshold != null) {
                            drawLine(
                                threshold.color.argbColor().copy(alpha = 0.45f),
                                Offset(left, y), Offset(left + plotW, y), 1f,
                                pathEffect = PathEffect.dashPathEffect(floatArrayOf(4f, 4f)),
                            )
                        } else {
                            drawLine(gridColor, Offset(left, y), Offset(left + plotW, y), 1f)
                        }
                        val color = threshold?.color?.argbColor() ?: axisColor
                        drawText(
                            textMeasurer,
                            String.format(Locale.ROOT, "%.0f", value),
                            topLeft = Offset(2f, y - 16f),
                            style = TextStyle(color = color, fontSize = 12.sp),
                        )
                    }
                    if (config.hasZeroLine) {
                        val y = yOf(0.0)
                        drawLine(
                            Color.White.copy(alpha = 0.54f), Offset(left, y), Offset(left + plotW, y), 1.5f,
                            pathEffect = PathEffect.dashPathEffect(floatArrayOf(5f, 5f)),
                        )
                    }

                    // 垂直グリッド線と X 軸ラベル
                    for (i in 0..4) {
                        val x = left + plotW * i / 4f
                        drawLine(gridColor, Offset(x, 8f), Offset(x, plotH + 8f), 1f)
                        val secs = spanSeconds * (4 - i) / 4.0
                        val label = if (i == 4) "現在" else {
                            val m = (secs / 60).toInt()
                            val s = (secs % 60).toInt()
                            if (m > 0) "-${m}分${if (s > 0) "${s}秒" else ""}" else "-${s}秒"
                        }
                        drawText(
                            textMeasurer, label,
                            topLeft = Offset(x - if (i == 4) 40f else 30f, plotH + 12f),
                            style = TextStyle(color = axisColor, fontSize = 11.sp),
                        )
                    }

                    // データライン (ギャップで分割)
                    fun drawSeries(getter: (SignalData) -> Double?, color: Color) {
                        var path = Path()
                        var started = false
                        var lastTime: LocalDateTime? = null
                        data.forEach { sample ->
                            val value = getter(sample)
                            val gap = lastTime != null &&
                                Duration.between(lastTime, sample.timestamp).toMillis() / 1000.0 > max(
                                    settings_interval * 2.5, 8.0,
                                )
                            if (value == null || value.isNaN() || value <= -200 || sample.timestamp.isBefore(startTime) || gap) {
                                if (started) { drawPath(path, color, style = Stroke(2.5f)); path = Path(); started = false }
                                lastTime = sample.timestamp
                                return@forEach
                            }
                            val point = Offset(xOf(sample.timestamp), yOf(value))
                            if (!started) { path.moveTo(point.x, point.y); started = true }
                            else path.lineTo(point.x, point.y)
                            lastTime = sample.timestamp
                        }
                        if (started) drawPath(path, color, style = Stroke(2.5f))
                    }
                    drawSeries(config.get4g, SignalColors.blue)
                    drawSeries(config.get5g, SignalColors.cyan)

                    // ハンドオーバー線
                    data.forEach { sample ->
                        if (sample.handoverDescription != null && !sample.timestamp.isBefore(startTime)) {
                            val x = xOf(sample.timestamp)
                            drawLine(SignalColors.yellow.copy(alpha = 0.7f), Offset(x, 8f), Offset(x, plotH + 8f), 1.5f)
                        }
                    }
                }
            }
        }
    }
}

private val settings_interval = 1

@Composable
private fun LegendDot(color: Color, label: String) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        Canvas(modifier = Modifier.padding(2.dp).height(10.dp).fillMaxWidth(0.02f)) {
            drawCircle(color, radius = 6f, center = Offset(6f, 6f))
        }
        Text(label, fontSize = 12.sp)
    }
}
