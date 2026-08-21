import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/signal_data.dart';
import '../models/connection_state.dart';
import '../utils/calc_frequency.dart';
import 'widgets/intensity_bar_metric.dart';

class PipScreen extends StatelessWidget {
    const PipScreen({super.key});

    @override
    Widget build(BuildContext context) {
        final apiService = context.watch<ApiService>();
        final signal = apiService.currentSignal;
        final settings = apiService.settings;
        final isConnecting = apiService.isConnecting;
        final aspectRatioStr = settings.pipAspectRatio;

        return Scaffold(
            backgroundColor: Colors.black,
            body: SafeArea(
                child: Container(
                    color: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                    child: Column(
                        children: [
                            _buildHeader(context, apiService, signal, isConnecting),
                            Expanded(
                                child: _buildResponsiveContent(context, signal, aspectRatioStr),
                            ),
                        ],
                    ),
                ),
            ),
        );
    }

    Widget _buildHeader(
        BuildContext context,
        ApiService apiService,
        SignalData? signal,
        bool isConnecting,
    ) {
        final mode = signal?.connectionMode ?? Fs050wConnectionMode.disconnected;
        final modeBadge = ConnectionModeHelper.getIconBadgeText(mode);
        final opName = signal?.operatorName ?? "--";
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Container(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(4.0),
            ),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                    Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.0),
                        decoration: BoxDecoration(
                            color: isConnecting ? Colors.amber.withOpacity(0.2) : const Color(0xFF00E5FF).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(3.0),
                        ),
                        child: Text(
                            isConnecting ? "[ 接続中... ]" : "[ $modeBadge ]",
                            style: GoogleFonts.notoSansJp(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: isConnecting ? Colors.amberAccent : const Color(0xFF00E5FF),
                            ),
                        ),
                    ),
                    Text(
                        opName,
                        style: GoogleFonts.notoSansJp(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white70,
                        ),
                    ),
                ],
            ),
        );
    }

    Widget _buildResponsiveContent(
        BuildContext context,
        SignalData? signal,
        String aspectRatioStr,
    ) {
        switch (aspectRatioStr) {
            case '16:9':
            case '4:3':
            case '21:9':
                // Horizontal 2-Column Layout
                return Row(
                    children: [
                        Expanded(child: _build5gSection(signal, isHorizontal: true)),
                        const SizedBox(width: 4.0),
                        Expanded(child: _build4gSection(signal, isHorizontal: true)),
                    ],
                );
            case '9:16':
            case '3:4':
            case '9:21':
                // Vertical 2-Row Layout
                return Column(
                    children: [
                        Expanded(child: _build5gSection(signal, isHorizontal: false)),
                        const SizedBox(height: 2.0),
                        Expanded(child: _build4gSection(signal, isHorizontal: false)),
                    ],
                );
            case '1:1':
            default:
                // 2x2 Grid Layout
                return Row(
                    children: [
                        Expanded(
                            child: Column(
                                children: [
                                    Expanded(child: _build5gSection(signal, isHorizontal: false)),
                                ],
                            ),
                        ),
                        const SizedBox(width: 4.0),
                        Expanded(
                            child: Column(
                                children: [
                                    Expanded(child: _build4gSection(signal, isHorizontal: false)),
                                ],
                            ),
                        ),
                    ],
                );
        }
    }

    Widget _build5gSection(SignalData? signal, {required bool isHorizontal}) {
        final isSub6 = signal?.connectionMode == Fs050wConnectionMode.nr5gSub6;
        final titlePrefix = isSub6 ? "5G+" : "5G";
        final nrBandStr = signal?.nrBand != null ? "n${signal!.nrBand}" : "--";
        final pciStr = signal?.nrPci != null ? "${signal!.nrPci}" : "--";

        return Container(
            padding: const EdgeInsets.all(2.0),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(4.0),
                border: Border.all(color: const Color(0xFF00ADB5).withOpacity(0.2), width: 0.5),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                            Text(
                                "$titlePrefix ($nrBandStr)",
                                style: GoogleFonts.notoSansJp(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF00E5FF),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                                "PCI: $pciStr",
                                style: GoogleFonts.notoSansMono(
                                    fontSize: 8.5,
                                    color: Colors.white60,
                                ),
                            ),
                        ],
                    ),
                    IntensityBarMetric(
                        label: "RSRP",
                        value: signal?.nrRsrp,
                        unit: "dBm",
                        minVal: -140.0,
                        maxVal: -50.0,
                        barColor: const Color(0xFF00ADB5),
                        height: 14.0,
                        fontSize: 8.5,
                    ),
                    IntensityBarMetric(
                        label: "RSRQ",
                        value: signal?.nrRsrq,
                        unit: "dB",
                        minVal: -25.0,
                        maxVal: -3.0,
                        barColor: const Color(0xFF00ADB5),
                        height: 14.0,
                        fontSize: 8.5,
                    ),
                    IntensityBarMetric(
                        label: "SNR",
                        value: signal?.nrSnr,
                        unit: "dB",
                        minVal: -10.0,
                        maxVal: 30.0,
                        barColor: const Color(0xFF00ADB5),
                        height: 14.0,
                        fontSize: 8.5,
                    ),
                ],
            ),
        );
    }

    Widget _build4gSection(SignalData? signal, {required bool isHorizontal}) {
        final lteBandStr = signal?.lteBand != null ? "B${signal!.lteBand}" : "--";
        final pciStr = signal?.ltePci != null ? "${signal!.ltePci}" : "--";

        return Container(
            padding: const EdgeInsets.all(2.0),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(4.0),
                border: Border.all(color: const Color(0xFF2196F3).withOpacity(0.2), width: 0.5),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                            Text(
                                "4G ($lteBandStr)",
                                style: GoogleFonts.notoSansJp(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF64B5F6),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                                "PCI: $pciStr",
                                style: GoogleFonts.notoSansMono(
                                    fontSize: 8.5,
                                    color: Colors.white60,
                                ),
                            ),
                        ],
                    ),
                    IntensityBarMetric(
                        label: "RSRP",
                        value: signal?.lteRsrp,
                        unit: "dBm",
                        minVal: -140.0,
                        maxVal: -50.0,
                        barColor: const Color(0xFF2196F3),
                        height: 14.0,
                        fontSize: 8.5,
                    ),
                    IntensityBarMetric(
                        label: "RSRQ",
                        value: signal?.lteRsrq,
                        unit: "dB",
                        minVal: -25.0,
                        maxVal: -3.0,
                        barColor: const Color(0xFF2196F3),
                        height: 14.0,
                        fontSize: 8.5,
                    ),
                    IntensityBarMetric(
                        label: "SINR",
                        value: signal?.lteSinr,
                        unit: "dB",
                        minVal: -10.0,
                        maxVal: 30.0,
                        barColor: const Color(0xFF2196F3),
                        height: 14.0,
                        fontSize: 8.5,
                    ),
                ],
            ),
        );
    }
}
