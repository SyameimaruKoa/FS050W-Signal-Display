package com.syameimarukoa.fs050w_signal_display.ui.hud

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.syameimarukoa.fs050w_signal_display.R
import com.syameimarukoa.fs050w_signal_display.domain.model.ConnectionModeHelper
import com.syameimarukoa.fs050w_signal_display.domain.model.Fs050wConnectionMode
import com.syameimarukoa.fs050w_signal_display.domain.model.SignalData
import com.syameimarukoa.fs050w_signal_display.domain.util.ColorGauge
import com.syameimarukoa.fs050w_signal_display.domain.util.FrequencyCalculator
import com.syameimarukoa.fs050w_signal_display.ui.LocalRepository
import com.syameimarukoa.fs050w_signal_display.ui.components.SignalColors
import com.syameimarukoa.fs050w_signal_display.ui.components.argbColor
import java.util.Locale

/** Flutter 版 HudScreen と同じ: 漆黒背景 + 5G/4G の RSRP/RSRQ/SINR を3列で表示。 */
@Composable
fun HudScreen(onClose: () -> Unit) {
    val repo = LocalRepository.current
    val signal by repo.currentSignal.collectAsStateWithLifecycle()
    val settings by repo.settings.collectAsStateWithLifecycle()
    val jitterX = remember { Animatable(0f) }
    val jitterY = remember { Animatable(0f) }

    // 焼き付き防止のピクセルシフト（Flutter 版と同じ 1 分間隔）
    LaunchedEffect(Unit) {
        var offset = 0f
        while (true) {
            kotlinx.coroutines.delay(60_000)
            offset = if (offset == 0f) 2f else 0f
            jitterX.animateTo(offset, animationSpec = tween(800, easing = LinearEasing))
            jitterY.animateTo(if (offset == 0f) 0f else 1f, animationSpec = tween(800))
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .clickable(onClick = onClose)
            .padding(16.dp)
            .graphicsLayerCompat(jitterX.value, jitterY.value),
        verticalArrangement = Arrangement.spacedBy(24.dp),
    ) {
        // ヘッダー: × / [モード] / バッテリー / キャリア
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Icon(
                painterResource(R.drawable.ic_close),
                contentDescription = "閉じる",
                tint = Color.White,
                modifier = Modifier.size(28.dp).clickable(onClick = onClose),
            )
            val mode = signal?.connectionMode ?: Fs050wConnectionMode.DISCONNECTED
            val badge = ConnectionModeHelper.getIconBadgeText(mode, settings.generationNotation)
            val uiMode = ConnectionModeHelper.getUiModeText(
                mode, isSa = signal?.isSa ?: false, notation = settings.generationNotation,
            )
            Row(
                modifier = Modifier
                    .background(Color(0x2200E5FF), RoundedCornerShape(20.dp))
                    .padding(horizontal = 12.dp, vertical = 6.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Text("[$badge] $uiMode", color = SignalColors.cyan, fontSize = 20.sp, fontWeight = FontWeight.Bold)
                if (signal?.batteryPercent != null) {
                    Text("🔋${signal!!.batteryPercent}%${if (signal!!.isCharging) "⚡" else ""}", fontSize = 16.sp)
                }
            }
            Text(signal?.operatorName ?: "--", color = Color.White, fontSize = 16.sp, maxLines = 1, modifier = Modifier.weight(1f))
        }

        if (signal == null) {
            Text("データ待機中...", color = Color(0xFF777777), fontSize = 18.sp)
        } else {
            val s = signal!!
            if (!s.is5gDisabledByConfig) {
                HudPanel(
                    title = ConnectionModeHelper.get5gCardTitle(s.connectionMode, settings.generationNotation),
                    band = FrequencyCalculator.getNrBandName(s.nrBand),
                    pci = s.nrPci,
                    rsrp = s.nrRsrp,
                    rsrq = s.nrRsrq,
                    snr = s.nrSnr,
                    snrLabel = "SNR",
                )
            }
            if (s.connectionMode != Fs050wConnectionMode.NR5G && s.connectionMode != Fs050wConnectionMode.NR5G_SUB6 || !s.isSa) {
                HudPanel(
                    title = ConnectionModeHelper.get4gCardTitle(s.connectionMode, settings.generationNotation),
                    band = FrequencyCalculator.getLteBandName(s.lteBand),
                    pci = s.ltePci,
                    rsrp = s.lteRsrp,
                    rsrq = s.lteRsrq,
                    snr = s.lteSinr,
                    snrLabel = "SINR",
                )
            }
        }
    }
}

@Composable
private fun HudPanel(
    title: String,
    band: String,
    pci: Int?,
    rsrp: Double?,
    rsrq: Double?,
    snr: Double?,
    snrLabel: String,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .border(1.dp, Color(0xFF1F6B75), RoundedCornerShape(10.dp))
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Text("$title ($band)", color = SignalColors.cyan, fontSize = 18.sp, fontWeight = FontWeight.Bold)
            Text("PCI: ${pci ?: "--"}", color = Color(0xFFAAAAAA), fontSize = 15.sp)
        }
        Row(modifier = Modifier.fillMaxWidth()) {
            HudMetric("RSRP", rsrp, "dBm", ColorGauge.colorFor(ColorGauge.rateRsrp(rsrp)).argbColor(), Modifier.weight(1f))
            HudMetric("RSRQ", rsrq, "dB", ColorGauge.colorFor(ColorGauge.rateRsrq(rsrq)).argbColor(), Modifier.weight(1f))
            HudMetric(snrLabel, snr, "dB", ColorGauge.colorFor(ColorGauge.rateSinr(snr)).argbColor(), Modifier.weight(1f))
        }
    }
}

@Composable
private fun HudMetric(label: String, value: Double?, unit: String, color: Color, modifier: Modifier) {
    Column(modifier = modifier, horizontalAlignment = Alignment.CenterHorizontally) {
        Text(label, color = Color(0xFF888888), fontSize = 13.sp)
        val text = if (value != null && value.isFinite() && value > -200) {
            String.format(Locale.ROOT, "%.1f", value)
        } else "--"
        Text(text, color = color, fontFamily = FontFamily.Monospace, fontSize = 26.sp, fontWeight = FontWeight.Bold)
        Text(unit, color = Color(0xFF888888), fontSize = 12.sp)
    }
}

private fun Modifier.graphicsLayerCompat(x: Float, y: Float): Modifier =
    this.then(graphicsLayer { translationX = x; translationY = y })
