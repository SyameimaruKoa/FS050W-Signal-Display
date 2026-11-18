package com.syameimarukoa.fs050w_signal_display.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.syameimarukoa.fs050w_signal_display.domain.model.ConnectionModeHelper
import com.syameimarukoa.fs050w_signal_display.domain.model.Fs050wConnectionMode
import com.syameimarukoa.fs050w_signal_display.domain.model.SignalData
import java.util.Locale

/** Flutter 版 Fs050wAppBar のヘッダ相当: アンテナピクト + モードバッジ + バッテリー要約。 */
@Composable
fun StatusHeader(
    signal: SignalData?,
    notation: String,
    isConnecting: Boolean,
    onOpenDetail: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val mode = signal?.connectionMode ?: Fs050wConnectionMode.DISCONNECTED
    val badge = if (isConnecting) "..." else ConnectionModeHelper.getIconBadgeText(mode, notation)
    val mainRsrp = signal?.nrRsrp ?: signal?.lteRsrp
    val isNr = mode == Fs050wConnectionMode.NR5G || mode == Fs050wConnectionMode.NR5G_SUB6
    val themeColor = if (isNr) SignalColors.cyan else SignalColors.blue
    val barCount = when {
        mainRsrp == null || mainRsrp <= -120 -> 0
        mainRsrp <= -110 -> 1
        mainRsrp <= -100 -> 2
        mainRsrp <= -90 -> 3
        else -> 4
    }

    Row(
        modifier = modifier
            .clip(RoundedCornerShape(8.dp))
            .clickable(onClick = onOpenDetail)
            .padding(horizontal = 6.dp, vertical = 2.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        // アンテナピクト (4 本のバー)
        Row(verticalAlignment = Alignment.Bottom) {
            for (i in 0..3) {
                val active = i < barCount
                androidx.compose.foundation.layout.Box(
                    modifier = Modifier
                        .padding(horizontal = 1.dp)
                        .size(width = 3.dp, height = (4 + i * 3).dp)
                        .background(
                            color = if (active) themeColor else Color(0x33FFFFFF),
                            shape = RoundedCornerShape(1.dp),
                        ),
                )
            }
        }
        // モードバッジ
        Text(
            badge,
            color = themeColor,
            fontSize = 12.sp,
            fontWeight = FontWeight.Bold,
            fontFamily = FontFamily.Monospace,
        )
        // バッテリー・温度サマリー
        Column {
            val batText = when {
                signal?.isBatteryPresent == false -> "AC給電"
                signal?.batteryPercent != null ->
                    "${signal!!.batteryPercent}%${if (signal!!.isCharging) "⚡" else ""}"
                else -> "--"
            }
            Text(batText, fontSize = 11.sp, fontWeight = FontWeight.Medium)
            val temp = signal?.batteryTemperature
            val curr = signal?.batteryCurrent
            val detail = buildString {
                if (temp != null) append("${temp.roundToInt()}℃")
                if (curr != null) {
                    if (isNotEmpty()) append(" ")
                    append(String.format(Locale.ROOT, "%+d mA", curr))
                }
            }
            if (detail.isNotEmpty()) {
                Text(detail, fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

private fun Double.roundToInt(): Int = kotlin.math.round(this).toInt()
