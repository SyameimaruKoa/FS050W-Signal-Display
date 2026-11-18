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
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
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
    val showGraph = settings.pipGraphType != "none" && history.size >= 2 && (isPortrait || isSquare)
    // PiP では weight が効かないため、アスペクト比から実寸を推定して高さを明示する。
    val signalHeight = when {
        isSquare -> if (showGraph) 150.dp else 210.dp
        isPortrait -> if (showGraph) 240.dp else 350.dp
        ratio.contains("21:") -> 138.dp
        else -> 154.dp
    }
    val graphHeight = if (isPortrait) 110.dp else 50.dp

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .padding(horizontal = 3.dp, vertical = 2.dp),
    ) {
        PipHeader(signal, settings, connecting, isSquare)
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
                    NrSection(signal, settings, false, Modifier.fillMaxSize())
                    LteSection(signal, settings, false, Modifier.fillMaxSize())
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
private fun PipHeader(signal: SignalData?, settings: AppSettings, connecting: Boolean, isSquare: Boolean) {
    val mode = signal?.connectionMode ?: Fs050wConnectionMode.DISCONNECTED
    val badge = if (connecting) "[ 接続中... ]" else
        "[ ${ConnectionModeHelper.getIconBadgeText(mode, settings.generationNotation)} ]"
    val latency = signal?.routerLatencyMs
    val isDelayed = latency != null && latency > 150
    val latencyColor = ColorGauge.latencyColor(latency).argbColor()
    val ratio = if (latency != null) (latency / 200.0).coerceIn(0.0, 1.0).toFloat() else 0f
    val fs = if (isSquare) 11.sp else 9.5.sp

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(Color.White.copy(alpha = 0.06f))
            .padding(horizontal = 4.dp, vertical = if (isSquare) 2.5.dp else 1.5.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            Box(
                modifier = Modifier
                    .background(
                        if (connecting) Color(0xFFFFB300).copy(alpha = 0.25f)
                        else SignalColors.cyan.copy(alpha = 0.25f),
                        androidx.compose.foundation.shape.RoundedCornerShape(3.dp),
                    )
                    .padding(horizontal = 4.dp, vertical = 1.dp),
            ) {
                Text(
                    badge,
                    color = if (connecting) Color(0xFFFFB300) else SignalColors.cyan,
                    fontSize = fs, fontWeight = FontWeight.Bold,
                )
            }
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
            if (bat.isNotEmpty()) {
                val warn = settings.batteryTempWarningEnabled &&
                    (signal?.batteryTemperature ?: 0.0) >= settings.batteryTempWarningThreshold
                Text(bat, color = if (warn) Color(0xFFFF5252) else Color.White.copy(alpha = 0.7f),
                    fontSize = if (isSquare) 10.sp else 8.5.sp, fontWeight = FontWeight.Bold)
            }
        }
        Box(
            modifier = Modifier
                .clip(androidx.compose.foundation.shape.RoundedCornerShape(3.dp))
                .border(
                    0.6.dp,
                    if (latency != null) latencyColor.copy(alpha = 0.4f) else Color.Transparent,
                    androidx.compose.foundation.shape.RoundedCornerShape(3.dp),
                ),
        ) {
            Box(
                modifier = Modifier
                    .matchParentSize()
                    .background(latencyColor.copy(alpha = 0.35f)),
            ) {
                Box(
                    Modifier
                        .fillMaxWidth(ratio)
                        .fillMaxSize()
                        .background(latencyColor.copy(alpha = 0.35f)),
                )
            }
            Text(
                if (isDelayed) "${latency}ms" else signal?.operatorName ?: "--",
                color = if (isDelayed) latencyColor else Color.White.copy(alpha = 0.7f),
                fontSize = fs, fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(horizontal = 4.dp, vertical = 1.dp),
            )
        }
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
            .fillMaxSize()
            .background(Color.White.copy(alpha = 0.03f))
            .border(0.6.dp, SignalColors.excellent.copy(alpha = 0.3f), androidx.compose.foundation.shape.RoundedCornerShape(4.dp))
            .padding(horizontal = 3.dp, vertical = 2.dp),
    ) {
        Row(modifier = Modifier.fillMaxWidth().height(14.dp), horizontalArrangement = Arrangement.SpaceBetween) {
            Text(if (signal?.nrBand != null) "$title ($band)" else title, color = SignalColors.cyan, fontSize = fs * 1.12f, fontWeight = FontWeight.Bold)
            Text("PCI: $pci", color = Color.White.copy(alpha = 0.7f), fontSize = fs * 1.06f)
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
            .fillMaxSize()
            .background(Color.White.copy(alpha = 0.03f))
            .border(0.6.dp, SignalColors.blue.copy(alpha = 0.3f), androidx.compose.foundation.shape.RoundedCornerShape(4.dp))
            .padding(horizontal = 3.dp, vertical = 2.dp),
    ) {
        Row(modifier = Modifier.fillMaxWidth().height(14.dp), horizontalArrangement = Arrangement.SpaceBetween) {
            Text("$gen ($band)", color = SignalColors.blue, fontSize = fs * 1.12f, fontWeight = FontWeight.Bold)
            Text("PCI: $pci", color = Color.White.copy(alpha = 0.7f), fontSize = fs * 1.06f)
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
private fun RefBox(label: String, value: Double?, unit: String, accent: Color, modifier: Modifier) {
    val color = when (label) {
        "RQ" -> ColorGauge.colorFor(ColorGauge.rateRsrq(value)).argbColor()
        else -> ColorGauge.colorFor(ColorGauge.rateSinr(value)).argbColor()
    }
    val text = if (value != null && value.isFinite() && value > -200) String.format(Locale.ROOT, "%+.1f", value) else "--"
    Column(modifier.fillMaxSize(), verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally) {
        Text(label, color = accent, fontSize = 9.sp, fontFamily = FontFamily.Monospace)
        Text(text, color = color, fontSize = 11.sp, fontFamily = FontFamily.Monospace, fontWeight = FontWeight.Bold)
        Text(unit, color = Color.White.copy(alpha = 0.5f), fontSize = 8.sp)
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
