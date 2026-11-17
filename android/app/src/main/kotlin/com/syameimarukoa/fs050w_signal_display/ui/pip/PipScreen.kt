package com.syameimarukoa.fs050w_signal_display.ui.pip

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.syameimarukoa.fs050w_signal_display.domain.model.ConnectionModeHelper
import com.syameimarukoa.fs050w_signal_display.domain.model.SignalData
import com.syameimarukoa.fs050w_signal_display.domain.util.ColorGauge
import com.syameimarukoa.fs050w_signal_display.domain.util.FrequencyCalculator
import com.syameimarukoa.fs050w_signal_display.ui.LocalRepository
import com.syameimarukoa.fs050w_signal_display.ui.components.argbColor

@Composable
fun PipScreen() {
    val repo = LocalRepository.current
    val signal by repo.currentSignal.collectAsStateWithLifecycle()
    val settings by repo.settings.collectAsStateWithLifecycle()

    BoxWithConstraints(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .padding(8.dp),
    ) {
        val wide = maxWidth > maxHeight
        val content: @Composable () -> Unit = {
            if (signal == null) {
                Text("データ待機中...", color = Color(0xFF888888), fontSize = 12.sp)
            } else {
                val s = signal!!
                val notation = settings.generationNotation
                val badge = ConnectionModeHelper.getIconBadgeText(
                    s.connectionMode, notation,
                )
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(
                        "[$badge] ${s.operatorName}" +
                            if (s.isBatteryPresent) "  🔋${s.batteryPercent ?: "--"}%" else "  AC給電",
                        color = Color(0xFF00E5FF),
                        fontSize = 11.sp,
                        fontFamily = FontFamily.Monospace,
                    )
                    val nr = @Composable { PiPCell("5G", FrequencyCalculator.getNrBandName(s.nrBand), s.nrRsrp, s.nrRsrq, s.nrSnr) }
                    val lte = @Composable { PiPCell("4G", FrequencyCalculator.getLteBandName(s.lteBand), s.lteRsrp, s.lteRsrq, s.lteSinr) }
                    if (wide) {
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) { nr(); lte() }
                    } else {
                        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) { nr(); lte() }
                    }
                }
            }
        }
        if (wide) {
            Row(modifier = Modifier.fillMaxSize()) { content() }
        } else {
            Column(modifier = Modifier.fillMaxSize()) { content() }
        }
    }
}

@Composable
private fun PiPCell(prefix: String, band: String, rsrp: Double?, rsrq: Double?, snr: Double?) {
    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
        Text("$prefix $band", color = Color(0xFF00E5FF), fontSize = 10.sp, fontFamily = FontFamily.Monospace)
        PiPLine("RP", rsrp, ColorGauge.rateRsrp(rsrp))
        PiPLine("RQ", rsrq, ColorGauge.rateRsrq(rsrq))
        PiPLine("SN", snr, ColorGauge.rateSinr(snr))
    }
}

@Composable
private fun PiPLine(label: String, value: Double?, level: com.syameimarukoa.fs050w_signal_display.domain.model.SignalRatingLevel) {
    val text = if (value != null && value.isFinite() && value > -200) {
        String.format(java.util.Locale.ROOT, "%+.1f", value)
    } else "--"
    Text(
        "$label: $text",
        color = ColorGauge.colorFor(level).argbColor(),
        fontSize = 10.sp,
        fontFamily = FontFamily.Monospace,
    )
}
