package com.syameimarukoa.fs050w_signal_display.ui.settings

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import android.view.View
import android.view.autofill.AutofillManager
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Slider
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.syameimarukoa.fs050w_signal_display.R
import com.syameimarukoa.fs050w_signal_display.data.AppLogger
import com.syameimarukoa.fs050w_signal_display.domain.model.AppNavigationStyle
import com.syameimarukoa.fs050w_signal_display.domain.model.AppSettings
import com.syameimarukoa.fs050w_signal_display.domain.model.AppThemeMode
import com.syameimarukoa.fs050w_signal_display.ui.LocalRepository
import com.syameimarukoa.fs050w_signal_display.ui.components.AutofillField
import com.syameimarukoa.fs050w_signal_display.ui.components.KeyValueRow
import com.syameimarukoa.fs050w_signal_display.ui.components.SectionCard
import kotlinx.coroutines.launch

@Composable
fun SettingsScreen(onOverlayChanged: (Boolean) -> Unit) {
    val repo = LocalRepository.current
    val settings by repo.settings.collectAsStateWithLifecycle()
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var showLogs by remember { mutableStateOf(false) }
    var connectionMessage by remember { mutableStateOf<String?>(null) }
    var passwordVisible by remember { mutableStateOf(false) }

    fun update(transform: (AppSettings) -> AppSettings) {
        repo.updateSettings(transform(settings))
    }

    fun commitAutofill() {
        try {
            context.getSystemService(AutofillManager::class.java)?.commit()
        } catch (_: Exception) {
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        SectionCard(title = "接続設定") {
            AutofillField(
                value = settings.routerIp,
                onValueChange = { value -> update { s -> s.copy(routerIp = value) } },
                label = "ルーターIPアドレス",
                hints = arrayOf("uri", View.AUTOFILL_HINT_USERNAME),
                onDone = { commitAutofill() },
            )
            Row(verticalAlignment = Alignment.CenterVertically) {
                AutofillField(
                    modifier = Modifier.weight(1f),
                    value = settings.webPassword,
                    onValueChange = { value -> update { s -> s.copy(webPassword = value) } },
                    label = "Web管理パスワード",
                    hints = arrayOf(View.AUTOFILL_HINT_PASSWORD),
                    password = true,
                    passwordVisible = passwordVisible,
                    imeDone = true,
                    onDone = { commitAutofill() },
                )
                IconButton(onClick = { passwordVisible = !passwordVisible }) {
                    Icon(
                        painterResource(if (passwordVisible) R.drawable.ic_visibility_off else R.drawable.ic_visibility),
                        contentDescription = if (passwordVisible) "パスワードを隠す" else "パスワードを表示",
                    )
                }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Button(onClick = {
                    scope.launch {
                        val ok = repo.testConnection(settings.routerIp, settings.webPassword)
                        connectionMessage = if (ok) "接続テスト成功" else "接続テスト失敗"
                    }
                    commitAutofill()
                }) { Text("接続テスト") }
                connectionMessage?.let { Text(it, modifier = Modifier.align(Alignment.CenterVertically)) }
            }
        }

        SectionCard(title = "ポーリング設定") {
            KeyValueRow("フォアグラウンド間隔", "${settings.foregroundIntervalSeconds} 秒")
            Slider(
                value = settings.foregroundIntervalSeconds.toFloat(),
                onValueChange = { value -> update { s -> s.copy(foregroundIntervalSeconds = value.toInt().coerceIn(1, 5)) } },
                valueRange = 1f..5f,
                steps = 3,
            )
            KeyValueRow("未ログイン時間隔", "${settings.unauthIntervalSeconds} 秒")
            Slider(
                value = settings.unauthIntervalSeconds.toFloat(),
                onValueChange = { value -> update { s -> s.copy(unauthIntervalSeconds = value.toInt().coerceIn(3, 10)) } },
                valueRange = 3f..10f,
                steps = 6,
            )
        }

        SectionCard(title = "監視 & フローティング表示") {
            SwitchRow("フローティングオーバーレイ", settings.overlayEnabled) { enabled ->
                if (enabled && !Settings.canDrawOverlays(context)) {
                    context.startActivity(
                        Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:${context.packageName}"))
                    )
                } else {
                    update { s -> s.copy(overlayEnabled = enabled) }
                    onOverlayChanged(enabled)
                }
            }
            ChipSelector(
                label = "オーバーレイ表示形式",
                options = listOf("card" to "カード", "compact" to "コンパクト"),
                selected = settings.overlayStyle,
            ) { value -> update { s -> s.copy(overlayStyle = value) } }
            KeyValueRow("背景透過度", "%.0f%%".format(java.util.Locale.ROOT, settings.overlayOpacity * 100))
            Slider(
                value = settings.overlayOpacity.toFloat(),
                onValueChange = { value -> update { s -> s.copy(overlayOpacity = value.toDouble()) } },
                valueRange = 0.2f..1f,
            )
            SwitchRow("ホーム時に自動PiP", settings.autoPipOnHome) { enabled ->
                update { s -> s.copy(autoPipOnHome = enabled) }
            }
            ChipSelector(
                label = "PiP アスペクト比",
                options = listOf("16:9", "9:16", "1:1", "4:3", "3:4", "21:9", "9:21").map { it to it },
                selected = settings.pipAspectRatio,
            ) { value -> update { s -> s.copy(pipAspectRatio = value) } }
        }

        SectionCard(title = "イベント検知 & LEDランプ") {
            SwitchRow("イベントLEDランプ", settings.eventLampEnabled) { enabled ->
                update { s -> s.copy(eventLampEnabled = enabled) }
            }
            ChipSelector(
                label = "ランプ形状",
                options = listOf("bar" to "スリムバー", "dot" to "LEDドット"),
                selected = settings.eventLampShape,
            ) { value -> update { s -> s.copy(eventLampShape = value) } }
            ChipSelector(
                label = "ランプ位置",
                options = listOf("topCenter" to "中央", "topLeft" to "左", "topRight" to "右"),
                selected = settings.eventLampPosition,
            ) { value -> update { s -> s.copy(eventLampPosition = value) } }
            SwitchRow("5G+ 突入バイブ", settings.vibrateOn5gSub6) { enabled ->
                update { s -> s.copy(vibrateOn5gSub6 = enabled) }
            }
            SwitchRow("ハンドオーバーバイブ", settings.vibrateOnHandover) { enabled ->
                update { s -> s.copy(vibrateOnHandover = enabled) }
            }
            SwitchRow("電波微弱警告バイブ", settings.vibrateOnCriticalSignal) { enabled ->
                update { s -> s.copy(vibrateOnCriticalSignal = enabled) }
            }
            SwitchRow("バッテリー高温警告", settings.batteryTempWarningEnabled) { enabled ->
                update { s -> s.copy(batteryTempWarningEnabled = enabled) }
            }
            KeyValueRow("警告温度", "${settings.batteryTempWarningThreshold.toInt()}℃")
            Slider(
                value = settings.batteryTempWarningThreshold.toFloat(),
                onValueChange = { value -> update { s -> s.copy(batteryTempWarningThreshold = value.toDouble()) } },
                valueRange = 38f..50f,
                steps = 11,
            )
        }

        SectionCard(title = "UI・テーマ") {
            SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
                listOf("システム" to AppThemeMode.SYSTEM, "ライト" to AppThemeMode.LIGHT, "ダーク" to AppThemeMode.DARK, "OLED" to AppThemeMode.OLED)
                    .forEachIndexed { index, (label, mode) ->
                        SegmentedButton(
                            selected = settings.appTheme == mode,
                            onClick = { update { s -> s.copy(appTheme = mode) } },
                            shape = SegmentedButtonDefaults.itemShape(index = index, count = 4),
                        ) { Text(label) }
                    }
            }
            ChipSelector(
                label = "ナビゲーション",
                options = listOf("bottom" to "ボトム", "buttons" to "ボタン"),
                selected = if (settings.navigationStyle == AppNavigationStyle.BOTTOM_NAV) "bottom" else "buttons",
            ) { value ->
                update { s ->
                    s.copy(navigationStyle = if (value == "bottom") AppNavigationStyle.BOTTOM_NAV else AppNavigationStyle.CARD_BUTTONS)
                }
            }
            ChipSelector(
                label = "世代表記",
                options = listOf("4g_5g" to "4G / 5G", "lte_nr" to "LTE / NR"),
                selected = settings.generationNotation,
            ) { value -> update { s -> s.copy(generationNotation = value) } }
            SwitchRow("画面の常時点灯", settings.keepScreenOn) { enabled ->
                update { s -> s.copy(keepScreenOn = enabled) }
            }
            SwitchRow("5G SNR 補正 (-23dB)", settings.adjust5gSnr) { enabled ->
                update { s -> s.copy(adjust5gSnr = enabled) }
            }
            SwitchRow("シームレスゲージカラー", settings.smoothGaugeColor) { enabled ->
                update { s -> s.copy(smoothGaugeColor = enabled) }
            }
            SwitchRow("更新フラッシュドット", settings.updateFlashDotEnabled) { enabled ->
                update { s -> s.copy(updateFlashDotEnabled = enabled) }
            }
            Button(onClick = { showLogs = true }) { Text("診断ログを表示") }
        }
    }

    if (showLogs) {
        AlertDialog(
            onDismissRequest = { showLogs = false },
            title = { Text("診断ログ") },
            text = {
                Column(modifier = Modifier.verticalScroll(rememberScrollState())) {
                    Text(AppLogger.exportText(), style = MaterialTheme.typography.bodySmall)
                }
            },
            confirmButton = { TextButton(onClick = { showLogs = false }) { Text("閉じる") } },
        )
    }
}

@Composable
private fun SwitchRow(label: String, checked: Boolean, onCheckedChange: (Boolean) -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(label, style = MaterialTheme.typography.bodyMedium)
        Switch(checked = checked, onCheckedChange = onCheckedChange)
    }
}

@Composable
private fun ChipSelector(
    label: String,
    options: List<Pair<String, String>>,
    selected: String,
    onSelect: (String) -> Unit,
) {
    Text(label, style = MaterialTheme.typography.bodySmall)
    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        options.forEach { (value, text) ->
            FilterChip(
                selected = selected == value,
                onClick = { onSelect(value) },
                label = { Text(text) },
            )
        }
    }
}
