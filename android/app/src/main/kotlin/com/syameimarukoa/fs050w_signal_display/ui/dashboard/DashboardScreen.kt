package com.syameimarukoa.fs050w_signal_display.ui.dashboard

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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
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
import com.syameimarukoa.fs050w_signal_display.ui.components.KeyValueRow
import com.syameimarukoa.fs050w_signal_display.ui.components.SignalColors
import com.syameimarukoa.fs050w_signal_display.ui.components.StatusHeader
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DashboardScreen(
    onEnterPip: () -> Unit,
    onOpenHud: () -> Unit,
    onOpenLogs: () -> Unit,
) {
    val repo = LocalRepository.current
    val signal by repo.currentSignal.collectAsStateWithLifecycle()
    val settings by repo.settings.collectAsStateWithLifecycle()
    val status by repo.status.collectAsStateWithLifecycle()
    val error by repo.errorMessage.collectAsStateWithLifecycle()
    val isLoggedIn by repo.isLoggedIn.collectAsStateWithLifecycle()
    val isConnecting by repo.isConnecting.collectAsStateWithLifecycle()
    var showBatterySheet by remember { mutableStateOf(false) }
    var detailsExpanded by remember { mutableStateOf(false) }

    Column(modifier = Modifier.fillMaxSize()) {
        TopAppBar(
            modifier = Modifier.height(56.dp),
            title = {
                StatusHeader(
                    signal = signal,
                    notation = settings.generationNotation,
                    isConnecting = isConnecting,
                    onOpenDetail = { showBatterySheet = true },
                )
            },
            actions = {
                IconButton(onClick = onEnterPip) {
                    Icon(painterResource(R.drawable.ic_pip), contentDescription = "PiP", tint = SignalColors.cyan)
                }
                IconButton(onClick = onOpenLogs) {
                    Icon(painterResource(R.drawable.ic_log), contentDescription = "ログ")
                }
                IconButton(onClick = onOpenHud) {
                    Icon(painterResource(R.drawable.ic_hud), contentDescription = "HUD", tint = SignalColors.yellow)
                }
            },
        )

        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 12.dp, vertical = 4.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            val mode = signal?.connectionMode ?: Fs050wConnectionMode.DISCONNECTED
            val connected = status.name == "AUTHENTICATED" || status.name == "UNAUTHENTICATED_MODE"

            // 接続ステータスバナー
            ConnectionBanner(
                connected = connected,
                isConnecting = isConnecting,
                routerIp = settings.routerIp,
                latency = signal?.routerLatencyMs,
                operatorName = signal?.operatorName,
                modeText = ConnectionModeHelper.getUiModeText(
                    mode, isSa = signal?.isSa ?: false, notation = settings.generationNotation,
                ),
                wifiFreq = signal?.wifiFreqDisplay,
                wifiClients = signal?.wifiClientCount,
                preferNetMode = signal?.preferNetMode,
                isWifiEnabled = signal?.isWifiEnabled ?: false,
            )
            if (!error.isNullOrEmpty()) {
                Text(error!!, color = SignalColors.red, style = MaterialTheme.typography.bodySmall)
            }

            // 電波強度 (RSRP) オーバービュー
            if (signal != null) {
                RsrpOverviewCard(
                    signal = signal!!,
                    mode = mode,
                    notation = settings.generationNotation,
                    isLoggedIn = isLoggedIn,
                )

                // 詳細セル情報（折りたたみ）
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { detailsExpanded = !detailsExpanded },
                    colors = CardDefaults.cardColors(
                        containerColor = MaterialTheme.colorScheme.surfaceContainerLow,
                    ),
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text("詳細セル情報", style = MaterialTheme.typography.titleMedium)
                        Text(if (detailsExpanded) "折りたたむ ▲" else "展開 ▼", color = MaterialTheme.colorScheme.primary)
                    }
                    if (detailsExpanded) {
                        Column(
                            modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp),
                            verticalArrangement = Arrangement.spacedBy(12.dp),
                        ) {
                            if (!signal!!.is5gDisabledByConfig) {
                                DetailCell(
                                    title = ConnectionModeHelper.get5gCardTitle(mode, settings.generationNotation),
                                    band = FrequencyCalculator.getNrBandName(signal!!.nrBand),
                                    pci = signal!!.nrPci,
                                    rsrp = signal!!.nrRsrp,
                                    rsrq = if (isLoggedIn) signal!!.nrRsrq else null,
                                    snr = if (isLoggedIn) signal!!.nrSnr else null,
                                    snrLabel = "SNR",
                                    accent = SignalColors.cyan,
                                )
                            }
                            if (mode != Fs050wConnectionMode.NR5G && mode != Fs050wConnectionMode.NR5G_SUB6 || !signal!!.isSa) {
                                DetailCell(
                                    title = ConnectionModeHelper.get4gCardTitle(mode, settings.generationNotation),
                                    band = FrequencyCalculator.getLteBandName(signal!!.lteBand),
                                    pci = signal!!.ltePci,
                                    rsrp = signal!!.lteRsrp,
                                    rsrq = if (isLoggedIn) signal!!.lteRsrq else null,
                                    snr = if (isLoggedIn) signal!!.lteSinr else null,
                                    snrLabel = "SINR",
                                    accent = SignalColors.blue,
                                )
                            }
                            signal!!.handoverDescription?.let {
                                Text("ハンドオーバー: $it", color = SignalColors.yellow, fontSize = 12.sp)
                            }
                        }
                    }
                }
            }
        }
    }

    if (showBatterySheet && signal != null) {
        BatteryDetailSheet(signal = signal!!, onDismiss = { showBatterySheet = false })
    }
}

@Composable
private fun ConnectionBanner(
    connected: Boolean,
    isConnecting: Boolean,
    routerIp: String,
    latency: Int?,
    operatorName: String?,
    modeText: String,
    wifiFreq: String?,
    wifiClients: Int?,
    preferNetMode: String?,
    isWifiEnabled: Boolean,
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerLow),
    ) {
        Column(modifier = Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Box(
                    modifier = Modifier
                        .size(9.dp)
                        .background(
                            if (connected) SignalColors.green else SignalColors.red,
                            RoundedCornerShape(50),
                        ),
                )
                Text(
                    if (isConnecting) "接続中..." else if (connected) "接続中: $routerIp" else "未接続",
                    color = if (connected) SignalColors.green else SignalColors.red,
                    fontWeight = FontWeight.Bold,
                    fontSize = 14.sp,
                )
                if (latency != null) {
                    Box(
                        modifier = Modifier
                            .background(
                                ColorGauge.latencyColor(latency).argbColorSafe().copy(alpha = 0.18f),
                                RoundedCornerShape(4.dp),
                            )
                            .padding(horizontal = 6.dp, vertical = 2.dp),
                    ) {
                        Text(
                            "⏱ ${latency}ms",
                            color = ColorGauge.latencyColor(latency).argbColorSafe(),
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold,
                        )
                    }
                }
                Text(operatorName ?: "--", modifier = Modifier.weight(1f), fontSize = 13.sp)
            }
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text("ステータス:", style = MaterialTheme.typography.bodyMedium)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                    Box(
                        modifier = Modifier
                            .background(SignalColors.blue.copy(alpha = 0.25f), RoundedCornerShape(4.dp))
                            .padding(horizontal = 6.dp, vertical = 2.dp),
                    ) { Text(modeText, color = SignalColors.blue, fontWeight = FontWeight.Bold, fontSize = 12.sp) }
                    val net = if (preferNetMode != null && preferNetMode!!.contains("5g")) "5G優先" else preferNetMode ?: "--"
                    Text("ルーター設定: $net", fontSize = 12.sp)
                }
            }
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(Color.White.copy(alpha = 0.025f), RoundedCornerShape(6.dp))
                    .border(0.8.dp, Color.White.copy(alpha = 0.06f), RoundedCornerShape(6.dp))
                    .padding(horizontal = 10.dp, vertical = 5.dp),
            ) {
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        Text("📶", fontSize = 14.sp, color = if (isWifiEnabled) SignalColors.cyan else Color.Gray)
                        Text("Wi-Fi: ", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Text(
                            if (isWifiEnabled) "有効 ($wifiFreq)" else "無効",
                            color = if (isWifiEnabled) SignalColors.cyan else Color.Gray,
                            fontWeight = FontWeight.Bold, fontSize = 12.sp,
                        )
                    }
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text("📱", fontSize = 13.sp)
                        Text("${wifiClients ?: 0}台 接続中", fontSize = 11.5.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }
        }
    }
}

@Composable
private fun RsrpOverviewCard(
    signal: SignalData,
    mode: Fs050wConnectionMode,
    notation: String,
    isLoggedIn: Boolean,
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerLow),
    ) {
        Column(modifier = Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Icon(painterResource(R.drawable.ic_graph), contentDescription = null, tint = SignalColors.cyan, modifier = Modifier.size(22.dp))
                    Text("電波強度 (RSRP)", style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.onSurface)
                }
                if (isLoggedIn) {
                    Box(
                        modifier = Modifier
                            .background(SignalColors.good.copy(alpha = 0.18f), RoundedCornerShape(4.dp))
                            .padding(horizontal = 8.dp, vertical = 4.dp),
                    ) { Text("ログイン済", color = SignalColors.good, fontWeight = FontWeight.Bold, fontSize = 12.sp) }
                }
            }
            val is4gOnly = mode == Fs050wConnectionMode.LTE
            val nrBandStr = if (signal.nrBand != null && signal.nrBand!! > 0) "n${signal.nrBand}" else "--"
            val lteBandStr = if (signal.lteBand != null && signal.lteBand!! > 0) "B${signal.lteBand}" else "--"
            androidx.compose.material3.HorizontalDivider(color = Color.White.copy(alpha = 0.08f), thickness = 0.8.dp)
            if (!signal.is5gDisabledByConfig) {
                RsrpPanel(
                    title = ConnectionModeHelper.get5gCardTitle(mode, notation),
                    band = nrBandStr,
                    pci = signal.nrPci,
                    rsrp = signal.nrRsrp,
                    accent = SignalColors.cyan,
                    is5g = true,
                    isStandby = mode == Fs050wConnectionMode.NSA_READY,
                    isSingleMode = is4gOnly,
                )
            }
            if (mode != Fs050wConnectionMode.NR5G && mode != Fs050wConnectionMode.NR5G_SUB6 || !signal.isSa) {
                RsrpPanel(
                    title = ConnectionModeHelper.get4gCardTitle(mode, notation),
                    band = lteBandStr,
                    pci = signal.ltePci,
                    rsrp = signal.lteRsrp,
                    accent = SignalColors.blue,
                    is5g = false,
                    isStandby = false,
                    isSingleMode = signal.isSa,
                )
            }
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Text("✓", color = SignalColors.good, fontWeight = FontWeight.Bold)
                Text("フル情報モード: セル詳細・ハンドオーバー常時監視中", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

@Composable
private fun RsrpPanel(
    title: String, band: String, pci: Int?, rsrp: Double?, accent: Color,
    is5g: Boolean, isStandby: Boolean, isSingleMode: Boolean,
) {
    val isValid = rsrp != null && !rsrp.isNaN() && rsrp < 0
    val level = ColorGauge.rateRsrp(rsrp)
    val color = ColorGauge.colorFor(level).argbColorSafe()
    val progress = ColorGauge.calculateNormalizedRatio(
        rsrp, ColorGauge.RSRP_MIN, ColorGauge.RSRP_MAX, "easeOut",
    ).toFloat()
    val statusLabel = when {
        isValid -> ColorGauge.getLabel(level)
        isStandby -> "NSA待機中"
        isSingleMode -> if (is5g) "4G単独中" else "5G SA中"
        else -> "圏外 / 未接続"
    }
    val titleText = if (band.isNotBlank() && band != "--") "$title ($band)" else title
    val mainValText = if (isValid) "${String.format(Locale.ROOT, "%.1f", rsrp)} dBm" else "-- dBm"

    Card(
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        shape = RoundedCornerShape(10.dp),
        border = androidx.compose.foundation.BorderStroke(1.dp, accent.copy(alpha = 0.3f)),
    ) {
        Column(modifier = Modifier.padding(10.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                Text(titleText, color = accent, fontWeight = FontWeight.Bold, fontSize = 13.sp, maxLines = 1)
                Box(
                    modifier = Modifier
                        .background(color.copy(alpha = 0.18f), RoundedCornerShape(4.dp))
                        .padding(horizontal = 6.dp, vertical = 2.dp),
                ) { Text(statusLabel, color = color, fontSize = 10.sp, fontWeight = FontWeight.Bold) }
            }
            Text(
                mainValText,
                color = if (isValid) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.38f),
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold,
                fontFamily = FontFamily.Monospace,
            )
            LinearProgressIndicator(
                progress = { progress },
                modifier = Modifier.fillMaxWidth().height(5.dp),
                color = color,
                trackColor = MaterialTheme.colorScheme.surfaceContainerHighest,
            )
        }
    }
}

@Composable
private fun DetailCell(
    title: String,
    band: String,
    pci: Int?,
    rsrp: Double?,
    rsrq: Double?,
    snr: Double?,
    snrLabel: String,
    accent: Color,
) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Text(title, color = accent, fontWeight = FontWeight.Bold, fontSize = 13.sp)
            Text("$band / ${pci ?: "--"}", fontSize = 12.sp)
        }
        KeyValueRow("RSRP", rsrp?.let { String.format(Locale.ROOT, "%.1f dBm", it) } ?: "-- dBm")
        KeyValueRow("RSRQ", rsrq?.let { String.format(Locale.ROOT, "%.1f dB", it) } ?: "-- dB")
        KeyValueRow(snrLabel, snr?.let { String.format(Locale.ROOT, "%+.1f dB", it) } ?: "-- dB")
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun BatteryDetailSheet(signal: SignalData, onDismiss: () -> Unit) {
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(16.dp)
                .padding(bottom = 32.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Text("ルーター詳細統計", style = MaterialTheme.typography.titleLarge)
            KeyValueRow("残り稼働予測", signal.estimatedTimeDisplay)
            if (signal.isBatteryPresent) {
                KeyValueRow("バッテリー残量", signal.batteryPercentDisplay)
                KeyValueRow("温度", signal.batteryTemperature?.let { String.format(Locale.ROOT, "%.1f℃", it) } ?: "--")
                KeyValueRow("電圧", signal.batteryVoltage?.let { String.format(Locale.ROOT, "%.2f V", it) } ?: "--")
                KeyValueRow("電流", signal.batteryCurrent?.let { "$it mA" } ?: "--")
                KeyValueRow("状態", signal.batteryChargeStatus ?: "--")
            } else {
                Text("AC給電駆動中 (バッテリーレス)", color = MaterialTheme.colorScheme.primary)
            }
            Text("ハードウェア", style = MaterialTheme.typography.titleMedium)
            KeyValueRow("CPU使用率", signal.cpuUsagePercent?.let { "$it %" } ?: "--")
            KeyValueRow("RAM使用率", signal.formattedRamUsage)
            KeyValueRow("稼働時間", signal.formattedUptime)
            KeyValueRow("プロセス数", signal.processCount?.toString() ?: "--")
        }
    }
}

private fun Long.argbColorSafe(): Color = Color((this and 0xFFFFFFFFL).toInt())
