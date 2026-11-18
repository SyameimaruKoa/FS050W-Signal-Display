package com.syameimarukoa.fs050w_signal_display.ui.settings

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import android.view.autofill.AutofillManager
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.TextField
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.syameimarukoa.fs050w_signal_display.R
import com.syameimarukoa.fs050w_signal_display.data.AppLogger
import com.syameimarukoa.fs050w_signal_display.domain.model.AppNavigationStyle
import com.syameimarukoa.fs050w_signal_display.domain.model.AppSettings
import com.syameimarukoa.fs050w_signal_display.domain.model.AppThemeMode
import com.syameimarukoa.fs050w_signal_display.ui.LocalRepository
import com.syameimarukoa.fs050w_signal_display.ui.components.AutofillCredentialFields
import com.syameimarukoa.fs050w_signal_display.ui.components.Fs050wTopAppBar
import com.syameimarukoa.fs050w_signal_display.ui.components.KeyValueRow
import com.syameimarukoa.fs050w_signal_display.ui.components.SignalColors
import kotlinx.coroutines.launch

@Composable
fun SettingsScreen(onOverlayChanged: (Boolean) -> Unit, onEnterPip: () -> Unit, onOpenLogs: () -> Unit, onOpenHud: () -> Unit) {
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

    Column(modifier = Modifier.fillMaxSize()) {
        Fs050wTopAppBar(onEnterPip, onOpenLogs, onOpenHud, onOpenDetail = {})
        Column(
            modifier = Modifier
                .fillMaxSize()
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 12.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
        SettingsSection(title = "1. 監視 & フローティング表示", painter = painterResource(R.drawable.ic_pip)) {
            SwitchRow(
                "フローティングオーバーレイ",
                settings.overlayEnabled,
                subtitle = "他アプリ使用中も最前面に電波ウィジェットを常時表示",
                onCheckedChange = { enabled ->
                    if (enabled && !Settings.canDrawOverlays(context)) {
                        context.startActivity(
                            Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:${context.packageName}"))
                        )
                    } else {
                        update { s -> s.copy(overlayEnabled = enabled) }
                        onOverlayChanged(enabled)
                    }
                },
            )
            if (settings.overlayEnabled) {
                DropdownSelector(
                    label = "オーバーレイ表示形式",
                    options = listOf("card" to "PiP共通カード型 (スタイルA)", "compact" to "コンパクト行型 (スタイルB)"),
                    selected = settings.overlayStyle,
                ) { value -> update { s -> s.copy(overlayStyle = value) } }
                KeyValueRow("背景透過度", "%.0f%%".format(java.util.Locale.ROOT, settings.overlayOpacity * 100))
                Slider(
                    value = settings.overlayOpacity.toFloat(),
                    onValueChange = { value -> update { s -> s.copy(overlayOpacity = value.toDouble()) } },
                    valueRange = 0.2f..1f,
                )
            }
            HorizontalDivider(color = Color.White.copy(alpha = 0.12f))
            SwitchRow(
                "ホーム画面に戻った時に自動でPiP起動",
                settings.autoPipOnHome,
                subtitle = "アプリ使用中にホーム操作を行うと自動で小窓化",
                onCheckedChange = { enabled -> update { s -> s.copy(autoPipOnHome = enabled) } },
            )
            DropdownSelector(
                label = "PiP アスペクト比 (全7種)",
                options = listOf("16:9" to "16:9 (横長標準)", "9:16" to "9:16 (縦長標準)", "1:1" to "1:1 (正方形)", "4:3" to "4:3 (横長クラシック)", "3:4" to "3:4 (縦長クラシック)", "21:9" to "21:9 (ウルトラワイド)", "9:21" to "9:21 (ウルトラトール)"),
                selected = settings.pipAspectRatio,
            ) { value -> update { s -> s.copy(pipAspectRatio = value) } }
            Text("現在: ${settings.pipAspectRatio}", style = MaterialTheme.typography.bodySmall)
            DropdownSelector(
                label = "PiP 拡大時グラフ種類",
                options = listOf("rsrp" to "RSRP 履歴", "snr" to "SNR / SINR 履歴", "rsrq" to "RSRQ 履歴", "none" to "非表示"),
                selected = settings.pipGraphType,
            ) { value -> update { s -> s.copy(pipGraphType = value) } }
            Text("PiP枠が一定サイズ以上の時にグラフを表示します。", style = MaterialTheme.typography.bodySmall)
            Slider(
                value = settings.pipGraphScaleThreshold.toFloat(),
                onValueChange = { value -> update { s -> s.copy(pipGraphScaleThreshold = value.toDouble()) } },
                valueRange = 0.5f..1.5f,
                steps = 9,
            )
            Text("現在: ${"%.1f".format(java.util.Locale.ROOT, settings.pipGraphScaleThreshold)}倍 (小さいほど表示されやすい)", style = MaterialTheme.typography.bodySmall.copy(color = MaterialTheme.colorScheme.onSurfaceVariant))
        }

        SettingsSection(title = "2. イベントハプティクス & LED通知", painter = painterResource(R.drawable.ic_hud)) {
            SwitchRow("イベントLEDランプ", settings.eventLampEnabled) { enabled ->
                update { s -> s.copy(eventLampEnabled = enabled) }
            }
            DropdownSelector(
                label = "ランプ形状",
                options = listOf("bar" to "スリムバー (画面幅1/4)", "dot" to "丸型 LED (8dp)"),
                selected = settings.eventLampShape,
            ) { value -> update { s -> s.copy(eventLampShape = value) } }
            DropdownSelector(
                label = "ランプ位置",
                options = listOf("topCenter" to "画面中央上部", "topLeft" to "画面左上", "topRight" to "画面右上"),
                selected = settings.eventLampPosition,
            ) { value -> update { s -> s.copy(eventLampPosition = value) } }
            HorizontalDivider(color = Color.White.copy(alpha = 0.12f))
            SwitchRow("5G+ 突入バイブ", settings.vibrateOn5gSub6) { enabled ->
                update { s -> s.copy(vibrateOn5gSub6 = enabled) }
            }
            SwitchRow("ハンドオーバーバイブ", settings.vibrateOnHandover) { enabled ->
                update { s -> s.copy(vibrateOnHandover = enabled) }
            }
            SwitchRow("電波微弱警告バイブ", settings.vibrateOnCriticalSignal) { enabled ->
                update { s -> s.copy(vibrateOnCriticalSignal = enabled) }
            }
            HorizontalDivider(color = Color.White.copy(alpha = 0.12f))
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

        SettingsSection(title = "3. 通信 & ルーター接続", painter = painterResource(R.drawable.ic_dashboard)) {
            AutofillCredentialFields(
                ip = settings.routerIp,
                password = settings.webPassword,
                onIpChange = { value -> update { s -> s.copy(routerIp = value) } },
                onPasswordChange = { value -> update { s -> s.copy(webPassword = value) } },
                passwordVisible = passwordVisible,
                onDone = { commitAutofill() },
            )
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("パスワードを表示", modifier = Modifier.weight(1f))
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
            DropdownSelector(
                label = "ログイン時ポーリング間隔",
                options = listOf(1 to "1秒 (推奨)", 2 to "2秒", 3 to "3秒", 5 to "5秒").map { it.first.toString() to it.second },
                selected = settings.foregroundIntervalSeconds.toString(),
            ) { value -> update { s -> s.copy(foregroundIntervalSeconds = value.toInt()) } }
            DropdownSelector(
                label = "未ログイン時ポーリング間隔",
                options = listOf(3 to "3秒 (推奨)", 5 to "5秒", 10 to "10秒").map { it.first.toString() to it.second },
                selected = settings.unauthIntervalSeconds.toString(),
            ) { value -> update { s -> s.copy(unauthIntervalSeconds = value.toInt()) } }
        }

        SettingsSection(title = "4. UI・テーマ & 表示設定", painter = painterResource(R.drawable.ic_settings)) {
            DropdownSelector(
                label = "通信規格の表記方式",
                options = listOf("4g_5g" to "4G / 5G / e4G", "lte_nr" to "LTE / NR / eLTE"),
                selected = settings.generationNotation,
            ) { value -> update { s -> s.copy(generationNotation = value) } }
            SwitchRow("5G SNR 値の補正 (-23dB)", settings.adjust5gSnr) { enabled ->
                update { s -> s.copy(adjust5gSnr = enabled) }
            }
            SwitchRow("更新時ポッチ点滅 (フラッシュインジケーター)", settings.updateFlashDotEnabled) { enabled ->
                update { s -> s.copy(updateFlashDotEnabled = enabled) }
            }
            SwitchRow("シームレスゲージカラー", settings.smoothGaugeColor) { enabled ->
                update { s -> s.copy(smoothGaugeColor = enabled) }
            }
            if (settings.smoothGaugeColor) {
                DropdownSelector(
                    label = "グラデーション曲線 (イージング)",
                    options = listOf("easeOut" to "Ease Out (推奨: 弱電界の変化を強調)", "easeIn" to "Ease In (強電界の変化を強調)", "easeInOut" to "Ease In-Out (S字曲線)", "linear" to "Linear (リニア / 線形)"),
                    selected = settings.smoothGaugeCurve,
                ) { value -> update { s -> s.copy(smoothGaugeCurve = value) } }
            }
            SwitchRow("画面の常時点灯 (スリープ防止)", settings.keepScreenOn) { enabled ->
                update { s -> s.copy(keepScreenOn = enabled) }
            }
            DropdownSelector(
                label = "グラフ初期表示スパン",
                options = listOf(1 to "1分", 3 to "3分 (推奨)", 5 to "5分", 10 to "10分").map { it.first.toString() to it.second },
                selected = settings.graphSpanMinutes.toString(),
            ) { value -> update { s -> s.copy(graphSpanMinutes = value.toInt()) } }
            DropdownSelector(
                label = "アプリテーマ",
                options = listOf("OLED" to "OLED 漆黒ダーク", "DARK" to "マテリアルダーク", "LIGHT" to "ライトモード", "SYSTEM" to "システム追従"),
                selected = settings.appTheme.name,
            ) { value -> update { s -> s.copy(appTheme = AppThemeMode.valueOf(value)) } }
            DropdownSelector(
                label = "ナビゲーション",
                options = listOf("bottom" to "ボトム", "buttons" to "ボタン"),
                selected = if (settings.navigationStyle == AppNavigationStyle.BOTTOM_NAV) "bottom" else "buttons",
            ) { value ->
                update { s ->
                    s.copy(navigationStyle = if (value == "bottom") AppNavigationStyle.BOTTOM_NAV else AppNavigationStyle.CARD_BUTTONS)
                }
            }
            HorizontalDivider(color = Color.White.copy(alpha = 0.12f))
            Button(onClick = { showLogs = true }) { Text("診断ログを表示") }
            }
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
private fun SettingsSection(
    title: String,
    painter: androidx.compose.ui.graphics.painter.Painter,
    content: @Composable ColumnScope.() -> Unit,
) {
    Column {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(painter, contentDescription = null, tint = SignalColors.cyan, modifier = Modifier.size(18.dp))
            Spacer(Modifier.width(8.dp))
            Text(title, color = SignalColors.cyan, fontSize = 15.sp, fontWeight = androidx.compose.ui.text.font.FontWeight.Bold)
        }
        Spacer(Modifier.height(8.dp))
        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerLow),
            shape = androidx.compose.foundation.shape.RoundedCornerShape(10.dp),
            border = androidx.compose.foundation.BorderStroke(0.6.dp, Color.White.copy(alpha = 0.12f)),
        ) {
            Column(
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
                content = content,
            )
        }
    }
}

@Composable
private fun SwitchRow(
    label: String,
    checked: Boolean,
    subtitle: String? = null,
    onCheckedChange: (Boolean) -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(label, style = MaterialTheme.typography.bodyMedium)
            if (subtitle != null) {
                Text(subtitle, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
        Switch(checked = checked, onCheckedChange = onCheckedChange)
    }
}

@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
private fun DropdownSelector(
    label: String,
    options: List<Pair<String, String>>,
    selected: String,
    onSelect: (String) -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(label, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.weight(1f))
        ExposedDropdownMenuBox(expanded = expanded, onExpandedChange = { expanded = it }) {
            TextField(
                value = options.firstOrNull { it.first == selected }?.second ?: selected,
                onValueChange = {},
                readOnly = true,
                singleLine = true,
                modifier = Modifier.menuAnchor().width(200.dp),
                colors = ExposedDropdownMenuDefaults.textFieldColors(),
                trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
            )
            ExposedDropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                options.forEach { (value, text) ->
                    DropdownMenuItem(
                        text = { Text(text) },
                        onClick = { onSelect(value); expanded = false },
                    )
                }
            }
        }
    }
}
