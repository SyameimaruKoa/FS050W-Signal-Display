package com.syameimarukoa.fs050w_signal_display.ui.setup

import android.content.Context
import android.net.wifi.WifiManager
import android.view.autofill.AutofillManager
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
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
import com.syameimarukoa.fs050w_signal_display.ui.LocalRepository
import com.syameimarukoa.fs050w_signal_display.ui.components.AutofillCredentialFields
import kotlinx.coroutines.launch

@Composable
fun SetupWizardScreen(onFinished: () -> Unit) {
    val repo = LocalRepository.current
    val settings by repo.settings.collectAsStateWithLifecycle()
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var ip by remember { mutableStateOf(settings.routerIp.ifEmpty { detectGateway(context) ?: "192.168.100.1" }) }
    var password by remember { mutableStateOf(settings.webPassword) }
    var passwordVisible by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf<String?>(null) }

    fun commitAutofill() {
        try {
            context.getSystemService(AutofillManager::class.java)?.commit()
        } catch (_: Exception) {
        }
    }

    fun saveAndFinish() {
        repo.updateSettings(
            settings.copy(routerIp = ip, webPassword = password, isSetupCompleted = true),
        )
        commitAutofill()
        repo.restartPolling()
        onFinished()
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text("+F FS050W 初期セットアップ", style = MaterialTheme.typography.headlineSmall)
        Text("ルーターに接続して電波監視を開始します。", style = MaterialTheme.typography.bodyMedium)

        AutofillCredentialFields(
            ip = ip,
            password = password,
            onIpChange = { ip = it },
            onPasswordChange = { password = it },
            passwordLabel = "Web管理パスワード (任意)",
            passwordVisible = passwordVisible,
            onDone = {
                commitAutofill()
                saveAndFinish()
            },
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

        Button(onClick = {
            scope.launch {
                message = if (repo.testConnection(ip, password)) "接続テスト成功" else "接続テスト失敗"
            }
            commitAutofill()
        }) { Text("接続テスト") }
        message?.let { Text(it) }
        Button(onClick = { saveAndFinish() }) { Text("設定を保存して開始") }
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
