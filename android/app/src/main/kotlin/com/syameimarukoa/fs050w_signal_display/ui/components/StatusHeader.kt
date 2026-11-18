package com.syameimarukoa.fs050w_signal_display.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.syameimarukoa.fs050w_signal_display.R
import com.syameimarukoa.fs050w_signal_display.domain.model.ConnectionModeHelper
import com.syameimarukoa.fs050w_signal_display.domain.model.Fs050wConnectionMode
import com.syameimarukoa.fs050w_signal_display.domain.model.SignalData
import java.util.Locale

/** Flutter 版 Fs050wAppBar と同じヘッダ: アンテナピクト + モードバッジ +
 *  バッテリー/温度/電流 + キャリア名と「詳細」リンク。 */
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
            .padding(horizontal = 6.dp, vertical = 3.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        // アンテナピクト (4 本のバー) + バッジ
        Row(
            verticalAlignment = Alignment.Bottom,
            modifier = Modifier.background(Color(0x2200E5FF), RoundedCornerShape(4.dp)).padding(3.dp),
        ) {
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
            Text(
                badge,
                color = themeColor,
                fontSize = 11.sp,
                fontWeight = FontWeight.Bold,
                fontFamily = FontFamily.Monospace,
                modifier = Modifier.padding(start = 3.dp),
            )
        }

        // バッテリー / 温度 / 電流 (1 行目) + キャリア / 詳細 (2 行目)
        Column(modifier = Modifier.weight(1f)) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                val hasBattery = signal?.isBatteryPresent ?: true
                Icon(
                    painter = painterResource(
                        if (!hasBattery) R.drawable.ic_power
                        else if (signal?.isCharging == true) R.drawable.ic_battery_charging
                        else R.drawable.ic_battery,
                    ),
                    contentDescription = null,
                    tint = if (!hasBattery) themeColor else SignalColors.yellow,
                    modifier = Modifier.size(14.dp),
                )
                val batText = when {
                    !hasBattery -> "AC給電"
                    signal?.batteryPercent != null -> "${signal!!.batteryPercent}%"
                    else -> "--"
                }
                Text(batText, fontSize = 11.sp, fontWeight = FontWeight.Bold)
                if (signal?.isCharging == true) {
                    Text("⚡", color = SignalColors.yellow, fontSize = 11.sp)
                }
                signal?.batteryTemperature?.let {
                    Text("${it.roundToInt()}℃", color = SignalColors.cyan, fontSize = 11.sp)
                }
                signal?.batteryCurrent?.let {
                    Text(String.format(Locale.ROOT, "%+dmA", it), fontSize = 10.sp)
                }
            }
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(3.dp),
            ) {
                Text(
                    signal?.operatorName ?: "--",
                    fontSize = 10.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Text("詳細", color = themeColor, fontSize = 10.sp, fontWeight = FontWeight.Bold)
            }
        }
    }
}

private fun Double.roundToInt(): Int = kotlin.math.round(this).toInt()
