package com.syameimarukoa.fs050w_signal_display.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.syameimarukoa.fs050w_signal_display.domain.util.ColorGauge

fun Long.argbColor(): Color = Color((this and 0xFFFFFFFFL).toInt())

/** 信号品質 6 段階の固定色（Material You の dinamic カラーとは別に意味論を保持）。 */
object SignalColors {
    val excellent = 0xFF2196F3L.argbColor()
    val good = 0xFF4CAF50L.argbColor()
    val moderate = 0xFF8BC34AL.argbColor()
    val weak = 0xFFFF9800L.argbColor()
    val veryWeak = 0xFFF44336L.argbColor()
    val critical = 0xFF9C27B0L.argbColor()
    val cyan = 0xFF00E5FFL.argbColor()
    val blue = 0xFF64B5F6L.argbColor()
    val green = 0xFF00E676L.argbColor()
    val yellow = 0xFFFFD600L.argbColor()
    val red = 0xFFFF5252L.argbColor()
}

@Composable
fun SectionCard(
    title: String,
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit,
) {
    Card(
        modifier = modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceContainerLow,
        ),
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(
                text = title,
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.primary,
            )
            content()
        }
    }
}

@Composable
fun MetricRow(
    label: String,
    value: Double?,
    unit: String,
    color: Long,
    min: Double,
    max: Double,
    curve: String = "easeOut",
    signed: Boolean = false,
    modifier: Modifier = Modifier,
) {
    val valueText = if (value != null && value.isFinite() && value > -200) {
        if (signed && value > 0) String.format(java.util.Locale.ROOT, "+%.1f", value)
        else String.format(java.util.Locale.ROOT, "%.1f", value)
    } else "--"
    val progress = ColorGauge.calculateNormalizedRatio(value, min, max, curve).toFloat()
    val argb = color.argbColor()

    Column(modifier = modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(label, style = MaterialTheme.typography.bodyMedium)
            Text(
                text = "$valueText $unit",
                style = MaterialTheme.typography.bodyMedium.copy(fontFamily = FontFamily.Monospace),
                color = argb,
                fontWeight = FontWeight.Bold,
            )
        }
        LinearProgressIndicator(
            progress = { progress },
            modifier = Modifier
                .fillMaxWidth()
                .height(6.dp)
                .padding(top = 4.dp),
            color = argb,
            trackColor = MaterialTheme.colorScheme.surfaceContainerHighest,
        )
    }
}

@Composable
fun KeyValueRow(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(label, style = MaterialTheme.typography.bodyMedium)
        Text(
            value,
            style = MaterialTheme.typography.bodyMedium.copy(fontFamily = FontFamily.Monospace),
        )
    }
}
