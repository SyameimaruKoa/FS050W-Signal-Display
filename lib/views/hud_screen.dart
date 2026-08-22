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
                                    child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Row(
                                            children: [
                                                // 5G Gauges
                                                Expanded(
                                                    child: _buildHudPanel(
                                                        context,
                                                        title: ConnectionModeHelper.getGenerationName(true, notation: notation),
                                                        bandStr: signal?.nrBand != null ? "n${signal!.nrBand}" : "--",
                                                        pciStr: signal?.nrPci != null ? "${signal!.nrPci}" : "--",
                                                        rsrp: signal?.nrRsrp,
                                                        rsrq: signal?.nrRsrq,
                                                        sinr: signal?.nrSnr,
                                                        accentColor: const Color(0xFF00ADB5),
                                                    ),
                                                ),
                                                const SizedBox(width: 16),
                                                // 4G Gauges
                                                Expanded(
                                                    child: _buildHudPanel(
                                                        context,
                                                        title: ConnectionModeHelper.getGenerationName(false, notation: notation),
                                                        bandStr: signal?.lteBand != null ? "B${signal!.lteBand}" : "--",
                                                        pciStr: signal?.ltePci != null ? "${signal!.ltePci}" : "--",
                                                        rsrp: signal?.lteRsrp,
                                                        rsrq: signal?.lteRsrq,
                                                        sinr: signal?.lteSinr,
                                                        accentColor: const Color(0xFF2196F3),
                                                    ),
                                                ),
                                            ],
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
    }) {
        return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accentColor.withOpacity(0.4), width: 1.5),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                            Text(
                                "$title ($bandStr)",
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: accentColor,
                                ),
                            ),
                            Text(
                                "PCI: $pciStr",
                                style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 14,
                                    color: Colors.white70,
                                ),
                            ),
                        ],
                    ),
                    const Divider(color: Colors.white12, height: 24),
                    Expanded(
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                                _buildHudMetric("RSRP", rsrp, "dBm", ColorGauge.getColor(ColorGauge.rateRsrp(rsrp))),
                                _buildHudMetric("RSRQ", rsrq, "dB", ColorGauge.getColor(ColorGauge.rateRsrq(rsrq))),
                                _buildHudMetric("SINR", sinr, "dB", ColorGauge.getColor(ColorGauge.rateSinr(sinr))),
                            ],
                        ),
                    ),
                ],
            ),
        );
    }

    Widget _buildHudMetric(String label, double? val, String unit, Color color) {
        final valStr = val != null ? val.toStringAsFixed(1) : "--";
        return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
                Text(
                    label,
                    style: const TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                    valStr,
                    style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: color,
                    ),
                ),
                Text(
                    unit,
                    style: const TextStyle(fontSize: 10, color: Colors.white38),
                ),
            ],
        );
    }
}
