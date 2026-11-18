package com.syameimarukoa.fs050w_signal_display.ui.pip

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.layout.SubcomposeLayout
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.syameimarukoa.fs050w_signal_display.domain.model.AppSettings
import com.syameimarukoa.fs050w_signal_display.domain.model.ConnectionModeHelper
import com.syameimarukoa.fs050w_signal_display.domain.model.Fs050wConnectionMode
import com.syameimarukoa.fs050w_signal_display.domain.model.SignalData
import com.syameimarukoa.fs050w_signal_display.domain.util.ColorGauge
import com.syameimarukoa.fs050w_signal_display.domain.util.FrequencyCalculator
import com.syameimarukoa.fs050w_signal_display.ui.LocalRepository
import com.syameimarukoa.fs050w_signal_display.ui.components.SignalColors
import com.syameimarukoa.fs050w_signal_display.ui.components.argbColor
import java.time.Duration
import java.util.Locale

/** Flutter の FittedBox(fit: scaleDown) 相当: 自然サイズで配置し、領域に収まるよう自動縮小する。 */
@Composable
private fun FittedPipText(
    text: String,
    color: Color,
    fontSize: androidx.compose.ui.unit.TextUnit,
    fontWeight: FontWeight? = null,
    fontFamily: FontFamily? = null,
    modifier: Modifier = Modifier,
) {
    SubcomposeLayout(modifier) { constraints ->
        val placeable = subcompose("text") {
            Text(
                text = text,
                color = color,
                fontWeight = fontWeight,
                fontFamily = fontFamily,
                maxLines = 1,
                softWrap = false,
                style = MaterialTheme.typography.bodySmall.copy(fontSize = fontSize),
            )
        }.first().measure(androidx.compose.ui.unit.Constraints())

        val scale = if (placeable.width > constraints.maxWidth && constraints.maxWidth > 0) {
            constraints.maxWidth.toFloat() / placeable.width.toFloat()
        } else 1f
        // 内容の自然幅 (scale 後) だけを占める。こうすると Row の SpaceBetween が正しく動く。
        val w = (placeable.width * scale).toInt().coerceAtMost(constraints.maxWidth)
        val h = (placeable.height * scale).toInt().coerceAtMost(constraints.maxHeight)
        layout(w, h) {
            placeable.placeRelativeWithLayer(0, 0) {
                scaleX = scale
                scaleY = scale
                transformOrigin = TransformOrigin(0f, 0f)
            }
        }
    }
}

/** ヘッダー用: 色分けしたテキストを 1 行にまとめ、FittedBox 相当で縮小して全部表示する。 */
@Composable
private fun FittedPipAnnotatedText(
    text: androidx.compose.ui.text.AnnotatedString,
    fontSize: androidx.compose.ui.unit.TextUnit,
    modifier: Modifier = Modifier,
) {
    SubcomposeLayout(modifier) { constraints ->
        val placeable = subcompose("text") {
            Text(
                text = text,
                maxLines = 1,
                softWrap = false,
                style = MaterialTheme.typography.bodySmall.copy(fontSize = fontSize),
            )
        }.first().measure(androidx.compose.ui.unit.Constraints())
        val scale = if (placeable.width > constraints.maxWidth && constraints.maxWidth > 0) {
            constraints.maxWidth.toFloat() / placeable.width.toFloat()
        } else 1f
        val w = (placeable.width * scale).toInt().coerceAtMost(constraints.maxWidth)
        val h = (placeable.height * scale).toInt().coerceAtMost(constraints.maxHeight)
        layout(w, h) {
            placeable.placeRelativeWithLayer(0, 0) {
                scaleX = scale
                scaleY = scale
                transformOrigin = TransformOrigin(0f, 0f)
            }
        }
    }
}

/** Flutter 版 PipScreen と同じ構成: ヘッダー + 5G/4G 信号グリッド + タップで切替できるミニ履歴グラフ。 */
@Composable
fun PipScreen() {
    val repo = LocalRepository.current
    val signal by repo.currentSignal.collectAsStateWithLifecycle()
    val settings by repo.settings.collectAsStateWithLifecycle()
    val history by repo.history.collectAsStateWithLifecycle()
    val connecting by repo.isConnecting.collectAsStateWithLifecycle()

    val ratio = settings.pipAspectRatio
    val isPortrait = ratio.contains("9:16") || ratio.contains("3:4") || ratio.contains("9:21")
    val isSquare = ratio == "1:1"
    // PiP の実寸は onSizeChanged で State に保存し、再コンポーズで反映する。
    var pipSize by remember { mutableStateOf(androidx.compose.ui.unit.IntSize.Zero) }
    val density = androidx.compose.ui.platform.LocalDensity.current
    val pipWidth = with(density) { pipSize.width.toDp() }
    val pipHeight = with(density) { pipSize.height.toDp() }

    val threshold = settings.pipGraphScaleThreshold.toFloat()
    val showGraph = settings.pipGraphType != "none" && history.size >= 2 &&
        if (isSquare) pipWidth.value >= 220f * threshold && pipHeight.value >= 220f * threshold
        else if (isPortrait) pipHeight.value >= 260f * threshold && pipWidth.value >= 140f * threshold
        else pipHeight.value >= 170f * threshold && pipWidth.value >= 280f * threshold

    // 実寸から、ヘッダー(約20dp)と余白を引いた高さを子に割り当てる。
    val available = (pipHeight - 24.dp).coerceAtLeast(40.dp)
    val signalHeight = if (showGraph) available * (if (isPortrait) 0.6f else 0.66f) else available
    val graphHeight = if (showGraph) available - signalHeight else 0.dp

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .padding(horizontal = 3.dp, vertical = 2.dp)
            .onSizeChanged {
                pipSize = it
            },
    ) {
        PipHeader(signal, settings, connecting, isSquare, isPortrait)
        androidx.compose.foundation.layout.Spacer(Modifier.height(2.dp))
        Column(modifier = Modifier.height(signalHeight)) {
            if (isSquare) {
                val nrActive = signal?.nrRsrp != null && signal!!.nrRsrp!! < 0
                if (nrActive) NrSection(signal, settings, true, Modifier.fillMaxSize())
                else LteSection(signal, settings, true, Modifier.fillMaxSize())
            } else if (isPortrait) {
                Column(modifier = Modifier.fillMaxSize(), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    NrSection(signal, settings, false, Modifier.height(signalHeight / 2 - 1.dp))
                    LteSection(signal, settings, false, Modifier.height(signalHeight / 2 - 1.dp))
                }
            } else {
                Row(modifier = Modifier.fillMaxSize(), horizontalArrangement = Arrangement.spacedBy(3.dp)) {
                    NrSection(signal, settings, false, Modifier.weight(1f).fillMaxHeight())
                    LteSection(signal, settings, false, Modifier.weight(1f).fillMaxHeight())
                }
            }
        }
        if (showGraph) {
            androidx.compose.foundation.layout.Spacer(Modifier.height(2.dp))
            MiniGraph(
                history = history,
                type = settings.pipGraphType,
                modifier = Modifier.height(graphHeight),
                onCycle = {
                    val next = when (settings.pipGraphType) {
                        "rsrp" -> "snr"
                        "snr" -> "rsrq"
                        else -> "rsrp"
                    }
                    repo.updateSettings(settings.copy(pipGraphType = next))
                },
            )
        }
    }
}

@Composable
private fun PipHeader(signal: SignalData?, settings: AppSettings, connecting: Boolean, isSquare: Boolean, isPortrait: Boolean) {
    val mode = signal?.connectionMode ?: Fs050wConnectionMode.DISCONNECTED
    val badge = if (connecting) "[ 接続中... ]" else
        "[ ${ConnectionModeHelper.getIconBadgeText(mode, settings.generationNotation)} ]"
    val latency = signal?.routerLatencyMs
    val isDelayed = latency != null && latency > 150
    val latencyColor = ColorGauge.latencyColor(latency).argbColor()
    val ratio = if (latency != null) (latency / 200.0).coerceIn(0.0, 1.0).toFloat() else 0f
    val fs = if (isSquare) 11.sp else 9.5.sp

    val bat = when {
        signal?.isBatteryPresent == false -> "🔌AC給電"
        signal?.batteryPercent != null || signal?.batteryTemperature != null -> buildString {
            append("🔋")
            signal?.batteryPercent?.let { append("$it%") }
            if (signal?.isCharging == true) append("⚡")
            signal?.batteryTemperature?.let { append(" ${it.toInt()}℃") }
            signal?.remainingTimeHHMM?.let { append(" $it") }
        }
        else -> ""
    }
    val warn = settings.batteryTempWarningEnabled &&
        (signal?.batteryTemperature ?: 0.0) >= settings.batteryTempWarningThreshold
    val operator = if (isDelayed) "${latency}ms" else signal?.operatorName ?: "--"

    val headerText = buildAnnotatedString {
        withStyle(SpanStyle(color = if (connecting) Color(0xFFFFB300) else SignalColors.cyan, fontWeight = FontWeight.Bold)) {
            append(badge)
        }
        if (bat.isNotEmpty()) {
            withStyle(SpanStyle(color = if (warn) Color(0xFFFF5252) else Color.White.copy(alpha = 0.7f), fontWeight = FontWeight.Bold)) {
                append("  $bat")
            }
        }
        withStyle(SpanStyle(color = if (isDelayed) latencyColor else Color.White.copy(alpha = 0.7f), fontWeight = FontWeight.Bold)) {
            append("  $operator")
        }
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(if (isSquare) 26.dp else 18.dp)
            .background(Color.White.copy(alpha = 0.06f))
            .padding(horizontal = 4.dp, vertical = if (isSquare) 2.5.dp else 1.5.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        FittedPipAnnotatedText(headerText, fontSize = fs)
    }
}

@Composable
private fun NrSection(signal: SignalData?, settings: AppSettings, single: Boolean, modifier: Modifier) {
    val isSub6 = signal?.connectionMode == Fs050wConnectionMode.NR5G_SUB6
    val gen = ConnectionModeHelper.getGenerationName(true, settings.generationNotation)
    val title = if (isSub6) "$gen+" else gen
    val fs = if (single) 10.5.sp else 8.5.sp
    if (signal?.is5gDisabledByConfig == true) {
        Box(modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Text("[${gen}無効]", color = Color.White.copy(alpha = 0.38f), fontSize = fs, fontWeight = FontWeight.Bold)
        }
        return
    }
    val band = if (signal?.nrBand != null && signal!!.nrBand!! > 0) "n${signal!!.nrBand}" else "--"
    val pci = if (signal?.nrPci != null && signal!!.nrPci!! > 0) "${signal!!.nrPci}" else "--"
    Column(
        modifier = modifier
            .background(Color.White.copy(alpha = 0.03f))
            .border(0.6.dp, SignalColors.excellent.copy(alpha = 0.3f), androidx.compose.foundation.shape.RoundedCornerShape(4.dp))
            .padding(horizontal = 3.dp, vertical = 2.dp),
    ) {
        Row(modifier = Modifier.fillMaxWidth().height(14.dp), horizontalArrangement = Arrangement.SpaceBetween) {
            FittedPipText("$title ($band)", color = SignalColors.cyan, fontSize = fs * 1.12f, fontWeight = FontWeight.Bold)
            FittedPipText("PCI: $pci", color = Color.White.copy(alpha = 0.7f), fontSize = fs * 1.06f)
        }
        IntensityBar("RSRP", signal?.nrRsrp, ColorGauge.RSRP_MIN, ColorGauge.RSRP_MAX,
            ColorGauge.colorFor(ColorGauge.rateRsrp(signal?.nrRsrp)).argbColor(),
            settings.smoothGaugeColor, settings.smoothGaugeCurve, fs, Modifier.weight(3f))
        if (signal != null) {
            Row(modifier = Modifier.weight(2f).fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(3.dp)) {
                RefBox("RQ", signal!!.nrRsrq, "dB", SignalColors.excellent, Modifier.weight(1f))
                RefBox("SNR", signal!!.nrSnr, "dB", SignalColors.excellent, Modifier.weight(1f))
            }
        }
    }
}

@Composable
private fun LteSection(signal: SignalData?, settings: AppSettings, single: Boolean, modifier: Modifier) {
    val gen = ConnectionModeHelper.getGenerationName(false, settings.generationNotation)
    val fs = if (single) 10.5.sp else 8.5.sp
    val band = if (signal?.lteBand != null && signal!!.lteBand!! > 0) "B${signal!!.lteBand}" else "--"
    val pci = if (signal?.ltePci != null && signal!!.ltePci!! > 0) "${signal!!.ltePci}" else "--"
    Column(
        modifier = modifier
            .background(Color.White.copy(alpha = 0.03f))
            .border(0.6.dp, SignalColors.blue.copy(alpha = 0.3f), androidx.compose.foundation.shape.RoundedCornerShape(4.dp))
            .padding(horizontal = 3.dp, vertical = 2.dp),
    ) {
        Row(modifier = Modifier.fillMaxWidth().height(14.dp), horizontalArrangement = Arrangement.SpaceBetween) {
            FittedPipText("$gen ($band)", color = SignalColors.blue, fontSize = fs * 1.12f, fontWeight = FontWeight.Bold)
            FittedPipText("PCI: $pci", color = Color.White.copy(alpha = 0.7f), fontSize = fs * 1.06f)
        }
        IntensityBar("RSRP", signal?.lteRsrp, ColorGauge.RSRP_MIN, ColorGauge.RSRP_MAX,
            ColorGauge.colorFor(ColorGauge.rateRsrp(signal?.lteRsrp)).argbColor(),
            settings.smoothGaugeColor, settings.smoothGaugeCurve, fs, Modifier.weight(3f))
        if (signal != null) {
            Row(modifier = Modifier.weight(2f).fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(3.dp)) {
                RefBox("RQ", signal!!.lteRsrq, "dB", SignalColors.blue, Modifier.weight(1f))
                RefBox("SINR", signal!!.lteSinr, "dB", SignalColors.blue, Modifier.weight(1f))
            }
        }
    }
}

@Composable
private fun IntensityBar(
    label: String, value: Double?, min: Double, max: Double, barColor: Color,
    smooth: Boolean, curve: String, fontSize: androidx.compose.ui.unit.TextUnit, modifier: Modifier,
) {
    val raw = if (value != null && value.isFinite() && value > -200) ((value - min) / (max - min)).coerceIn(0.0, 1.0) else 0.0
    val ratio = ColorGauge.applyCurve(raw, curve).toFloat()
    val color = if (smooth && value != null) ColorGauge.getSmoothColor(raw, curve).argbColor() else barColor
    val text = if (value != null && value.isFinite() && value > -200) String.format(Locale.ROOT, "%.1f dBm", value) else "-- dBm"
    Box(
        modifier = modifier
            .fillMaxWidth()
            .background(Color.White.copy(alpha = 0.06f))
            .border(0.5.dp, Color.White.copy(alpha = 0.08f), androidx.compose.foundation.shape.RoundedCornerShape(4.dp)),
    ) {
        Box(
            Modifier
                .fillMaxWidth(ratio)
                .fillMaxSize()
                .background(color.copy(alpha = 0.35f)),
        )
        Row(
            modifier = Modifier.fillMaxSize().padding(horizontal = 5.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(label, color = Color.White.copy(alpha = 0.7f), fontSize = fontSize, fontWeight = FontWeight.W600)
            Text(text, color = Color.White, fontSize = fontSize, fontWeight = FontWeight.Bold)
        }
    }
}

@Composable
@Suppress("UNUSED_PARAMETER")
private fun RefBox(label: String, value: Double?, unit: String, accent: Color, modifier: Modifier) {
    val color = when (label) {
        "RQ" -> ColorGauge.colorFor(ColorGauge.rateRsrq(value)).argbColor()
        else -> ColorGauge.colorFor(ColorGauge.rateSinr(value)).argbColor()
    }
    val hasVal = value != null && value.isFinite() && value > -200
    val text = if (hasVal) String.format(Locale.ROOT, "%+.1f", value) else "--"
    val minVal = if (label == "RQ") ColorGauge.RSRQ_MIN else ColorGauge.SINR_MIN
    val maxVal = if (label == "RQ") ColorGauge.RSRQ_MAX else ColorGauge.SINR_MAX
    val ratio = if (hasVal) ((value - minVal) / (maxVal - minVal)).coerceIn(0.0, 1.0).toFloat() else 0f
    Box(
        modifier = modifier
            .background(Color.White.copy(alpha = 0.035f), androidx.compose.foundation.shape.RoundedCornerShape(3.dp))
            .border(0.5.dp, if (hasVal) color.copy(alpha = 0.35f) else Color.White.copy(alpha = 0.08f), androidx.compose.foundation.shape.RoundedCornerShape(3.dp)),
        contentAlignment = Alignment.Center,
    ) {
        if (hasVal && ratio > 0f) {
            Box(Modifier.fillMaxWidth(ratio).fillMaxHeight().background(color.copy(alpha = 0.24f)))
        }
        FittedPipText("$label $text", color = color, fontSize = 8.sp, fontFamily = FontFamily.Monospace, fontWeight = FontWeight.Bold)
    }
}

@Composable
private fun MiniGraph(history: List<SignalData>, type: String, modifier: Modifier = Modifier, onCycle: () -> Unit) {
    val label = when (type) {
        "rsrp" -> "RSRP 履歴"
        "snr" -> "SNR / SINR 履歴"
        else -> "RSRQ 履歴"
    }
    Box(
        modifier = modifier
            .fillMaxWidth()
            .background(Color.White.copy(alpha = 0.04f))
            .border(0.5.dp, Color.White.copy(alpha = 0.08f), androidx.compose.foundation.shape.RoundedCornerShape(3.dp))
            .clickable(onClick = onCycle),
    ) {
        if (history.size >= 2) {
            Canvas(modifier = Modifier.fillMaxSize()) {
                val points = history.takeLast(30)
                var minV = when (type) { "rsrp" -> -140.0; "snr" -> -10.0; else -> -25.0 }
                var maxV = when (type) { "rsrp" -> -50.0; "snr" -> 30.0; else -> -3.0 }
                points.forEach { s ->
                    val v5 = when (type) { "rsrp" -> s.nrRsrp; "snr" -> s.nrSnr; else -> s.nrRsrq }
                    val v4 = when (type) { "rsrp" -> s.lteRsrp; "snr" -> s.lteSinr; else -> s.lteRsrq }
                    listOfNotNull(v5, v4).forEach { v ->
                        if (v.isFinite() && v > -200) {
                            if (v < minV) minV = v - 2.0
                            if (v > maxV) maxV = v + 2.0
                        }
                    }
                }
                drawLine(Color.White.copy(alpha = 0.06f), Offset(0f, size.height / 2), Offset(size.width, size.height / 2), 0.5f)
                val step = size.width / (points.size - 1)
                fun drawSeries(getter: (SignalData) -> Double?, color: Color, width: Float) {
                    val path = Path()
                    var started = false
                    points.forEachIndexed { i, s ->
                        val v = getter(s)
                        val gap = i > 0 && Duration.between(points[i - 1].timestamp, s.timestamp).toMillis() > 4000
                        if (gap || v == null || !v.isFinite() || v <= -200) {
                            started = false
                            return@forEachIndexed
                        }
                        val y = size.height * (1 - ((v - minV) / (maxV - minV)).coerceIn(0.0, 1.0)).toFloat()
                        if (!started) { path.moveTo(i * step, y); started = true } else path.lineTo(i * step, y)
                    }
                    drawPath(path, color, style = Stroke(width))
                }
                drawSeries({ it.lteRsrp.takeIf { type == "rsrp" } ?: if (type == "snr") it.lteSinr else it.lteRsrq }, SignalColors.blue, 1.2f)
                drawSeries({ it.nrRsrp.takeIf { type == "rsrp" } ?: if (type == "snr") it.nrSnr else it.nrRsrq }, SignalColors.cyan, 1.5f)
            }
        }
        Text(
            "$label (タップで切替)",
            color = Color.White.copy(alpha = 0.7f), fontSize = 7.sp,
            modifier = Modifier
                .align(Alignment.TopStart)
                .padding(2.dp)
                .background(Color.Black.copy(alpha = 0.6f))
                .padding(horizontal = 3.dp, vertical = 1.dp),
        )
    }
}
