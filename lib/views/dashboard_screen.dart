import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/pip_service.dart';
import '../models/signal_data.dart';
import '../models/connection_state.dart';
import '../utils/calc_frequency.dart';
import '../utils/color_gauge.dart';
import 'widgets/fs050w_app_bar.dart';
import 'widgets/cell_card.dart';
import 'widgets/log_viewer_dialog.dart';
import 'hud_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
    final VoidCallback? onNavigateToGraph;
    final VoidCallback? onNavigateToSettings;

    const DashboardScreen({
        super.key,
        this.onNavigateToGraph,
        this.onNavigateToSettings,
    });

    @override
    State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
    bool _isCellDetailsExpanded = false;

    @override
    Widget build(BuildContext context) {
        final apiService = context.watch<ApiService>();
        final signal = apiService.currentSignal;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Scaffold(
            appBar: const Fs050wAppBar(),
            body: RefreshIndicator(
                onRefresh: () async {
                    apiService.restartPolling();
                },
                child: ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                        _buildConnectionBanner(context, apiService, signal),
                        _buildRsrpOverviewCard(context, apiService, signal),
                        _buildCollapsibleDetailsSection(context, apiService, signal),
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

        final statusColor = isConnected ? const Color(0xFF00E676) : Colors.redAccent;
        final statusText = isConnected ? "接続中: ${apiService.settings.routerIp}" : "未接続";
        final operatorName = signal?.operatorName ?? "--";

        final mode = signal?.connectionMode ?? Fs050wConnectionMode.disconnected;
        final uiMode = ConnectionModeHelper.getUiModeText(
            mode,
            isSa: signal?.isSa ?? false,
            notation: apiService.settings.generationNotation,
        );

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
                            Text(
                                operatorName,
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                ),
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
                                        isConnecting ? "接続中..." : uiMode,
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

    Widget _buildRsrpOverviewCard(BuildContext context, ApiService apiService, SignalData? signal) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final notation = apiService.settings.generationNotation;
        final smooth = apiService.settings.smoothGaugeColor;
        final curve = apiService.settings.smoothGaugeCurve;
        final isAuthenticated = apiService.status == ConnectionStatus.authenticated;
        final isUnauthenticated = apiService.status == ConnectionStatus.unauthenticatedMode;
        final mode = signal?.connectionMode ?? Fs050wConnectionMode.disconnected;

        final is5gSub6 = mode == Fs050wConnectionMode.nr5gSub6;
        final is5gStandby = mode == Fs050wConnectionMode.nsaReady;
        final is4gOnly = mode == Fs050wConnectionMode.lte;

        final nrName = ConnectionModeHelper.getGenerationName(true, notation: notation);
        final lteName = ConnectionModeHelper.getGenerationName(false, notation: notation);

        final nrBandStr = (signal?.nrBand != null && signal!.nrBand! > 0) ? "n${signal!.nrBand}" : null;
        final lteBandStr = (signal?.lteBand != null && signal!.lteBand! > 0) ? "B${signal!.lteBand}" : null;

        return Card(
            elevation: 3,
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: const Color(0xFF00ADB5).withOpacity(0.4), width: 1.4),
            ),
            color: Theme.of(context).cardColor,
            child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Row(
                            children: [
                                const Icon(Icons.analytics_outlined, color: Color(0xFF00E5FF), size: 22),
                                const SizedBox(width: 8),
                                const Expanded(
                                    child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                            "電波強度 (RSRP)",
                                            style: TextStyle(
                                                fontFamilyFallback: ['Noto Sans JP', 'sans-serif'],
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                            ),
                                        ),
                                    ),
                                ),
                                Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                        color: isAuthenticated
                                            ? Colors.green.withOpacity(0.18)
                                            : (isUnauthenticated ? Colors.amber.withOpacity(0.18) : Colors.grey.withOpacity(0.18)),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                            color: isAuthenticated
                                                ? Colors.greenAccent.withOpacity(0.4)
                                                : (isUnauthenticated ? Colors.amberAccent.withOpacity(0.4) : Colors.grey),
                                            width: 0.8,
                                        ),
                                    ),
                                    child: Text(
                                        isAuthenticated ? "ログイン済" : (isUnauthenticated ? "未ログイン (RSRP基本)" : "待機中"),
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isAuthenticated ? Colors.greenAccent : (isUnauthenticated ? Colors.amberAccent : Colors.white70),
                                        ),
                                    ),
                                ),
                            ],
                        ),
                        const Divider(height: 16, thickness: 0.8),
                        // Dual RSRP Metric Panels
                        LayoutBuilder(
                            builder: (context, constraints) {
                                final isNarrow = constraints.maxWidth < 340;
                                final p5g = _buildRsrpOverviewPanel(
                                    context,
                                    title: is5gSub6 ? "$nrName+ (Sub6)" : nrName,
                                    bandStr: nrBandStr,
                                    rsrp: signal?.nrRsrp,
                                    is5g: true,
                                    isStandby: is5gStandby,
                                    isSingleMode: is4gOnly,
                                    smoothGaugeColor: smooth,
                                    smoothGaugeCurve: curve,
                                    accentColor: is5gSub6 ? const Color(0xFF00E5FF) : const Color(0xFF00ADB5),
                                );
                                final p4g = _buildRsrpOverviewPanel(
                                    context,
                                    title: lteName,
                                    bandStr: lteBandStr,
                                    rsrp: signal?.lteRsrp,
                                    is5g: false,
                                    isStandby: false,
                                    isSingleMode: signal?.isSa ?? false,
                                    smoothGaugeColor: smooth,
                                    smoothGaugeCurve: curve,
                                    accentColor: const Color(0xFF2196F3),
                                );

                                if (isNarrow) {
                                    return Column(
                                        children: [
                                            p5g,
                                            const SizedBox(height: 10),
                                            p4g,
                                        ],
                                    );
                                }
                                return Row(
                                    children: [
                                        Expanded(child: p5g),
                                        const SizedBox(width: 10),
                                        Expanded(child: p4g),
                                    ],
                                );
                            },
                        ),
                        const SizedBox(height: 10),
                        // Authentication / Handover footer banner
                        _buildRsrpSummaryFooter(context, apiService, signal),
                    ],
                ),
            ),
        );
    }

    Widget _buildRsrpOverviewPanel(
        BuildContext context, {
        required String title,
        required String? bandStr,
        required double? rsrp,
        required bool is5g,
        required bool isStandby,
        required bool isSingleMode,
        required bool smoothGaugeColor,
        required String smoothGaugeCurve,
        required Color accentColor,
    }) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final isValid = rsrp != null && !rsrp.isNaN && rsrp < 0;
        final level = isValid ? ColorGauge.rateRsrp(rsrp) : SignalRatingLevel.unknown;
        final color = isValid
            ? (smoothGaugeColor
                ? ColorGauge.getSmoothColor(((rsrp - ColorGauge.rsrpMin) / (ColorGauge.rsrpMax - ColorGauge.rsrpMin)).clamp(0.0, 1.0), curve: smoothGaugeCurve)
                : ColorGauge.getColor(level))
            : Colors.grey;

        final rawRatio = isValid ? ((rsrp - ColorGauge.rsrpMin) / (ColorGauge.rsrpMax - ColorGauge.rsrpMin)).clamp(0.0, 1.0) : 0.0;

        String mainValText;
        String statusLabel;

        if (isValid) {
            mainValText = "${rsrp.toStringAsFixed(1)} dBm";
            statusLabel = ColorGauge.getLabel(level);
        } else if (isStandby) {
            mainValText = "-- dBm";
            statusLabel = "NSA待機中";
        } else if (isSingleMode) {
            mainValText = "-- dBm";
            statusLabel = is5g ? "4G単独中" : "5G SA中";
        } else {
            mainValText = "-- dBm";
            statusLabel = "圏外 / 未接続";
        }

        final titleText = bandStr != null ? "$title ($bandStr)" : title;

        return Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.035) : Colors.black.withOpacity(0.025),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accentColor.withOpacity(0.3), width: 1.0),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                            Flexible(
                                child: Text(
                                    titleText,
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: accentColor,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                ),
                            ),
                            Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                    color: color.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: color.withOpacity(0.4), width: 0.8),
                                ),
                                child: Text(
                                    statusLabel,
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: color,
                                    ),
                                ),
                            ),
                        ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                        mainValText,
                        style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isValid ? (isDark ? Colors.white : Colors.black87) : (isDark ? Colors.white38 : Colors.black38),
                        ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                            value: rawRatio,
                            minHeight: 5,
                            backgroundColor: isDark ? Colors.white12 : Colors.black12,
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                    ),
                ],
            ),
        );
    }

    Widget _buildRsrpSummaryFooter(BuildContext context, ApiService apiService, SignalData? signal) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final isAuth = apiService.status == ConnectionStatus.authenticated;
        final handover = signal?.handoverDescription;

        if (isAuth && handover != null && handover.isNotEmpty) {
            return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.amber.withOpacity(0.3), width: 0.8),
                ),
                child: Row(
                    children: [
                        const Icon(Icons.swap_horiz, size: 16, color: Colors.amberAccent),
                        const SizedBox(width: 6),
                        Expanded(
                            child: Text(
                                "ハンドオーバー検知: $handover",
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amberAccent),
                            ),
                        ),
                    ],
                ),
            );
        }

        if (isAuth) {
            return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                    children: [
                        const Icon(Icons.check_circle_outline, size: 14, color: Colors.greenAccent),
                        const SizedBox(width: 6),
                        Expanded(
                            child: Text(
                                "フル情報モード: セル詳細・ハンドオーバー常時監視中",
                                style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black54),
                            ),
                        ),
                    ],
                ),
            );
        }

        return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
                borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
                children: [
                    const Icon(Icons.info_outline, size: 14, color: Colors.amberAccent),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(
                            "未ログイン状態でもRSRPは常時監視中。ログインするとハンドオーバー検知と詳細品質が有効化されます。",
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black54),
                        ),
                    ),
                ],
            ),
        );
    }

    Widget _buildCollapsibleDetailsSection(BuildContext context, ApiService apiService, SignalData? signal) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final isAuthenticated = apiService.status == ConnectionStatus.authenticated;

        // 未ログイン時は詳細セル情報を非表示
        if (!isAuthenticated) {
            return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: isDark ? Colors.white10 : Colors.black12,
                            width: 0.8,
                        ),
                    ),
                    child: Row(
                        children: [
                            Icon(Icons.lock_outline, size: 16, color: isDark ? Colors.white38 : Colors.black38),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(
                                    "詳細セル情報はログイン時のみ表示されます",
                                    style: TextStyle(
                                        fontFamilyFallback: const ['Noto Sans JP', 'sans-serif'],
                                        fontSize: 12,
                                        color: isDark ? Colors.white38 : Colors.black38,
                                    ),
                                ),
                            ),
                        ],
                    ),
                ),
            );
        }

        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
                Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.035) : Colors.black.withOpacity(0.025),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: isDark ? Colors.white10 : Colors.black12,
                            width: 0.8,
                        ),
                    ),
                    child: InkWell(
                        onTap: () {
                            setState(() {
                                _isCellDetailsExpanded = !_isCellDetailsExpanded;
                            });
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                    Expanded(
                                        child: Row(
                                            children: [
                                                Icon(
                                                    _isCellDetailsExpanded ? Icons.tune : Icons.tune_outlined,
                                                    size: 18,
                                                    color: const Color(0xFF00ADB5),
                                                ),
                                                const SizedBox(width: 8),
                                                Flexible(
                                                    child: Text(
                                                        "詳細セル情報",
                                                        style: TextStyle(
                                                            fontSize: 12.5,
                                                            fontWeight: FontWeight.w600,
                                                            color: isDark ? Colors.white70 : Colors.black87,
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                    ),
                                                ),
                                            ],
                                        ),
                                    ),
                                    const SizedBox(width: 6),
                                    Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                            Text(
                                                _isCellDetailsExpanded ? "閉じる" : "展開",
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF00ADB5),
                                                ),
                                            ),
                                            const SizedBox(width: 2),
                                            Icon(
                                                _isCellDetailsExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                                size: 18,
                                                color: const Color(0xFF00ADB5),
                                            ),
                                        ],
                                    ),
                                ],
                            ),
                        ),
                    ),
                ),
                if (_isCellDetailsExpanded) ...[
                    CellCard.build5gNrCard(
                        context,
                        signal,
                        notation: apiService.settings.generationNotation,
                        smoothGaugeColor: apiService.settings.smoothGaugeColor,
                        smoothGaugeCurve: apiService.settings.smoothGaugeCurve,
                    ),
                    CellCard.build4gLteCard(
                        context,
                        signal,
                        notation: apiService.settings.generationNotation,
                        smoothGaugeColor: apiService.settings.smoothGaugeColor,
                        smoothGaugeCurve: apiService.settings.smoothGaugeCurve,
                    ),
                ],
            ],
        );
    }
}
