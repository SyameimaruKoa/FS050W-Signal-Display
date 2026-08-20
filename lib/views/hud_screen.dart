import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../services/api_service.dart';
import '../models/connection_state.dart';
import '../utils/calc_frequency.dart';

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
        // 1-minute interval pixel shift to prevent OLED burn-in
        _pixelShiftTimer = Timer.periodic(const Duration(minutes: 1), (_) {
            setState(() {
                _offsetX = (_random.nextDouble() * 40) - 20;
                _offsetY = (_random.nextDouble() * 60) - 30;
            });
        });
    }

    @override
    void dispose() {
        _pixelShiftTimer?.cancel();
        WakelockPlus.disable();
        super.dispose();
    }

    @override
    Widget build(BuildContext context) {
        final apiService = context.watch<ApiService>();
        final signal = apiService.currentSignal;

        final mode = signal?.connectionMode ?? Fs050wConnectionMode.disconnected;
        final modeBadge = ConnectionModeHelper.getIconBadgeText(mode);
        final uiMode = ConnectionModeHelper.getUiModeText(mode, isSa: signal?.isSa ?? false);

        final lteRsrp = signal?.lteRsrp != null ? "${signal!.lteRsrp!.toStringAsFixed(1)} dBm" : "--";
        final lteBand = signal?.lteBand != null ? "B${signal!.lteBand}" : "--";
        final ltePci = signal?.ltePci != null ? "${signal!.ltePci}" : "--";

        final nrRsrp = signal?.nrRsrp != null ? "${signal!.nrRsrp!.toStringAsFixed(1)} dBm" : "--";
        final nrBand = signal?.nrBand != null ? "n${signal!.nrBand}" : "--";
        final nrPci = signal?.nrPci != null ? "${signal!.nrPci}" : "--";

        final battery = signal?.batteryPercent != null ? "${signal!.batteryPercent}%" : "--";
        final isCharging = signal?.isCharging ?? false;

        return Scaffold(
            backgroundColor: Colors.black, // #000000 OLED True Black
            body: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                    Navigator.of(context).pop();
                },
                child: Center(
                    child: Transform.translate(
                        offset: Offset(_offsetX, _offsetY),
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                                // Top Minimal Status
                                Text(
                                    "[ $modeBadge ] $uiMode",
                                    style: GoogleFonts.notoSansJp(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF558B8B),
                                    ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                    "🔋 $battery${isCharging ? ' ⚡' : ''}  |  ${signal?.operatorName ?? '--'}",
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF445555),
                                    ),
                                ),
                                const SizedBox(height: 36),

                                // 5G Display (if available)
                                if (mode == Fs050wConnectionMode.nr5g || mode == Fs050wConnectionMode.nr5gSub6) ...[
                                    Text(
                                        "5G ($nrBand  PCI $nrPci)",
                                        style: const TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF446666),
                                            fontWeight: FontWeight.w500,
                                        ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                        nrRsrp,
                                        style: GoogleFonts.notoSansMono(
                                            fontSize: 38,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF66AAAA),
                                        ),
                                    ),
                                    const SizedBox(height: 24),
                                ],

                                // 4G Display
                                if (!((signal?.isSa ?? false))) ...[
                                    Text(
                                        "4G ($lteBand  PCI $ltePci)",
                                        style: const TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF445566),
                                            fontWeight: FontWeight.w500,
                                        ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                        lteRsrp,
                                        style: GoogleFonts.notoSansMono(
                                            fontSize: 34,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF5588AA),
                                        ),
                                    ),
                                ],

                                const SizedBox(height: 48),
                                const Text(
                                    "タップして通常表示に戻る",
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF333333),
                                    ),
                                ),
                            ],
                        ),
                    ),
                ),
            ),
        );
    }
}
