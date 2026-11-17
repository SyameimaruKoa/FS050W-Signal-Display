package com.syameimarukoa.fs050w_signal_display.ui.dashboard

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
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
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.syameimarukoa.fs050w_signal_display.R
import com.syameimarukoa.fs050w_signal_display.domain.model.ConnectionModeHelper
import com.syameimarukoa.fs050w_signal_display.domain.model.Fs050wConnectionMode
import com.syameimarukoa.fs050w_signal_display.domain.util.ColorGauge
import com.syameimarukoa.fs050w_signal_display.domain.util.FrequencyCalculator
import com.syameimarukoa.fs050w_signal_display.ui.LocalRepository
import com.syameimarukoa.fs050w_signal_display.ui.components.KeyValueRow
import com.syameimarukoa.fs050w_signal_display.ui.components.MetricRow
import com.syameimarukoa.fs050w_signal_display.ui.components.SectionCard
import com.syameimarukoa.fs050w_signal_display.ui.components.argbColor

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
    val latency by repo.currentSignal.collectAsStateWithLifecycle()
    var showBatterySheet by remember { mutableStateOf(false) }

    Column(modifier = Modifier.fillMaxSize()) {
        TopAppBar(
            title = { Text("FS050W Signal Display") },
            actions = {
                IconButton(onClick = { repo.restartPolling() }) {
                    Icon(painterResource(R.drawable.ic_refresh), contentDescription = "再読み込み")
                }
                IconButton(onClick = onEnterPip) {
                    Icon(painterResource(R.drawable.ic_pip), contentDescription = "PiP")
                }
                IconButton(onClick = onOpenHud) {
                    Icon(painterResource(R.drawable.ic_hud), contentDescription = "HUD")
                }
                IconButton(onClick = onOpenLogs) {
                    Icon(painterResource(R.drawable.ic_log), contentDescription = "ログ")
                }
            },
        )

        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 12.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            val mode = signal?.connectionMode ?: Fs050wConnectionMode.DISCONNECTED
            val notation = settings.generationNotation
            val badge = ConnectionModeHelper.getIconBadgeText(mode, notation)
            val modeText = ConnectionModeHelper.getUiModeText(mode, isSa = signal?.isSa ?: false, notation = notation)

            SectionCard(title = "接続ステータス") {
                KeyValueRow("状態", if (status.name == "CONNECTING") "[ 接続中... ]" else "[ $badge ] $modeText")
                KeyValueRow("ルーター", settings.routerIp.ifEmpty { "未設定" })
                KeyValueRow("認証", if (isLoggedIn) "ログイン済み" else "未ログインモード")
                KeyValueRow("事業者", signal?.operatorName ?: "--")
                latency?.routerLatencyMs?.let { KeyValueRow("応答時間", "$it ms") }
                if (!error.isNullOrEmpty()) {
                    Text(error!!, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
                }
            }

            val batterySummary = when {
                signal?.isBatteryPresent == false -> "AC給電"
                signal?.batteryPercent != null -> buildString {
                    append(signal!!.batteryPercentDisplay)
                    if (signal!!.isCharging) append(" ⚡")
                    signal!!.batteryTemperature?.let { append(" ${it.toInt()}℃") }
                }
                else -> "--"
            }
            SectionCard(title = "バッテリー / システム") {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { showBatterySheet = true },
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text("詳細を見る", style = MaterialTheme.typography.bodyMedium)
                    Text(batterySummary, style = MaterialTheme.typography.bodyMedium)
                }
                signal?.handoverDescription?.let {
                    Text("ハンドオーバー: $it", style = MaterialTheme.typography.bodySmall)
                }
            }

            val s = signal
            if (s != null) {
                if (!s.is5gDisabledByConfig) {
                    SectionCard(title = ConnectionModeHelper.get5gCardTitle(mode, notation)) {
                        val band = FrequencyCalculator.getNrBandName(s.nrBand)
                        KeyValueRow("Band / PCI", "$band / ${s.nrPci ?: "--"}")
                        MetricRow(
                            "RSRP", s.nrRsrp, "dBm",
                            ColorGauge.metricColor(s.nrRsrp, ColorGauge.rateRsrp(s.nrRsrp), ColorGauge.RSRP_MIN, ColorGauge.RSRP_MAX),
                            ColorGauge.RSRP_MIN, ColorGauge.RSRP_MAX,
                        )
                        MetricRow(
                            "RSRQ", s.nrRsrq, "dB",
                            ColorGauge.metricColor(s.nrRsrq, ColorGauge.rateRsrq(s.nrRsrq), ColorGauge.RSRQ_MIN, ColorGauge.RSRQ_MAX),
                            ColorGauge.RSRQ_MIN, ColorGauge.RSRQ_MAX,
                        )
                        MetricRow(
                            if (notation == "lte_nr") "SNR" else "SNR", s.nrSnr, "dB",
                            ColorGauge.metricColor(s.nrSnr, ColorGauge.rateSinr(s.nrSnr), ColorGauge.SINR_MIN, ColorGauge.SINR_MAX),
                            ColorGauge.SINR_MIN, ColorGauge.SINR_MAX, signed = true,
                        )
                    }
                }

                if (mode != Fs050wConnectionMode.NR5G && mode != Fs050wConnectionMode.NR5G_SUB6 || !s.isSa) {
                    SectionCard(title = ConnectionModeHelper.get4gCardTitle(mode, notation)) {
                        KeyValueRow(
                            "Band / PCI",
                            "${FrequencyCalculator.getLteBandName(s.lteBand)} / ${s.ltePci ?: "--"}",
                        )
                        MetricRow(
                            "RSRP", s.lteRsrp, "dBm",
                            ColorGauge.metricColor(s.lteRsrp, ColorGauge.rateRsrp(s.lteRsrp), ColorGauge.RSRP_MIN, ColorGauge.RSRP_MAX),
                            ColorGauge.RSRP_MIN, ColorGauge.RSRP_MAX,
                        )
                        MetricRow(
                            "RSRQ", s.lteRsrq, "dB",
                            ColorGauge.metricColor(s.lteRsrq, ColorGauge.rateRsrq(s.lteRsrq), ColorGauge.RSRQ_MIN, ColorGauge.RSRQ_MAX),
                            ColorGauge.RSRQ_MIN, ColorGauge.RSRQ_MAX,
                        )
                        MetricRow(
                            "SINR", s.lteSinr, "dB",
                            ColorGauge.metricColor(s.lteSinr, ColorGauge.rateSinr(s.lteSinr), ColorGauge.SINR_MIN, ColorGauge.SINR_MAX),
                            ColorGauge.SINR_MIN, ColorGauge.SINR_MAX, signed = true,
                        )
                    }
                }
            }
        }
    }

    if (showBatterySheet && signal != null) {
        val s = signal!!
        ModalBottomSheet(
            onDismissRequest = { showBatterySheet = false },
            sheetState = rememberModalBottomSheetState(),
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .verticalScroll(rememberScrollState())
                    .padding(16.dp)
                    .padding(bottom = 32.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Text("ルーター詳細統計", style = MaterialTheme.typography.titleLarge)
                KeyValueRow("残り稼働予測", s.estimatedTimeDisplay)
                if (s.isBatteryPresent) {
                    KeyValueRow("バッテリー残量", s.batteryPercentDisplay)
                    KeyValueRow("温度", s.batteryTemperature?.let { String.format(java.util.Locale.ROOT, "%.1f", it) + "℃" } ?: "--")
                    KeyValueRow("電圧", s.batteryVoltage?.let { String.format(java.util.Locale.ROOT, "%.2f", it) + " V" } ?: "--")
                    KeyValueRow("電流", s.batteryCurrent?.let { "$it mA" } ?: "--")
                    KeyValueRow("状態", s.batteryChargeStatus ?: "--")
                } else {
                    Text("AC給電駆動中 (バッテリーレス)", color = MaterialTheme.colorScheme.primary)
                }
                Text("ハードウェア", style = MaterialTheme.typography.titleMedium)
                KeyValueRow("CPU使用率", s.cpuUsagePercent?.let { "$it %" } ?: "--")
                KeyValueRow("RAM使用率", s.formattedRamUsage)
                KeyValueRow("稼働時間", s.formattedUptime)
                KeyValueRow("プロセス数", s.processCount?.toString() ?: "--")
            }
        }
    }
}
