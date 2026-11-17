package com.syameimarukoa.fs050w_signal_display.ui.graph

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
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
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.syameimarukoa.fs050w_signal_display.domain.model.SignalData
import com.syameimarukoa.fs050w_signal_display.domain.util.ColorGauge
import com.syameimarukoa.fs050w_signal_display.ui.LocalRepository
import com.syameimarukoa.fs050w_signal_display.ui.components.argbColor
import java.time.Duration
import java.time.LocalDateTime

private data class ChartConfig(
    val title: String,
    val unit: String,
    val minY: Double,
    val maxY: Double,
    val thresholds: List<ColorGauge.MetricThreshold>,
    val hasZeroLine: Boolean = false,
    val get4g: (SignalData) -> Double?,
    val get5g: (SignalData) -> Double?,
)

@Composable
fun GraphScreen() {
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

    val configs = listOf(
        ChartConfig("1. RSRP", "dBm", -130.0, -70.0, ColorGauge.rsrpThresholds,
            get4g = { it.lteRsrp }, get5g = { it.nrRsrp }),
        ChartConfig("2. RSRQ", "dB", -24.0, -8.0, ColorGauge.rsrqThresholds,
            get4g = { it.lteRsrq }, get5g = { it.nrRsrq }),
        ChartConfig("3. SNR / SINR", "dB", -10.0, 25.0, ColorGauge.sinrThresholds, hasZeroLine = true,
            get4g = { it.lteSinr }, get5g = { it.nrSnr }),
        ChartConfig("4. Router Ping", "ms", 0.0, 200.0, emptyList(),
            get4g = { it.routerLatencyMs?.toDouble() }, get5g = { null }),
    )

    Column(modifier = Modifier.fillMaxSize()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 12.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            listOf(1, 3, 5, 10).forEach { minutes ->
                FilterChip(
                    selected = spanMinutes == minutes,
                    onClick = { spanMinutes = minutes },
                    label = { Text("${minutes}分") },
                )
            }
        }
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 12.dp, vertical = 4.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            configs.forEach { config ->
                ChartCard(
                    config = config,
                    data = visible,
                    startTime = cutoff,
                    endTime = now,
                    spanSeconds = spanMinutes * 60.0,
                )
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
    ) {
        Column(modifier = Modifier.padding(12.dp)) {
            Text("${config.title} (${config.unit})", style = MaterialTheme.typography.titleSmall)
            Text(
                "5G: シアン   4G: 青   ──: ハンドオーバー",
                style = MaterialTheme.typography.labelSmall.copy(fontFamily = FontFamily.Monospace),
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(170.dp)
                    .padding(top = 8.dp)
                    .background(MaterialTheme.colorScheme.surface, RoundedCornerShape(8.dp)),
            ) {
                if (data.isEmpty()) {
                    Text(
                        "データ蓄積中...",
                        modifier = Modifier.align(Alignment.Center),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                } else {
                    val gridColor = MaterialTheme.colorScheme.outlineVariant
                    val nrColor = Color(0xFF00E5FF)
                    val lteColor = Color(0xFF2196F3)
                    Canvas(modifier = Modifier.fillMaxSize()) {
                        drawChart(
                            config = config,
                            data = data,
                            startTime = startTime,
                            endTime = endTime,
                            spanSeconds = spanSeconds,
                            gridColor = gridColor,
                            nrColor = nrColor,
                            lteColor = lteColor,
                        )
                    }
                }
            }
        }
    }
}

private fun DrawScope.drawChart(
    config: ChartConfig,
    data: List<SignalData>,
    startTime: LocalDateTime,
    endTime: LocalDateTime,
    spanSeconds: Double,
    gridColor: Color,
    nrColor: Color,
    lteColor: Color,
) {
    val w = size.width
    val h = size.height
    val range = config.maxY - config.minY
    fun xOf(time: LocalDateTime): Float {
        val seconds = Duration.between(startTime, time).toMillis() / 1000.0
        return (seconds / spanSeconds * w).toFloat().coerceIn(0f, w)
    }
    fun yOf(value: Double): Float = ((config.maxY - value) / range * h).toFloat().coerceIn(0f, h)

    config.thresholds.forEach { threshold ->
        val y = yOf(threshold.value)
        drawLine(
            color = threshold.color.argbColor().copy(alpha = 0.35f),
            start = Offset(0f, y),
            end = Offset(w, y),
            strokeWidth = 1f,
        )
    }
    if (config.hasZeroLine) {
        val y = yOf(0.0)
        drawLine(
            color = Color.White.copy(alpha = 0.4f),
            start = Offset(0f, y),
            end = Offset(w, y),
            strokeWidth = 1.5f,
        )
    }

    fun drawSeries(getter: (SignalData) -> Double?, color: Color) {
        val path = Path()
        var started = false
        data.forEach { sample ->
            val value = getter(sample)
            if (value == null || value.isNaN() || value <= -200 || sample.timestamp.isBefore(startTime)) {
                started = false
                return@forEach
            }
            val point = Offset(xOf(sample.timestamp), yOf(value))
            if (!started) {
                path.moveTo(point.x, point.y)
                started = true
            } else {
                path.lineTo(point.x, point.y)
            }
        }
        drawPath(path, color = color, style = Stroke(width = 2.5f))
    }

    drawSeries(config.get4g, lteColor)
    drawSeries(config.get5g, nrColor)

    data.forEach { sample ->
        if (sample.handoverDescription != null && !sample.timestamp.isBefore(startTime)) {
            val x = xOf(sample.timestamp)
            drawLine(
                color = Color(0xFFFFD600).copy(alpha = 0.7f),
                start = Offset(x, 0f),
                end = Offset(x, h),
                strokeWidth = 1.5f,
            )
        }
    }
}
