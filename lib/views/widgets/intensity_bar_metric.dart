import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class IntensityBarMetric extends StatelessWidget {
    final String label;
    final double? value;
    final String unit;
    final double minVal;
    final double maxVal;
    final Color barColor;
    final double height;
    final double fontSize;

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
    });

    static double calculateNormalizedRatio(double? val, double min, double max) {
        if (val == null || val.isNaN) return 0.0;
        return ((val - min) / (max - min)).clamp(0.0, 1.0);
    }

    @override
    Widget build(BuildContext context) {
        final double ratio = calculateNormalizedRatio(value, minVal, maxVal);
        final String textValue = (value != null && !value!.isNaN)
            ? "${value!.toStringAsFixed(1)} $unit"
            : "-- $unit";

        return Container(
            height: height,
            margin: const EdgeInsets.symmetric(vertical: 2.0),
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
                                    color: barColor.withOpacity(0.35),
                                ),
                            ),
                        ),
                        // Label & Numeric Value Text
                        Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6.0),
                            child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                    Text(
                                        label,
                                        style: GoogleFonts.notoSansJp(
                                            fontSize: fontSize,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white70,
                                        ),
                                    ),
                                    Text(
                                        textValue,
                                        style: GoogleFonts.notoSansMono(
                                            fontSize: fontSize,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                        ),
                                    ),
                                ],
                            ),
                        ),
                    ],
                ),
            ),
        );
    }
}
