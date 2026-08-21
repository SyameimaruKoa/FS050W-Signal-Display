import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/color_gauge.dart';

class MetricGauge extends StatelessWidget {
    final String label;
    final double? value;
    final String unit;
    final SignalRatingLevel level;
    final String? annotation;

    const MetricGauge({
        super.key,
        required this.label,
        required this.value,
        required this.unit,
        required this.level,
        this.annotation,
    });

    @override
    Widget build(BuildContext context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final color = ColorGauge.getColor(level);
        final progress = ColorGauge.getProgress(level);
        final levelText = ColorGauge.getLabel(level);

        final valueText = value != null
            ? "${value! > 0 && (unit == 'dB' || unit == 'dBm') && label.contains('S') ? '+' : ''}${value!.toStringAsFixed(1)} $unit"
            : "-- $unit";

        return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                            Text(
                                label,
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white70 : Colors.black87,
                                ),
                            ),
                            Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                    SizedBox(
                                        width: 96,
                                        child: Text(
                                            valueText,
                                            textAlign: TextAlign.right,
                                            style: GoogleFonts.notoSansMono(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: color,
                                            ),
                                        ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                        width: 78,
                                        height: 24,
                                        alignment: Alignment.center,
                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                        decoration: BoxDecoration(
                                            color: color.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: color.withOpacity(0.4), width: 0.8),
                                        ),
                                        child: Text(
                                            annotation ?? levelText,
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: color,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                        ),
                                    ),
                                ],
                            ),
                        ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            backgroundColor: isDark ? Colors.white12 : Colors.black12,
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                    ),
                ],
            ),
        );
    }
}
