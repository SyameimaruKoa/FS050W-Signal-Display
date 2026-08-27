import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../services/api_service.dart';
import '../models/connection_state.dart';
import '../utils/calc_frequency.dart';
import '../utils/color_gauge.dart';

class HudScreen extends StatefulWidget {
    const HudScreen({super.key});

    @override
    State<HudScreen> createState() => _HudScreenState();
}

class _HudScreenState extends State<HudScreen> {
    @override
    void initState() {
        super.initState();
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        WakelockPlus.enable();
    }

    @override
    void dispose() {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        super.dispose();
    }

    @override
    Widget build(BuildContext context) {
        final apiService = context.watch<ApiService>();
        final signal = apiService.currentSignal;
        final settings = apiService.settings;
        final mode = signal?.connectionMode ?? Fs050wConnectionMode.disconnected;
        final notation = settings.generationNotation;
        final modeBadge = ConnectionModeHelper.getIconBadgeText(mode, notation: notation);
        final uiMode = ConnectionModeHelper.getUiModeText(mode, isSa: signal?.isSa ?? false, notation: notation);

        final isCharging = signal?.isCharging ?? false;

        return Scaffold(
            backgroundColor: Colors.black,
            body: Stack(
                children: [
                    SafeArea(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                                // Top status bar
                                Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                            IconButton(
                                                icon: const Icon(Icons.close, color: Colors.white70),
                                                onPressed: () => Navigator.of(context).pop(),
                                            ),
                                            Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                                decoration: BoxDecoration(
                                                    color: Colors.white.withOpacity(0.05),
                                                    borderRadius: BorderRadius.circular(20),
                                                ),
                                                child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                        Text(
                                                            "[ $modeBadge ] $uiMode",
                                                            style: const TextStyle(
                                                                fontFamilyFallback: ['Noto Sans JP', 'sans-serif'],
                                                                fontSize: 14,
                                                                fontWeight: FontWeight.bold,
                                                                color: Color(0xFF00E5FF),
                                                            ),
                                                        ),
                                                        if (signal?.batteryPercent != null) ...[
                                                            const SizedBox(width: 12),
                                                            Text(
                                                                "🔋 ${signal!.batteryPercent}%${isCharging ? '⚡' : ''}",
                                                                style: const TextStyle(fontSize: 12, color: Colors.white70),
                                                            ),
                                                        ],
                                                    ],
                                                ),
                                            ),
                                            Text(
                                                signal?.operatorName ?? "--",
                                                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                                            ),
                                        ],
                                    ),
                                ),

                                // Main signal gauges
                                Expanded(
                                    child: Center(
                                        child: LayoutBuilder(
                                            builder: (context, constraints) {
                                                final isPortrait = constraints.maxHeight > constraints.maxWidth;
                                                final children = [
                                                    // 5G Gauges
                                                    _buildHudPanel(
                                                        context,
                                                        title: ConnectionModeHelper.getGenerationName(true, notation: notation),
                                                        bandStr: (signal?.nrBand != null && signal!.nrBand! > 0) ? "n${signal!.nrBand}" : "--",
                                                        pciStr: (signal?.nrPci != null && signal!.nrPci! > 0) ? "${signal!.nrPci}" : "--",
                                                        rsrp: signal?.nrRsrp,
                                                        rsrq: signal?.nrRsrq,
                                                        sinr: signal?.nrSnr,
                                                        accentColor: const Color(0xFF00ADB5),
                                                        width: isPortrait ? constraints.maxWidth * 0.85 : (constraints.maxWidth - 48) / 2,
                                                    ),
                                                    SizedBox(height: isPortrait ? 12 : 0, width: isPortrait ? 0 : 16),
                                                    // 4G Gauges
                                                    _buildHudPanel(
                                                        context,
                                                        title: ConnectionModeHelper.getGenerationName(false, notation: notation),
                                                        bandStr: (signal?.lteBand != null && signal!.lteBand! > 0) ? "B${signal!.lteBand}" : "--",
                                                        pciStr: (signal?.ltePci != null && signal!.ltePci! > 0) ? "${signal!.ltePci}" : "--",
                                                        rsrp: signal?.lteRsrp,
                                                        rsrq: signal?.lteRsrq,
                                                        sinr: signal?.lteSinr,
                                                        accentColor: const Color(0xFF2196F3),
                                                        width: isPortrait ? constraints.maxWidth * 0.85 : (constraints.maxWidth - 48) / 2,
                                                    ),
                                                ];

                                                return SingleChildScrollView(
                                                    child: Padding(
                                                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                                                        child: isPortrait
                                                            ? Column(
                                                                mainAxisSize: MainAxisSize.min,
                                                                mainAxisAlignment: MainAxisAlignment.center,
                                                                children: children,
                                                            )
                                                            : Row(
                                                                mainAxisSize: MainAxisSize.min,
                                                                mainAxisAlignment: MainAxisAlignment.center,
                                                                children: children,
                                                            ),
                                                    ),
                                                );
                                            },
                                        ),
                                    ),
                                ),
                            ],
                        ),
                    ),
                ],
            ),
        );
    }

    Widget _buildHudPanel(
        BuildContext context, {
        required String title,
        required String bandStr,
        required String pciStr,
        required double? rsrp,
        required double? rsrq,
        required double? sinr,
        required Color accentColor,
        required double width,
    }) {
        return Container(
            width: width,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accentColor.withOpacity(0.25), width: 1.0),
            ),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                            Text(
                                "$title ($bandStr)",
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: accentColor,
                                ),
                            ),
                            Text(
                                "PCI: $pciStr",
                                style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    color: Colors.white60,
                                ),
                            ),
                        ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                            _buildHudMetric("RSRP", rsrp, "dBm", ColorGauge.getColor(ColorGauge.rateRsrp(rsrp))),
                            _buildHudMetric("RSRQ", rsrq, "dB", ColorGauge.getColor(ColorGauge.rateRsrq(rsrq))),
                            _buildHudMetric("SINR", sinr, "dB", ColorGauge.getColor(ColorGauge.rateSinr(sinr))),
                        ],
                    ),
                ],
            ),
        );
    }

    Widget _buildHudMetric(String label, double? val, String unit, Color color) {
        final valStr = val != null ? val.toStringAsFixed(1) : "--";
        return Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
                Text(
                    label,
                    style: const TextStyle(fontSize: 10, color: Colors.white54, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                    valStr,
                    style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color,
                    ),
                ),
                Text(
                    unit,
                    style: const TextStyle(fontSize: 9, color: Colors.white38),
                ),
            ],
        );
    }
}
