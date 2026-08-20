import 'package:flutter/material.dart';

enum SignalRatingLevel {
    excellent,   // ① 極めて優秀 (青)
    good,        // ② 良好 (緑)
    moderate,    // ③ 普通 (黄緑)
    weak,        // ④ 微弱 / 不良 (オレンジ)
    veryWeak,    // ⑤ 極めて微弱 (赤)
    critical,    // ⑥ 限界 / 圏外寸前 (深紫)
    unknown,     // 未取得
}

class ColorGauge {
    static const Color colorExcellent = Color(0xFF2196F3); // 青
    static const Color colorGood = Color(0xFF4CAF50);      // 緑
    static const Color colorModerate = Color(0xFF8BC34A);  // 黄緑
    static const Color colorWeak = Color(0xFFFF9800);      // オレンジ
    static const Color colorVeryWeak = Color(0xFFF44336);  // 赤
    static const Color colorCritical = Color(0xFF9C27B0);  // 深紫
    static const Color colorUnknown = Color(0xFF757575);   // グレー

    static SignalRatingLevel rateRsrp(double? rsrp) {
        if (rsrp == null) return SignalRatingLevel.unknown;
        if (rsrp >= -80.0) return SignalRatingLevel.excellent;
        if (rsrp >= -90.0) return SignalRatingLevel.good;
        if (rsrp >= -100.0) return SignalRatingLevel.moderate;
        if (rsrp >= -110.0) return SignalRatingLevel.weak;
        if (rsrp >= -120.0) return SignalRatingLevel.veryWeak;
        return SignalRatingLevel.critical;
    }

    static SignalRatingLevel rateRsrq(double? rsrq) {
        if (rsrq == null) return SignalRatingLevel.unknown;
        if (rsrq >= -9.0) return SignalRatingLevel.excellent;
        if (rsrq >= -12.0) return SignalRatingLevel.good;
        if (rsrq >= -15.0) return SignalRatingLevel.moderate;
        if (rsrq >= -17.5) return SignalRatingLevel.weak;
        if (rsrq >= -19.5) return SignalRatingLevel.veryWeak;
        return SignalRatingLevel.critical;
    }

    static SignalRatingLevel rateSinr(double? sinr) {
        if (sinr == null) return SignalRatingLevel.unknown;
        if (sinr >= 20.0) return SignalRatingLevel.excellent;
        if (sinr >= 13.0) return SignalRatingLevel.good;
        if (sinr >= 5.0) return SignalRatingLevel.moderate;
        if (sinr >= 0.0) return SignalRatingLevel.weak;
        if (sinr >= -10.0) return SignalRatingLevel.veryWeak;
        return SignalRatingLevel.critical;
    }

    static Color getColor(SignalRatingLevel level) {
        switch (level) {
            case SignalRatingLevel.excellent:
                return colorExcellent;
            case SignalRatingLevel.good:
                return colorGood;
            case SignalRatingLevel.moderate:
                return colorModerate;
            case SignalRatingLevel.weak:
                return colorWeak;
            case SignalRatingLevel.veryWeak:
                return colorVeryWeak;
            case SignalRatingLevel.critical:
                return colorCritical;
            case SignalRatingLevel.unknown:
                return colorUnknown;
        }
    }

    static String getLabel(SignalRatingLevel level) {
        switch (level) {
            case SignalRatingLevel.excellent:
                return "極めて優秀";
            case SignalRatingLevel.good:
                return "良好";
            case SignalRatingLevel.moderate:
                return "普通";
            case SignalRatingLevel.weak:
                return "微弱";
            case SignalRatingLevel.veryWeak:
                return "極めて微弱";
            case SignalRatingLevel.critical:
                return "限界 / 圏外寸前";
            case SignalRatingLevel.unknown:
                return "未取得";
        }
    }

    static double getProgress(SignalRatingLevel level) {
        switch (level) {
            case SignalRatingLevel.excellent:
                return 1.0;
            case SignalRatingLevel.good:
                return 0.83;
            case SignalRatingLevel.moderate:
                return 0.66;
            case SignalRatingLevel.weak:
                return 0.50;
            case SignalRatingLevel.veryWeak:
                return 0.33;
            case SignalRatingLevel.critical:
                return 0.16;
            case SignalRatingLevel.unknown:
                return 0.0;
        }
    }
}
