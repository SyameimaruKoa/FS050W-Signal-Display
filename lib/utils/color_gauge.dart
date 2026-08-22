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
    static const Color colorExcellent = Color(0xFF2196F3); // 青 (極めて優秀)
    static const Color colorGood = Color(0xFF4CAF50);      // 緑 (良好)
    static const Color colorModerate = Color(0xFF8BC34A);  // 黄緑 (普通)
    static const Color colorWeak = Color(0xFFFF9800);      // オレンジ (微弱)
    static const Color colorVeryWeak = Color(0xFFF44336);  // 赤 (極めて微弱)
    static const Color colorCritical = Color(0xFF9C27B0);  // 深紫 (限界 / 圏外寸前)
    static const Color colorUnknown = Color(0xFF757575);   // グレー (未取得)

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
        if (rsrq >= -10.0) return SignalRatingLevel.excellent;
        if (rsrq >= -15.0) return SignalRatingLevel.good;
        if (rsrq >= -18.0) return SignalRatingLevel.moderate;
        if (rsrq >= -20.0) return SignalRatingLevel.weak;
        if (rsrq >= -22.0) return SignalRatingLevel.veryWeak;
        return SignalRatingLevel.critical;
    }

    static SignalRatingLevel rateSinr(double? sinr) {
        if (sinr == null) return SignalRatingLevel.unknown;
        if (sinr >= 20.0) return SignalRatingLevel.excellent;
        if (sinr >= 13.0) return SignalRatingLevel.good;
        if (sinr >= 0.0) return SignalRatingLevel.moderate;
        if (sinr >= -3.0) return SignalRatingLevel.weak;
        if (sinr >= -6.0) return SignalRatingLevel.veryWeak;
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

    /// シームレスカラー (グラデーション補間)
    /// ratio: 0.0 (紫) -> 0.2 (赤) -> 0.4 (橙) -> 0.6 (黄緑) -> 0.8 (緑) -> 1.0 (青)
    static Color getSmoothColor(double ratio) {
        final r = ratio.clamp(0.0, 1.0);
        if (r < 0.20) {
            final t = r / 0.20;
            return Color.lerp(colorCritical, colorVeryWeak, t)!;
        } else if (r < 0.40) {
            final t = (r - 0.20) / 0.20;
            return Color.lerp(colorVeryWeak, colorWeak, t)!;
        } else if (r < 0.60) {
            final t = (r - 0.40) / 0.20;
            return Color.lerp(colorWeak, colorModerate, t)!;
        } else if (r < 0.80) {
            final t = (r - 0.60) / 0.20;
            return Color.lerp(colorModerate, colorGood, t)!;
        } else {
            final t = (r - 0.80) / 0.20;
            return Color.lerp(colorGood, colorExcellent, t)!;
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
