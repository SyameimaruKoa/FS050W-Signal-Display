package com.syameimarukoa.fs050w_signal_display.ui.hud

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.syameimarukoa.fs050w_signal_display.domain.util.ColorGauge
import com.syameimarukoa.fs050w_signal_display.ui.LocalRepository
import com.syameimarukoa.fs050w_signal_display.ui.components.argbColor
import kotlinx.coroutines.delay

@Composable
fun HudScreen(onClose: () -> Unit) {
    val repo = LocalRepository.current
    val signal by repo.currentSignal.collectAsStateWithLifecycle()
    val jitterX = remember { Animatable(0f) }
    val jitterY = remember { Animatable(0f) }

    // Anti-burn-in: shift the whole overlay by a few pixels once a minute.
    LaunchedEffect(Unit) {
        var offset = 0f
        while (true) {
            delay(60_000)
            offset = if (offset == 0f) 2f else 0f
            jitterX.animateTo(offset, animationSpec = tween(800, easing = LinearEasing))
            jitterY.animateTo(if (offset == 0f) 0f else 1f, animationSpec = tween(800))
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .clickable(onClick = onClose)
            .padding(24.dp)
            .graphicsLayer {
                translationX = jitterX.value
                translationY = jitterY.value
            },
        verticalArrangement = Arrangement.spacedBy(24.dp),
    ) {
        signal?.let { s ->
            HudMetric("5G RSRP", s.nrRsrp, "dBm", ColorGauge.rateRsrp(s.nrRsrp))
            HudMetric("5G SNR", s.nrSnr, "dB", ColorGauge.rateSinr(s.nrSnr))
            HudMetric("4G RSRP", s.lteRsrp, "dBm", ColorGauge.rateRsrp(s.lteRsrp))
            HudMetric("4G SINR", s.lteSinr, "dB", ColorGauge.rateSinr(s.lteSinr))
        } ?: Text("データ待機中...", color = Color(0xFF666666), fontSize = 16.sp)
    }
}

@Composable
private fun HudMetric(label: String, value: Double?, unit: String, level: com.syameimarukoa.fs050w_signal_display.domain.model.SignalRatingLevel) {
    val text = if (value != null && value.isFinite() && value > -200) {
        String.format(java.util.Locale.ROOT, "%+.1f", value)
    } else "--"
    Column {
        Text(label, color = Color(0xFF777777), fontSize = 12.sp)
        Text(
            "$text $unit",
            color = ColorGauge.colorFor(level).argbColor().copy(alpha = 0.85f),
            fontFamily = FontFamily.Monospace,
            fontSize = 28.sp,
        )
    }
}
