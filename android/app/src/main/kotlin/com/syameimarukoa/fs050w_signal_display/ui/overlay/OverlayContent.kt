package com.syameimarukoa.fs050w_signal_display.ui.overlay

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.collectAsState
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.syameimarukoa.fs050w_signal_display.domain.model.ConnectionModeHelper
import com.syameimarukoa.fs050w_signal_display.domain.model.Fs050wConnectionMode
import com.syameimarukoa.fs050w_signal_display.domain.model.SignalData
import com.syameimarukoa.fs050w_signal_display.domain.util.ColorGauge
import com.syameimarukoa.fs050w_signal_display.domain.util.FrequencyCalculator
import com.syameimarukoa.fs050w_signal_display.ui.components.MetricRow
import com.syameimarukoa.fs050w_signal_display.ui.components.argbColor
import com.syameimarukoa.fs050w_signal_display.data.SignalRepository
import com.syameimarukoa.fs050w_signal_display.domain.model.AppSettings

private val OVERLAY_ON_SURFACE = Color(0xFFF5F5F5)
private val OVERLAY_PRIMARY = Color(0xFF00E5FF)

/** Compose content for the floating window. Material You colours come from the platform scheme. */
@Composable
fun OverlayRoot(
    repository: SignalRepository,
    initialSettings: AppSettings,
    expanded: Boolean,
    onToggleExpanded: () -> Unit,
) {
    val context = LocalContext.current
    val signal by repository.currentSignal.collectAsState()
    val connecting by repository.isConnecting.collectAsState()
    val liveSettings by repository.settings.collectAsState()
    val settings = liveSettings
    // オーバーレイは常に暗い背景に重なるため、dynamic カラーに頼らず
    // コントラストを保証する固定の明るい色を使う。
    MaterialTheme(colorScheme = dynamicDarkColorScheme(context)) {
        // 背景にのみ透過度を適用する。文字まで薄くすると可読性が落ちるため。
        val opacity = settings.overlayOpacity.toFloat().coerceIn(0.2f, 1f)
        val cardModifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onToggleExpanded)
            .background(
                color = Color(0xFF0A0A0A).copy(alpha = opacity.coerceAtLeast(0.85f)),
                shape = RoundedCornerShape(12.dp),
            )
            .padding(10.dp)
        if (!expanded) {
            PillContent(signal, connecting, settings, cardModifier)
        } else if (settings.overlayStyle == "compact") {
            CompactContent(signal, connecting, settings, cardModifier)
        } else {
            CardContent(signal, connecting, settings, cardModifier)
        }
    }
}

@Composable
private fun PillContent(
    signal: SignalData?,
    connecting: Boolean,
    settings: AppSettings,
    modifier: Modifier,
) {
    val mode = signal?.connectionMode ?: Fs050wConnectionMode.DISCONNECTED
    val badge = if (connecting) "..." else ConnectionModeHelper.getIconBadgeText(mode, settings.generationNotation)
    val rsrp = signal?.nrRsrp ?: signal?.lteRsrp
    val color = ColorGauge.colorFor(ColorGauge.rateRsrp(rsrp)).argbColor()
    Text(
        text = buildString {
            append("[ $badge ] ")
            append(if (rsrp != null) String.format(java.util.Locale.ROOT, "%.0f", rsrp) else "--")
            if (signal?.batteryPercent != null) {
                append("  🔋${signal!!.batteryPercent}%")
            } else if (signal?.isBatteryPresent == false) {
                append("  AC給電")
            }
        },
        color = if (rsrp != null) color else OVERLAY_ON_SURFACE,
        fontSize = 11.sp,
        fontFamily = FontFamily.Monospace,
        modifier = modifier,
    )
}

@Composable
private fun CompactContent(
    signal: SignalData?,
    connecting: Boolean,
    settings: AppSettings,
    modifier: Modifier,
) {
    val mode = signal?.connectionMode ?: Fs050wConnectionMode.DISCONNECTED
    val badge = if (connecting) "[ 接続中... ]" else
        "[ ${ConnectionModeHelper.getIconBadgeText(mode, settings.generationNotation)} ]"
    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(
            "$badge ${signal?.operatorName ?: "--"}",
            color = OVERLAY_PRIMARY,
            fontSize = 11.sp,
            fontFamily = FontFamily.Monospace,
        )
        signal?.let { s ->
            CompactMetric("5G", s.nrRsrp, s.nrSnr)
            CompactMetric("4G", s.lteRsrp, s.lteSinr)
        }
    }
}

@Composable
private fun CompactMetric(prefix: String, rsrp: Double?, snr: Double?) {
    val rp = ColorGauge.colorFor(ColorGauge.rateRsrp(rsrp)).argbColor()
    val sn = ColorGauge.colorFor(ColorGauge.rateSinr(snr)).argbColor()
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            "$prefix RP: ${fmt(rsrp)}",
            color = rp, fontSize = 10.sp, fontFamily = FontFamily.Monospace,
        )
        Text(
            "SNR: ${fmt(snr)}",
            color = sn, fontSize = 10.sp, fontFamily = FontFamily.Monospace,
        )
    }
}

@Composable
private fun CardContent(
    signal: SignalData?,
    connecting: Boolean,
    settings: AppSettings,
    modifier: Modifier,
) {
    val mode = signal?.connectionMode ?: Fs050wConnectionMode.DISCONNECTED
    val badge = if (connecting) "[ 接続中... ]" else
        "[ ${ConnectionModeHelper.getIconBadgeText(mode, settings.generationNotation)} ]"
    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(
            "$badge ${signal?.operatorName ?: "--"}",
            color = OVERLAY_PRIMARY,
            fontSize = 16.sp,
            fontWeight = androidx.compose.ui.text.font.FontWeight.Bold,
            fontFamily = FontFamily.Monospace,
        )
        signal?.let { s ->
            if (!s.is5gDisabledByConfig) {
                Text(
                    ConnectionModeHelper.get5gCardTitle(mode, settings.generationNotation) +
                        " (${FrequencyCalculator.getNrBandName(s.nrBand)}/${s.nrPci ?: "--"})",
                    color = Color(0xFF00E5FF),
                    fontSize = 10.sp,
                )
                OverlayMetrics(s.nrRsrp, s.nrRsrq, s.nrSnr, true)
            }
            Text(
                ConnectionModeHelper.get4gCardTitle(mode, settings.generationNotation) +
                    " (${FrequencyCalculator.getLteBandName(s.lteBand)}/${s.ltePci ?: "--"})",
                color = Color(0xFF64B5F6),
                fontSize = 10.sp,
            )
            OverlayMetrics(s.lteRsrp, s.lteRsrq, s.lteSinr, false)
        }
    }
}

@Composable
private fun OverlayMetrics(rsrp: Double?, rsrq: Double?, snr: Double?, isNr: Boolean) {
    MetricRow(
        "RSRP", rsrp, "dBm",
        ColorGauge.metricColor(rsrp, ColorGauge.rateRsrp(rsrp), ColorGauge.RSRP_MIN, ColorGauge.RSRP_MAX,
            smooth = false, curve = "easeOut"),
        ColorGauge.RSRP_MIN, ColorGauge.RSRP_MAX,
    )
    MetricRow(
        "RQ", rsrq, "dB",
        ColorGauge.metricColor(rsrq, ColorGauge.rateRsrq(rsrq), ColorGauge.RSRQ_MIN, ColorGauge.RSRQ_MAX),
        ColorGauge.RSRQ_MIN, ColorGauge.RSRQ_MAX,
    )
    MetricRow(
        if (isNr) "SNR" else "SINR", snr, "dB",
        ColorGauge.metricColor(snr, ColorGauge.rateSinr(snr), ColorGauge.SINR_MIN, ColorGauge.SINR_MAX),
        ColorGauge.SINR_MIN, ColorGauge.SINR_MAX, signed = true,
    )
}

private fun fmt(value: Double?): String =
    if (value != null && value.isFinite() && value > -200) String.format(java.util.Locale.ROOT, "%+.1f", value) else "--"
