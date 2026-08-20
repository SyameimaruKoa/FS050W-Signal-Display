import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/signal_data.dart';
import '../../models/connection_state.dart';
import '../../utils/calc_frequency.dart';
import '../../utils/color_gauge.dart';
import 'metric_gauge.dart';

class CellCard extends StatelessWidget {
    final String title;
    final IconData icon;
    final Color accentColor;
    final List<Widget> children;
    final Widget? headerTrailing;

    const CellCard({
        super.key,
        required this.title,
        required this.icon,
        required this.accentColor,
        required this.children,
        this.headerTrailing,
    });

    @override
    Widget build(BuildContext context) {
        return Card(
            elevation: 2,
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: accentColor.withOpacity(0.3), width: 1.2),
            ),
            color: Theme.of(context).cardColor,
            child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Row(
                            children: [
                                Icon(icon, color: accentColor, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(
                                        title,
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: accentColor,
                                        ),
                                    ),
                                ),
                                if (headerTrailing != null) headerTrailing!,
                            ],
                        ),
                        const Divider(height: 16, thickness: 0.8),
                        ...children,
                    ],
                ),
            ),
        );
    }

    static Widget build5gNrCard(BuildContext context, SignalData? signal) {
        if (signal == null) {
            return const CellCard(
                title: "【最上段：5G NR Secondary Cell】",
                icon: Icons.cell_tower,
                accentColor: Color(0xFF00E5FF),
                children: [
                    Text("データ取得待機中...", style: TextStyle(color: Colors.white60)),
                ],
            );
        }

        final mode = signal.connectionMode;
        final isNrHidden = (mode == Fs050wConnectionMode.lte || mode == Fs050wConnectionMode.lteCa);
        final isStandby = (mode == Fs050wConnectionMode.nsaReady || mode == Fs050wConnectionMode.nsaReadyCa);

        if (isNrHidden) {
            return const SizedBox.shrink();
        }

        if (isStandby) {
            return CellCard(
                title: "5G NR Secondary Cell (待機中)",
                icon: Icons.cell_tower,
                accentColor: Colors.blueGrey,
                children: [
                    Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                            children: [
                                Icon(Icons.hourglass_empty, color: Colors.orangeAccent, size: 18),
                                SizedBox(width: 8),
                                Expanded(
                                    child: Text(
                                        "5G NSA 待機中 (ENDC 未確立 / 4G Ready)",
                                        style: TextStyle(color: Colors.white70, fontSize: 13),
                                    ),
                                ),
                            ],
                        ),
                    ),
                ],
            );
        }

        final nrBandName = FrequencyCalculator.getNrBandName(signal.nrBand);
        final freqStr = signal.nrFrequency != null ? "${signal.nrFrequency!.toStringAsFixed(1)} MHz" : "--";
        final isSub6 = FrequencyCalculator.isSub6Band(signal.nrBand);
        final nrTitle = isSub6 ? "▼ 5G+ NR+ ($nrBandName)" : "▼ 5G NR ($nrBandName)";

        final rsrpLevel = ColorGauge.rateRsrp(signal.nrRsrp);
        final rsrqLevel = ColorGauge.rateRsrq(signal.nrRsrq);
        final snrLevel = ColorGauge.rateSinr(signal.nrSnr);

        return CellCard(
            title: nrTitle,
            icon: Icons.five_g,
            accentColor: isSub6 ? const Color(0xFF00E5FF) : const Color(0xFF4CAF50),
            headerTrailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: (isSub6 ? const Color(0xFF00E5FF) : const Color(0xFF4CAF50)).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                    isSub6 ? "sub6 高速5G" : "転用 / 通常5G",
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSub6 ? const Color(0xFF00E5FF) : const Color(0xFF4CAF50),
                    ),
                ),
            ),
            children: [
                Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                            Row(
                                children: [
                                    const Text("PCI: ", style: TextStyle(fontSize: 12, color: Colors.white60)),
                                    Text(
                                        signal.nrPci != null ? "${signal.nrPci}" : "--",
                                        style: GoogleFonts.notoSansMono(fontSize: 13, fontWeight: FontWeight.bold),
                                    ),
                                ],
                            ),
                            Row(
                                children: [
                                    const Text("NR-ARFCN: ", style: TextStyle(fontSize: 12, color: Colors.white60)),
                                    Text(
                                        signal.nrArfcn != null ? "${signal.nrArfcn} ($freqStr)" : "--",
                                        style: GoogleFonts.notoSansMono(fontSize: 13, fontWeight: FontWeight.bold),
                                    ),
                                ],
                            ),
                        ],
                    ),
                ),
                const SizedBox(height: 8),
                MetricGauge(
                    label: "RSRP",
                    value: signal.nrRsrp,
                    unit: "dBm",
                    level: rsrpLevel,
                ),
                MetricGauge(
                    label: "RSRQ",
                    value: signal.nrRsrq,
                    unit: "dB",
                    level: rsrqLevel,
                ),
                MetricGauge(
                    label: "SNR (補正済)",
                    value: signal.nrSnr,
                    unit: "dB",
                    level: snrLevel,
                    annotation: "${ColorGauge.getLabel(snrLevel)}・補正済",
                ),
            ],
        );
    }

    static Widget build4gLteCard(BuildContext context, SignalData? signal) {
        if (signal == null) {
            return const CellCard(
                title: "【下段：4G LTE Anchor Cell】",
                icon: Icons.network_cell,
                accentColor: Color(0xFF2196F3),
                children: [
                    Text("データ取得待機中...", style: TextStyle(color: Colors.white60)),
                ],
            );
        }

        if (signal.isSa) {
            // 5G SAの場合は4Gアンカーカード非表示 (設計書準拠)
            return const SizedBox.shrink();
        }

        final bandName = FrequencyCalculator.getLteBandName(signal.lteBand);
        final freqStr = signal.lteFrequency != null ? "${signal.lteFrequency!.toStringAsFixed(1)} MHz" : "--";
        final anchorText = ConnectionModeHelper.get4gAnchorText(
            signal.connectionMode,
            bandName,
            hasCa: signal.hasCa,
            caBands: signal.caBands,
        );

        final rsrpLevel = ColorGauge.rateRsrp(signal.lteRsrp);
        final rsrqLevel = ColorGauge.rateRsrq(signal.lteRsrq);
        final sinrLevel = ColorGauge.rateSinr(signal.lteSinr);

        return CellCard(
            title: "▼ $anchorText",
            icon: Icons.four_g_mobiledata,
            accentColor: const Color(0xFF2196F3),
            headerTrailing: signal.hasCa
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                        "CA 有効",
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                    ),
                )
                : null,
            children: [
                Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                            Row(
                                children: [
                                    const Text("PCI: ", style: TextStyle(fontSize: 12, color: Colors.white60)),
                                    Text(
                                        signal.ltePci != null ? "${signal.ltePci}" : "--",
                                        style: GoogleFonts.notoSansMono(fontSize: 13, fontWeight: FontWeight.bold),
                                    ),
                                ],
                            ),
                            Row(
                                children: [
                                    const Text("EARFCN: ", style: TextStyle(fontSize: 12, color: Colors.white60)),
                                    Text(
                                        signal.lteEarfcn != null ? "${signal.lteEarfcn} ($freqStr)" : "--",
                                        style: GoogleFonts.notoSansMono(fontSize: 13, fontWeight: FontWeight.bold),
                                    ),
                                ],
                            ),
                        ],
                    ),
                ),
                const SizedBox(height: 8),
                MetricGauge(
                    label: "RSRP",
                    value: signal.lteRsrp,
                    unit: "dBm",
                    level: rsrpLevel,
                ),
                MetricGauge(
                    label: "RSRQ",
                    value: signal.lteRsrq,
                    unit: "dB",
                    level: rsrqLevel,
                ),
                MetricGauge(
                    label: "SINR",
                    value: signal.lteSinr,
                    unit: "dB",
                    level: sinrLevel,
                ),
            ],
        );
    }
}
