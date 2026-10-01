import 'package:flutter/material.dart';
import '../../utils/color_gauge.dart';

class IntensityBarMetric extends StatelessWidget {
    final String label;
    final double? value;
    final String unit;
    final double minVal;
    final double maxVal;
    final Color barColor;
    final double? height;
    final double fontSize;
    final bool smoothGaugeColor;
    final String smoothGaugeCurve;

    const IntensityBarMetric({
        super.key,
        required this.label,
        required this.value,
        required this.unit,
        required this.minVal,
        required this.maxVal,
        required this.barColor,
        this.height = 20.0,
        this.fontSize = 11.0,
        this.smoothGaugeColor = false,
        this.smoothGaugeCurve = "easeOut",
    });

    static double calculateNormalizedRatio(
        double? val,
        double min,
        double max, {
        String curve = "linear",
    }) {
        if (val == null || val.isNaN) return 0.0;
        final raw = ((val - min) / (max - min)).clamp(0.0, 1.0);
        return ColorGauge.applyCurve(raw, curve);
    }

    @override
    Widget build(BuildContext context) {
        final double rawRatio = (value != null && value!.isFinite && value! > -200)
            ? ((value! - minVal) / (maxVal - minVal)).clamp(0.0, 1.0)
            : 0.0;
        final double ratio = ColorGauge.applyCurve(rawRatio, smoothGaugeCurve);
        final Color activeColor = smoothGaugeColor
            ? (value != null && value!.isFinite && value! > -200 ? ColorGauge.getSmoothColor(rawRatio, curve: smoothGaugeCurve) : barColor)
            : barColor;
        final String textValue = (value != null && value!.isFinite && value! > -200)
            ? "${value!.toStringAsFixed(1)} $unit"
            : "-- $unit";

        final content = Container(
            height: height,
            margin: const EdgeInsets.symmetric(vertical: 1.0),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(4.0),
                border: Border.all(color: Colors.white.withOpacity(0.08), width: 0.5),
            ),
            child: ClipRRect(
                borderRadius: BorderRadius.circular(3.5),
                child: Stack(
                    children: [
                        // Horizontal Intensity Progress Bar
                        FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: ratio,
                            child: Container(
                                decoration: BoxDecoration(
                                    color: activeColor.withOpacity(0.35),
                                ),
                            ),
                        ),
                        // Label & Numeric Value Text
                        Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5.0),
                            child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                    Expanded(
                                        flex: 2,
                                        child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                alignment: Alignment.centerLeft,
                                                child: Text(
                                                    label,
                                                    style: TextStyle(
                                                        fontSize: fontSize,
                                                        fontWeight: FontWeight.w600,
                                                        color: Colors.white70,
                                                    ),
                                                ),
                                            ),
                                        ),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                        flex: 3,
                                        child: Align(
                                            alignment: Alignment.centerRight,
                                            child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                alignment: Alignment.centerRight,
                                                child: Text(
                                                    textValue,
                                                    style: TextStyle(
                                                        fontSize: fontSize,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.white,
                                                    ),
                                                ),
                                            ),
                                        ),
                                    ),
                                ],
                            ),
                        ),
                    ],
                ),
            ),
        );

        return content;
    }
}

