import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../services/pip_service.dart';
import '../models/signal_data.dart';
import '../models/connection_state.dart';
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
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Scaffold(
            appBar: AppBar(
                title: Text(
                    "📶 FS050W Monitor",
                    style: GoogleFonts.notoSansJp(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                actions: [
                    IconButton(
                        icon: const Icon(Icons.picture_in_picture_alt, color: Color(0xFF00E5FF)),
                        tooltip: "PiP (小窓表示) 起動",
                        onPressed: () async {
                            final success = await PipService.enterPipMode(apiService.settings.pipAspectRatio);
                            if (!success && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("PiPモードの起動に失敗しました (端末の設定をご確認ください)")),
                                );
                            }
                        },
                    ),
                    IconButton(
                        icon: Icon(Icons.assignment_outlined, color: isDark ? Colors.white70 : Colors.black87),
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
                        icon: Icon(Icons.settings, color: isDark ? Colors.white70 : Colors.black87),
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
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final isConnected = apiService.status == ConnectionStatus.authenticated ||
            apiService.status == ConnectionStatus.unauthenticatedMode;
        final isConnecting = apiService.status == ConnectionStatus.connecting;

        final statusColor = isConnected
            ? Colors.greenAccent
            : (isConnecting ? Colors.orangeAccent : Colors.redAccent);

        final statusText = isConnected
            ? "🟢 接続中: ${apiService.settings.routerIp}"
            : (isConnecting ? "🟡 接続試行中... (${apiService.settings.routerIp})" : "🔴 未接続 / エラー");

        final operatorName = signal?.operatorName ?? "--";
        final hasBattery = signal?.batteryPercent != null;
        final batteryText = hasBattery
            ? "🔋 ${signal!.batteryPercent}%${signal.isCharging ? ' ⚡' : ''}"
            : null;

        final mode = signal?.connectionMode ?? Fs050wConnectionMode.disconnected;
        final modeBadge = isConnecting ? "接続中..." : ConnectionModeHelper.getIconBadgeText(mode);
        final uiMode = ConnectionModeHelper.getUiModeText(mode, isSa: signal?.isSa ?? false);

        return Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
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
                                            color: isDark ? statusColor : (isConnected ? const Color(0xFF2E7D32) : Colors.red.shade700),
                                        ),
                                    ),
                                ],
                            ),
                            Row(
                                children: [
                                    Text(
                                        operatorName,
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white : Colors.black87,
                                        ),
                                    ),
                                    if (batteryText != null) ...[
                                        const SizedBox(width: 8),
                                        Text(
                                            batteryText,
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: isDark ? Colors.white70 : Colors.black54,
                                            ),
                                        ),
                                    ],
                                ],
                            ),
                        ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                            color: isDark ? Colors.blueGrey.withOpacity(0.2) : Colors.blueGrey.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                            children: [
                                Text(
                                    "ステータス: ",
                                    style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
                                ),
                                Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                        color: isConnecting
                                            ? Colors.amber.withOpacity(0.2)
                                            : (isDark ? Colors.cyanAccent.withOpacity(0.25) : const Color(0xFF00ADB5).withOpacity(0.15)),
                                        borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                        isConnecting ? "[ 接続中... ]" : "[ $modeBadge ] $uiMode",
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: isConnecting
                                                ? Colors.amberAccent
                                                : (isDark ? Colors.cyanAccent : const Color(0xFF007A78)),
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
                            style: const TextStyle(fontSize: 12, color: Colors.orangeAccent),
                        ),
                    ],
                ],
            ),
        );
    }

    Widget _buildNavigationActionButtons(BuildContext context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
                children: [
                    Expanded(
                        child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                backgroundColor: isDark ? Colors.blueGrey.shade800 : Colors.blueGrey.shade100,
                                elevation: isDark ? 1 : 0,
                            ),
                            icon: Icon(Icons.show_chart, color: isDark ? Colors.cyanAccent : const Color(0xFF007A78)),
                            label: Text(
                                "同期グラフへ",
                                style: TextStyle(
                                    color: isDark ? Colors.white : Colors.black87,
                                    fontWeight: FontWeight.bold,
                                ),
                            ),
                            onPressed: onNavigateToGraph,
                        ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                        child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                backgroundColor: isDark ? Colors.blueGrey.shade800 : Colors.blueGrey.shade100,
                                elevation: isDark ? 1 : 0,
                            ),
                            icon: const Icon(Icons.settings, color: Colors.orangeAccent),
                            label: Text(
                                "設定へ",
                                style: TextStyle(
                                    color: isDark ? Colors.white : Colors.black87,
                                    fontWeight: FontWeight.bold,
                                ),
                            ),
                            onPressed: onNavigateToSettings,
                        ),
                    ),
                ],
            ),
        );
    }
}
