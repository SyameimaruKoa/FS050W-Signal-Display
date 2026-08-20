import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
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
    Timer? _pixelShiftTimer;
    double _offsetX = 0.0;
    double _offsetY = 0.0;
    final Random _random = Random();

    @override
    void initState() {
        super.initState();
        WakelockPlus.enable();
        // Immersive sticky fullscreen (hides status bar and navigation buttons)
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

        // 1-minute interval pixel shift to prevent OLED burn-in
        _pixelShiftTimer = Timer.periodic(const Duration(minutes: 1), (_) {
            if (mounted) {
                setState(() {
                    _offsetX = (_random.nextDouble() * 30) - 15;
                    _offsetY = (_random.nextDouble() * 40) - 20;
                });
            }
        });
    }

    @override
    void dispose() {
        _pixelShiftTimer?.cancel();
        WakelockPlus.disable();
        // Restore standard system UI mode
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        super.dispose();
    }

    @override
    Widget build(BuildContext context) {
        final apiService = context.watch<ApiService>();
        final signal = apiService.currentSignal;

        final mode = signal?.connectionMode ?? Fs050wConnectionMode.disconnected;
        final modeBadge = ConnectionModeHelper.getIconBadgeText(mode);
        final uiMode = ConnectionModeHelper.getUiModeText(mode, isSa: signal?.isSa ?? false);

        final battery = signal?.batteryPercent != null ? "${signal!.batteryPercent}%" : "--";
        final isCharging = signal?.isCharging ?? false;

        return Scaffold(
            backgroundColor: Colors.black, // #000000 OLED True Black
            body: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(),
                child: SafeArea(
                    child: Center(
                        child: Transform.translate(
                            offset: Offset(_offsetX, _offsetY),
                            child: SingleChildScrollView(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                        // Top Bar
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
                                                        style: GoogleFonts.notoSansJp(
                                                            fontSize: 14,
                                                            fontWeight: FontWeight.bold,
                                                            color: const Color(0xFF00E5FF),
                                                        ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Text(
                                                        "🔋 $battery${isCharging ? '⚡' : ''}",
                                                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                        signal?.operatorName ?? "--",
                                                        style: const TextStyle(fontSize: 12, color: Colors.white54),
                                                    ),
                                                ],
                                            ),
                                        ),
                                        const SizedBox(height: 24),

                                        // 5G NR Section (if available)
                                        if (mode == Fs050wConnectionMode.nr5g || mode == Fs050wConnectionMode.nr5gSub6) ...[
                                            _buildMetricSection(
                                                title: "5G NR (${FrequencyCalculator.getNrBandName(signal?.nrBand)}  PCI: ${signal?.nrPci ?? '--'})",
                                                titleColor: const Color(0xFF00E5FF),
                                                rsrp: signal?.nrRsrp,
                                                rsrq: signal?.nrRsrq,
                                                sinr: signal?.nrSnr,
                                                sinrLabel: "SNR",
                                            ),
                                            const SizedBox(height: 20),
                                        ],

                                        // 4G LTE Section
                                        if (!(signal?.isSa ?? false)) ...[
                                            _buildMetricSection(
                                                title: "4G LTE (${FrequencyCalculator.getLteBandName(signal?.lteBand)}  PCI: ${signal?.ltePci ?? '--'})",
                                                titleColor: const Color(0xFF2196F3),
                                                rsrp: signal?.lteRsrp,
                                                rsrq: signal?.lteRsrq,
                                                sinr: signal?.lteSinr,
                                                sinrLabel: "SINR",
                                            ),
                                        ],

                                        const SizedBox(height: 32),
                                        const Text(
                                            "画面をタップして通常表示に戻る",
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF444444),
                                            ),
                                        ),
                                    ],
                                ),
                            ),
                        ),
                    ),
                ),
            ),
        );
    }

    Widget _buildMetricSection({
        required String title,
        required Color titleColor,
        required double? rsrp,
        required double? rsrq,
        required double? sinr,
        required String sinrLabel,
    }) {
        return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: titleColor.withOpacity(0.25)),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Text(
                        title,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: titleColor,
                        ),
                    ),
                    const Divider(color: Colors.white12, height: 14),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                            _buildSingleMetric("RSRP", rsrp, "dBm", ColorGauge.rateRsrp(rsrp)),
                            _buildSingleMetric("RSRQ", rsrq, "dB", ColorGauge.rateRsrq(rsrq)),
                            _buildSingleMetric(sinrLabel, sinr, "dB", ColorGauge.rateSinr(sinr)),
                        ],
                    ),
                ],
            ),
        );
    }

    Widget _buildSingleMetric(String label, double? value, String unit, SignalRatingLevel level) {
        final valStr = value != null ? value.toStringAsFixed(1) : "--";
        final color = ColorGauge.getColor(level);

        return Column(
            children: [
                Text(
                    label,
                    style: const TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                    valStr,
                    style: GoogleFonts.notoSansMono(
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
