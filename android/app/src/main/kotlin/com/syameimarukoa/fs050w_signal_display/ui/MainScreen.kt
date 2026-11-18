package com.syameimarukoa.fs050w_signal_display.ui

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.syameimarukoa.fs050w_signal_display.R
import com.syameimarukoa.fs050w_signal_display.domain.model.AppNavigationStyle
import com.syameimarukoa.fs050w_signal_display.ui.dashboard.DashboardScreen
import com.syameimarukoa.fs050w_signal_display.ui.graph.GraphScreen
import com.syameimarukoa.fs050w_signal_display.ui.hud.HudScreen
import com.syameimarukoa.fs050w_signal_display.ui.pip.PipScreen
import com.syameimarukoa.fs050w_signal_display.ui.settings.SettingsScreen
import com.syameimarukoa.fs050w_signal_display.ui.setup.SetupWizardScreen

@Composable
fun MainScreen(
    onEnterPip: () -> Unit,
    onOverlayChanged: (Boolean) -> Unit,
) {
    val repo = LocalRepository.current
    val settings by repo.settings.collectAsStateWithLifecycle()
    val isPip by repo.isPipMode.collectAsStateWithLifecycle()
    var selected by remember { mutableIntStateOf(0) }
    var showHud by remember { mutableStateOf(false) }

    // Flutter 版 MainNavigationShell と同じ: 設定完了後にポーリングを開始する。
    // Activity の onResume はセットアップ表示中に一度きりなので、ここで確実に開始する。
    LaunchedEffect(settings.routerIp.isEmpty()) {
        if (settings.routerIp.isNotEmpty()) {
            repo.startPolling()
        }
    }

    when {
        settings.routerIp.isEmpty() -> SetupWizardScreen(onFinished = { selected = 0 })
        isPip -> PipScreen()
        showHud -> HudScreen(onClose = { showHud = false })
        else -> {
            val screens: List<@Composable () -> Unit> = listOf(
                {
                    DashboardScreen(
                        onEnterPip = onEnterPip,
                        onOpenHud = { showHud = true },
                        onOpenLogs = { selected = 2 },
                    )
                },
                { GraphScreen() },
                { SettingsScreen(onOverlayChanged = onOverlayChanged) },
            )
            if (settings.navigationStyle == AppNavigationStyle.BOTTOM_NAV) {
                Scaffold(
                    bottomBar = {
                        NavigationBar {
                            NavigationBarItem(
                                selected = selected == 0,
                                onClick = { selected = 0 },
                                icon = { Icon(painterResource(R.drawable.ic_dashboard), null) },
                                label = { Text("ダッシュボード") },
                            )
                            NavigationBarItem(
                                selected = selected == 1,
                                onClick = { selected = 1 },
                                icon = { Icon(painterResource(R.drawable.ic_graph), null) },
                                label = { Text("同期グラフ") },
                            )
                            NavigationBarItem(
                                selected = selected == 2,
                                onClick = { selected = 2 },
                                icon = { Icon(painterResource(R.drawable.ic_settings), null) },
                                label = { Text("設定") },
                            )
                        }
                    },
                ) { padding ->
                    Column(modifier = Modifier.fillMaxSize().padding(padding)) {
                        screens[selected]()
                    }
                }
            } else {
                Column(modifier = Modifier.fillMaxSize()) {
                    RowOfPageButtons(selected = selected, onSelect = { selected = it })
                    Column(modifier = Modifier.fillMaxSize().weight(1f)) {
                        screens[selected]()
                    }
                }
            }
        }
    }
}

@Composable
private fun RowOfPageButtons(selected: Int, onSelect: (Int) -> Unit) {
    androidx.compose.foundation.layout.Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(8.dp),
    ) {
        listOf("ダッシュボード", "同期グラフ", "設定").forEachIndexed { index, label ->
            Button(
                onClick = { onSelect(index) },
                modifier = Modifier
                    .weight(1f)
                    .padding(horizontal = 4.dp),
            ) { Text(label) }
        }
    }
}
