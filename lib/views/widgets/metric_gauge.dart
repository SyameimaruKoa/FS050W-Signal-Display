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
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white70,
                                ),
                            ),
                            Row(
                                children: [
                                    Text(
                                        valueText,
                                        style: GoogleFonts.notoSansMono(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: color,
                                        ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                            backgroundColor: Colors.white12,
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                    ),
                ],
            ),
        );
    }
}
