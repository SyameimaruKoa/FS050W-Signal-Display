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

    static Widget build5gNrCard(
        BuildContext context,
        SignalData? signal, {
        String notation = "4g_5g",
        bool smoothGaugeColor = false,
        String smoothGaugeCurve = "easeOut",
    }) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final isLteNr = notation == "lte_nr";
        final genLabel = ConnectionModeHelper.getGenerationName(true, notation: notation);

        if (signal == null) {
            return CellCard(
                title: "【$genLabel Secondary Cell】",
                icon: Icons.cell_tower,
                accentColor: const Color(0xFF00E5FF),
                children: [
                    Text("データ取得待機中...", style: TextStyle(color: isDark ? Colors.white60 : Colors.black54)),
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
                title: "${ConnectionModeHelper.get5gCardTitle(mode, notation: notation)}",
                icon: Icons.cell_tower,
                accentColor: Colors.blueGrey,
                children: [
                    Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                            children: [
                                const Icon(Icons.hourglass_empty, color: Colors.orangeAccent, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(
                                        "$genLabel NSA 待機中 (ENDC 未確立 / ${ConnectionModeHelper.get4gCardTitle(mode, notation: notation)})",
                                        style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 13),
                                    ),
                                ),
                            ],
                        ),
                    ),
                ],
            );
        }

        final nrBandName = FrequencyCalculator.getNrBandName(signal.nrBand, operatorName: signal.operatorName);
        final isSub6 = FrequencyCalculator.isSub6Band(signal.nrBand);
        final nrTitle = "● ${ConnectionModeHelper.get5gCardTitle(mode, notation: notation)}";

        final rsrpLevel = ColorGauge.rateRsrp(signal.nrRsrp);
        final rsrqLevel = ColorGauge.rateRsrq(signal.nrRsrq);
        final snrLevel = ColorGauge.rateSinr(signal.nrSnr);

        final tagText = FrequencyCalculator.getNrBadgeText(signal.nrBand, operatorName: signal.operatorName);

        return CellCard(
            title: nrTitle,
            icon: Icons.cell_tower,
            accentColor: isSub6 ? const Color(0xFF00E5FF) : const Color(0xFF4CAF50),
            headerTrailing: tagText != null
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: (isSub6 ? const Color(0xFF00E5FF) : const Color(0xFF4CAF50)).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                        tagText,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isSub6 ? const Color(0xFF00E5FF) : const Color(0xFF4CAF50),
                        ),
                    ),
                )
                : null,
            children: [
                Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                            Row(
                                children: [
                                    Text("PCI: ", style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54)),
                                    Text(
                                        signal.nrPci != null ? "${signal.nrPci}" : "--",
                                        style: GoogleFonts.notoSansMono(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white : Colors.black87,
                                        ),
                                    ),
                                ],
                            ),
                            Flexible(
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                        Text("Band: ", style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54)),
                                        Flexible(
                                            child: Text(
                                                nrBandName,
                                                style: GoogleFonts.notoSansMono(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: isDark ? Colors.white : Colors.black87,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                            ),
                                        ),
                                    ],
                                ),
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
                    smoothGaugeColor: smoothGaugeColor,
                    smoothGaugeCurve: smoothGaugeCurve,
                    minVal: ColorGauge.rsrpMin,
                    maxVal: ColorGauge.rsrpMax,
                ),
                MetricGauge(
                    label: "RSRQ",
                    value: signal.nrRsrq,
                    unit: "dB",
                    level: rsrqLevel,
                    smoothGaugeColor: smoothGaugeColor,
                    smoothGaugeCurve: smoothGaugeCurve,
                    minVal: ColorGauge.rsrqMin,
                    maxVal: ColorGauge.rsrqMax,
                ),
                MetricGauge(
                    label: "SNR (補正済)",
                    value: signal.nrSnr,
                    unit: "dB",
                    level: snrLevel,
                    smoothGaugeColor: smoothGaugeColor,
                    smoothGaugeCurve: smoothGaugeCurve,
                    minVal: ColorGauge.sinrMin,
                    maxVal: ColorGauge.sinrMax,
                ),
            ],
        );
    }

    static Widget build4gLteCard(
        BuildContext context,
        SignalData? signal, {
        String notation = "4g_5g",
        bool smoothGaugeColor = false,
        String smoothGaugeCurve = "easeOut",
    }) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final genLabel = ConnectionModeHelper.getGenerationName(false, notation: notation);

        if (signal == null) {
            return CellCard(
                title: "● $genLabel Anchor Cell",
                icon: Icons.network_cell,
                accentColor: const Color(0xFF2196F3),
                children: [
                    Text("データ取得待機中...", style: TextStyle(color: isDark ? Colors.white60 : Colors.black54)),
                ],
            );
        }

        if (signal.isSa) {
            // 5G SAの場合は4Gアンカーカード非表示
            return const SizedBox.shrink();
        }

        final bandName = FrequencyCalculator.getLteBandName(signal.lteBand, operatorName: signal.operatorName);
        final lteBadge = FrequencyCalculator.getLteBadgeText(signal.lteBand, operatorName: signal.operatorName);
        final titleText = "● ${ConnectionModeHelper.get4gCardTitle(signal.connectionMode, notation: notation)}";

        final rsrpLevel = ColorGauge.rateRsrp(signal.lteRsrp);
        final rsrqLevel = ColorGauge.rateRsrq(signal.lteRsrq);
        final sinrLevel = ColorGauge.rateSinr(signal.lteSinr);

        return CellCard(
            title: titleText,
            icon: Icons.network_cell,
            accentColor: const Color(0xFF2196F3),
            headerTrailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                    if (lteBadge != null) ...[
                        Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color: (lteBadge.contains("楽天") || lteBadge.contains("au"))
                                    ? Colors.pinkAccent.withOpacity(0.2)
                                    : Colors.blueAccent.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                                lteBadge,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: (lteBadge.contains("楽天") || lteBadge.contains("au"))
                                        ? Colors.pinkAccent
                                        : Colors.blueAccent,
                                ),
                            ),
                        ),
                        const SizedBox(width: 4),
                    ],
                    if (signal.hasCa)
                        Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color: Colors.blueAccent.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                                "CA 有効",
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                            ),
                        ),
                ],
            ),
            children: [
                Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                            Row(
                                children: [
                                    Text("PCI: ", style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54)),
                                    Text(
                                        signal.ltePci != null ? "${signal.ltePci}" : "--",
                                        style: GoogleFonts.notoSansMono(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white : Colors.black87,
                                        ),
                                    ),
                                ],
                            ),
                            Flexible(
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                        Text("Band: ", style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54)),
                                        Flexible(
                                            child: Text(
                                                bandName,
                                                style: GoogleFonts.notoSansMono(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: isDark ? Colors.white : Colors.black87,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                            ),
                                        ),
                                    ],
                                ),
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
                    smoothGaugeColor: smoothGaugeColor,
                    smoothGaugeCurve: smoothGaugeCurve,
                    minVal: ColorGauge.rsrpMin,
                    maxVal: ColorGauge.rsrpMax,
                ),
                MetricGauge(
                    label: "RSRQ",
                    value: signal.lteRsrq,
                    unit: "dB",
                    level: rsrqLevel,
                    smoothGaugeColor: smoothGaugeColor,
                    smoothGaugeCurve: smoothGaugeCurve,
                    minVal: ColorGauge.rsrqMin,
                    maxVal: ColorGauge.rsrqMax,
                ),
                MetricGauge(
                    label: "SINR",
                    value: signal.lteSinr,
                    unit: "dB",
                    level: sinrLevel,
                    smoothGaugeColor: smoothGaugeColor,
                    smoothGaugeCurve: smoothGaugeCurve,
                    minVal: ColorGauge.sinrMin,
                    maxVal: ColorGauge.sinrMax,
                ),
            ],
        );
    }
}
