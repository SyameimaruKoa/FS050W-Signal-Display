package com.syameimarukoa.fs050w_signal_display.ui.setup

import android.content.Context
import android.net.wifi.WifiManager
import android.view.autofill.AutofillManager
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.syameimarukoa.fs050w_signal_display.R
import com.syameimarukoa.fs050w_signal_display.ui.LocalRepository
import com.syameimarukoa.fs050w_signal_display.ui.components.AutofillCredentialFields
import com.syameimarukoa.fs050w_signal_display.ui.components.SignalColors
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
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 24.dp, vertical = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Spacer(Modifier.height(24.dp))

        // アプリアイコン
        Box(
            modifier = Modifier
                .size(72.dp)
                .background(SignalColors.cyan, RoundedCornerShape(20.dp)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                painterResource(R.drawable.ic_dashboard),
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier.size(44.dp),
            )
        }

        Spacer(Modifier.height(16.dp))

        Text(
            "+F FS050W Signal Display",
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onSurface,
            textAlign = TextAlign.Center,
        )
        Text(
            "ルーターに接続し、電波強度の監視を開始します",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
        )

        Spacer(Modifier.height(20.dp))

        // 検出カード
        if (ip.isNotBlank()) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(
                        Color(0xFF1B5E20).copy(alpha = 0.35f),
                        RoundedCornerShape(10.dp),
                    )
                    .padding(14.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Icon(
                    painterResource(R.drawable.ic_dashboard),
                    contentDescription = null,
                    tint = SignalColors.green,
                    modifier = Modifier.size(28.dp),
                )
                Text(
                    "🎉 +F FS050W ($ip) を検出しました！",
                    color = SignalColors.green,
                    fontWeight = FontWeight.Bold,
                    fontSize = 14.sp,
                )
            }
        }

        Spacer(Modifier.height(20.dp))

        // 接続設定カード
        androidx.compose.material3.Card(
            modifier = Modifier.fillMaxWidth(),
            colors = androidx.compose.material3.CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.surfaceContainerLow,
            ),
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text(
                    "接続設定",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                )
                Spacer(Modifier.height(12.dp))
                AutofillCredentialFields(
                    ip = ip,
                    password = password,
                    onIpChange = { ip = it },
                    onPasswordChange = { password = it },
                    passwordLabel = "Web管理パスワード (初期: admin)",
                    passwordVisible = passwordVisible,
                    onDone = {
                        commitAutofill()
                        saveAndFinish()
                    },
                )
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.End,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        "パスワードを表示",
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    IconButton(onClick = { passwordVisible = !passwordVisible }) {
                        Icon(
                            painterResource(if (passwordVisible) R.drawable.ic_visibility_off else R.drawable.ic_visibility),
                            contentDescription = if (passwordVisible) "パスワードを隠す" else "パスワードを表示",
                        )
                    }
                }
                Spacer(Modifier.height(8.dp))
                Button(
                    onClick = {
                        scope.launch {
                            message = if (repo.testConnection(ip, password)) "接続テスト成功" else "接続テスト失敗"
                        }
                        commitAutofill()
                    },
                    modifier = Modifier.fillMaxWidth(),
                ) { Text("接続テスト") }
                message?.let {
                    Spacer(Modifier.height(6.dp))
                    Text(it, color = SignalColors.green, fontSize = 13.sp)
                }
            }
        }

        Spacer(Modifier.height(16.dp))

        Button(
            onClick = { saveAndFinish() },
            modifier = Modifier
                .fillMaxWidth()
                .height(52.dp),
            colors = ButtonDefaults.buttonColors(containerColor = SignalColors.cyan),
        ) { Text("設定を保存して開始", fontWeight = FontWeight.Bold) }
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
