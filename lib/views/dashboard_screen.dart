import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/app_settings.dart';
import '../services/api_service.dart';
import '../models/signal_data.dart';
import '../models/connection_state.dart';
import '../utils/calc_frequency.dart';
import 'widgets/cell_card.dart';
import 'widgets/log_viewer_dialog.dart';
import 'hud_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatelessWidget {
    final VoidCallback? onNavigateToGraph;
    final VoidCallback? onNavigateToSettings;

    const DashboardScreen({
        super.key,
        this.onNavigateToGraph,
        this.onNavigateToSettings,
    });

    @override
    Widget build(BuildContext context) {
        final apiService = context.watch<ApiService>();
        final signal = apiService.currentSignal;
        final status = apiService.status;
        final isConnecting = status == ConnectionStatus.connecting;

        return Scaffold(
            appBar: AppBar(
                title: Text(
                    "📶 FS050W Monitor",
                    style: GoogleFonts.notoSansJp(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                actions: [
                    IconButton(
                        icon: const Icon(Icons.assignment_outlined, color: Colors.white70),
                        tooltip: "診断ログを表示",
                        onPressed: () => LogViewerDialog.show(context),
                    ),
                    IconButton(
                        icon: const Icon(Icons.bedtime, color: Colors.amberAccent),
                        tooltip: "HUD / 有機EL 常時表示モード",
                        onPressed: () {
                            Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const HudScreen()),
                            );
                        },
                    ),
                    IconButton(
                        icon: const Icon(Icons.settings, color: Colors.white70),
                        tooltip: "設定",
                        onPressed: onNavigateToSettings ?? () {
                            Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const SettingsScreen()),
                            );
                        },
                    ),
                ],
            ),
            body: RefreshIndicator(
                onRefresh: () async {
                    apiService.restartPolling();
                },
                child: ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                        _buildConnectionBanner(context, apiService, signal),
                        CellCard.build5gNrCard(context, signal),
                        CellCard.build4gLteCard(context, signal),
                        const SizedBox(height: 8),
                        _buildNavigationActionButtons(context),
                    ],
                ),
            ),
        );
    }

    Widget _buildConnectionBanner(BuildContext context, ApiService apiService, SignalData? signal) {
        final isConnected = apiService.status == ConnectionStatus.authenticated ||
            apiService.status == ConnectionStatus.unauthenticatedMode;
        final statusColor = isConnected ? Colors.greenAccent : (apiService.status == ConnectionStatus.connecting ? Colors.orangeAccent : Colors.redAccent);
        final statusText = isConnected
            ? "🟢 接続中: ${apiService.settings.routerIp}"
            : (apiService.status == ConnectionStatus.connecting ? "🟡 接続中..." : "🔴 未接続 / エラー");

        final operatorName = signal?.operatorName ?? "--";
        final battery = signal?.batteryPercent != null
            ? "🔋 ${signal!.batteryPercent}%${signal.isCharging ? ' ⚡' : ''}"
            : "🔋 --%";

        final mode = signal?.connectionMode ?? Fs050wConnectionMode.disconnected;
        final modeBadge = ConnectionModeHelper.getIconBadgeText(mode);
        final uiMode = ConnectionModeHelper.getUiModeText(mode, isSa: signal?.isSa ?? false);

        return Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                            Row(
                                children: [
                                    Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                            color: statusColor,
                                            shape: BoxShape.circle,
                                        ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                        statusText,
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: statusColor,
                                        ),
                                    ),
                                ],
                            ),
                            Row(
                                children: [
                                    Text(
                                        operatorName,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                        ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                        battery,
                                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                                    ),
                                ],
                            ),
                        ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                            color: Colors.blueGrey.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                            children: [
                                const Text(
                                    "ステータス: ",
                                    style: TextStyle(fontSize: 13, color: Colors.white70),
                                ),
                                Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                        color: Colors.cyanAccent.withOpacity(0.25),
                                        borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                        "[ $modeBadge ] $uiMode",
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.cyanAccent,
                                        ),
                                    ),
                                ),
                            ],
                        ),
                    ),
                    if (apiService.errorMessage != null && !isConnected) ...[
                        const SizedBox(height: 6),
                        Text(
                            apiService.errorMessage!,
                            style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                        ),
                    ],
                ],
            ),
        );
    }

    Widget _buildNavigationActionButtons(BuildContext context) {
        return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
                children: [
                    Expanded(
                        child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                backgroundColor: Colors.blueGrey.shade800,
                            ),
                            icon: const Icon(Icons.show_chart, color: Colors.cyanAccent),
                            label: const Text("同期グラフへ", style: TextStyle(color: Colors.white)),
                            onPressed: onNavigateToGraph,
                        ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                        child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                backgroundColor: Colors.blueGrey.shade800,
                            ),
                            icon: const Icon(Icons.settings, color: Colors.orangeAccent),
                            label: const Text("設定へ", style: TextStyle(color: Colors.white)),
                            onPressed: onNavigateToSettings,
                        ),
                    ),
                ],
            ),
        );
    }
}
