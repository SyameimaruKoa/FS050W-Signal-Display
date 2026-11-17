package com.syameimarukoa.fs050w_signal_display.ui.setup

import android.content.Context
import android.net.wifi.WifiManager
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.syameimarukoa.fs050w_signal_display.ui.LocalRepository
import kotlinx.coroutines.launch

@Composable
fun SetupWizardScreen(onFinished: () -> Unit) {
    val repo = LocalRepository.current
    val settings by repo.settings.collectAsStateWithLifecycle()
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var ip by remember { mutableStateOf(settings.routerIp.ifEmpty { detectGateway(context) ?: "192.168.100.1" }) }
    var password by remember { mutableStateOf(settings.webPassword) }
    var message by remember { mutableStateOf<String?>(null) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text("+F FS050W 初期セットアップ", style = MaterialTheme.typography.headlineSmall)
        Text("ルーターに接続して電波監視を開始します。", style = MaterialTheme.typography.bodyMedium)
        OutlinedTextField(
            value = ip,
            onValueChange = { ip = it },
            label = { Text("ルーターIPアドレス") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )
        OutlinedTextField(
            value = password,
            onValueChange = { password = it },
            label = { Text("Web管理パスワード (任意)") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )
        Button(onClick = {
            scope.launch {
                message = if (repo.testConnection(ip, password)) "接続テスト成功" else "接続テスト失敗"
            }
        }) { Text("接続テスト") }
        message?.let { Text(it) }
        Button(onClick = {
            repo.updateSettings(
                settings.copy(routerIp = ip, webPassword = password, isSetupCompleted = true),
            )
            repo.restartPolling()
            onFinished()
        }) { Text("設定を保存して開始") }
    }
}

private fun detectGateway(context: Context): String? = try {
    @Suppress("DEPRECATION")
    val wifi = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
    val gateway = wifi?.dhcpInfo?.gateway ?: 0
    if (gateway == 0) null else
        "${gateway and 0xFF}.${(gateway shr 8) and 0xFF}.${(gateway shr 16) and 0xFF}.${(gateway shr 24) and 0xFF}"
} catch (_: Exception) {
    null
}
