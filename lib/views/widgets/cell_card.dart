import 'package:flutter/material.dart';
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
        final hasDetailParams = signal.nrRsrq != null || signal.nrSnr != null || signal.nrPci != null;

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
                                        (signal.nrPci != null && signal.nrPci! > 0) ? "${signal.nrPci}" : "--",
                                        style: TextStyle(
                                            fontFamily: 'monospace',
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
                                                style: TextStyle(
                                                    fontFamily: 'monospace',
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
                // Main RSRP Primary Metric
                MetricGauge(
                    label: "RSRP (電波強度・主指標)",
                    value: signal.nrRsrp,
                    unit: "dBm",
                    level: rsrpLevel,
                    smoothGaugeColor: smoothGaugeColor,
                    smoothGaugeCurve: smoothGaugeCurve,
                    minVal: ColorGauge.rsrpMin,
                    maxVal: ColorGauge.rsrpMax,
                ),
                const SizedBox(height: 4),
                // Consolidated Reference Metrics (RSRQ / SNR)
                if (hasDetailParams)
                    Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.025),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05)),
                        ),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Row(
                                    children: [
                                        Icon(Icons.info_outline, size: 12, color: isDark ? Colors.white38 : Colors.black38),
                                        const SizedBox(width: 4),
                                        Text(
                                            "参考品質指標 (推定目安)",
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: isDark ? Colors.white54 : Colors.black45,
                                            ),
                                        ),
                                    ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                    children: [
                                        Expanded(
                                            child: _buildCompactRefMetric(
                                                context,
                                                label: "RSRQ",
                                                value: signal.nrRsrq,
                                                unit: "dB",
                                                level: rsrqLevel,
                                            ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                            child: _buildCompactRefMetric(
                                                context,
                                                label: "SNR",
                                                value: signal.nrSnr,
                                                unit: "dB",
                                                level: snrLevel,
                                            ),
                                        ),
                                    ],
                                ),
                            ],
                        ),
                    )
                else
                    Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
                            borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                            children: [
                                Icon(Icons.lock_outline, size: 13, color: isDark ? Colors.white38 : Colors.black38),
                                const SizedBox(width: 6),
                                Expanded(
                                    child: Text(
                                        "ログインすると詳細パラメータ (PCI/Band/RQ/SNR) が表示されます",
                                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black45),
                                    ),
                                ),
                            ],
                        ),
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
        final hasDetailParams = signal.lteRsrq != null || signal.lteSinr != null || signal.ltePci != null;

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
                                        (signal.ltePci != null && signal.ltePci! > 0) ? "${signal.ltePci}" : "--",
                                        style: TextStyle(
                                            fontFamily: 'monospace',
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
                                                style: TextStyle(
                                                    fontFamily: 'monospace',
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
                // Main RSRP Primary Metric
                MetricGauge(
                    label: "RSRP (電波強度・主指標)",
                    value: signal.lteRsrp,
                    unit: "dBm",
                    level: rsrpLevel,
                    smoothGaugeColor: smoothGaugeColor,
                    smoothGaugeCurve: smoothGaugeCurve,
                    minVal: ColorGauge.rsrpMin,
                    maxVal: ColorGauge.rsrpMax,
                ),
                const SizedBox(height: 4),
                // Consolidated Reference Metrics (RSRQ / SINR)
                if (hasDetailParams)
                    Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.025),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05)),
                        ),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Row(
                                    children: [
                                        Icon(Icons.info_outline, size: 12, color: isDark ? Colors.white38 : Colors.black38),
                                        const SizedBox(width: 4),
                                        Text(
                                            "参考品質指標 (推定目安)",
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: isDark ? Colors.white54 : Colors.black45,
                                            ),
                                        ),
                                    ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                    children: [
                                        Expanded(
                                            child: _buildCompactRefMetric(
                                                context,
                                                label: "RSRQ",
                                                value: signal.lteRsrq,
                                                unit: "dB",
                                                level: rsrqLevel,
                                            ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                            child: _buildCompactRefMetric(
                                                context,
                                                label: "SINR",
                                                value: signal.lteSinr,
                                                unit: "dB",
                                                level: sinrLevel,
                                            ),
                                        ),
                                    ],
                                ),
                            ],
                        ),
                    )
                else
                    Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
                            borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                            children: [
                                Icon(Icons.lock_outline, size: 13, color: isDark ? Colors.white38 : Colors.black38),
                                const SizedBox(width: 6),
                                Expanded(
                                    child: Text(
                                        "ログインすると詳細パラメータ (PCI/Band/RQ/SINR) が表示されます",
                                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black45),
                                    ),
                                ),
                            ],
                        ),
                    ),
            ],
        );
    }

    static Widget _buildCompactRefMetric(
        BuildContext context, {
        required String label,
        required double? value,
        required String unit,
        required SignalRatingLevel level,
    }) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final color = ColorGauge.getColor(level);
        final valText = (value != null && !value.isNaN && value > -200)
            ? "${value > 0 && unit == 'dB' && label.contains('S') ? '+' : ''}${value.toStringAsFixed(1)} $unit"
            : "-- $unit";
        final levelText = (value != null && !value.isNaN && value > -200)
            ? ColorGauge.getLabel(level)
            : "--";

        return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
                borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                    Text(
                        label,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white60 : Colors.black54,
                        ),
                    ),
                    Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                            Text(
                                valText,
                                style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: (value != null && !value.isNaN && value > -200) ? color : (isDark ? Colors.white38 : Colors.black38),
                                ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                    color: (value != null && !value.isNaN && value > -200) ? color.withOpacity(0.15) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                    levelText,
                                    style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: (value != null && !value.isNaN && value > -200) ? color : (isDark ? Colors.white24 : Colors.black26),
                                    ),
                                ),
                            ),
                        ],
                    ),
                ],
            ),
        );
    }
}
