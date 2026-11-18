package com.syameimarukoa.fs050w_signal_display.ui.components

import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.res.painterResource
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.syameimarukoa.fs050w_signal_display.R
import com.syameimarukoa.fs050w_signal_display.ui.LocalRepository

/** Flutter 版 Fs050wAppBar と同じ共通トップバー（3 画面で共有）。 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun Fs050wTopAppBar(
    onEnterPip: () -> Unit,
    onOpenLogs: () -> Unit,
    onOpenHud: () -> Unit,
    onOpenDetail: () -> Unit,
) {
    val repo = LocalRepository.current
    val signal by repo.currentSignal.collectAsStateWithLifecycle()
    val settings by repo.settings.collectAsStateWithLifecycle()
    val isConnecting by repo.isConnecting.collectAsStateWithLifecycle()

    TopAppBar(
        title = {
            StatusHeader(
                signal = signal,
                notation = settings.generationNotation,
                isConnecting = isConnecting,
                onOpenDetail = onOpenDetail,
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
}
