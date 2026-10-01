import 'dart:math' as math;
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

class MetricThreshold {
    final double value;
    final SignalRatingLevel level;
    final Color color;
    final String label;

    const MetricThreshold({
        required this.value,
        required this.level,
        required this.color,
        required this.label,
    });
}

class ColorGauge {
    static Color temperatureColor(double? temperature, {double threshold = 45.0}) {
        if (temperature == null || !temperature.isFinite) return colorUnknown;
        if (temperature >= threshold) return const Color(0xFFFF5252);
        if (temperature >= threshold - 5.0) return const Color(0xFFFFD600);
        return const Color(0xFF00E5FF);
    }

    static Color latencyColor(int? milliseconds) {
        if (milliseconds == null) return colorUnknown;
        if (milliseconds <= 50) return const Color(0xFF00E676);
        if (milliseconds <= 150) return const Color(0xFFFFD600);
        return const Color(0xFFFF5252);
    }

    static Color metricColor(double? value, SignalRatingLevel level,
        double min, double max, {bool smooth = false, String curve = "easeOut"}) {
        if (value == null || !value.isFinite || value <= -200) return colorUnknown;
        return smooth
            ? getSmoothColor(((value - min) / (max - min)).clamp(0.0, 1.0), curve: curve)
            : getColor(level);
    }

    static const Color colorExcellent = Color(0xFF2196F3); // 青 (極めて優秀)
    static const Color colorGood = Color(0xFF4CAF50);      // 緑 (良好)
    static const Color colorModerate = Color(0xFF8BC34A);  // 黄緑 (普通)
    static const Color colorWeak = Color(0xFFFF9800);      // オレンジ (微弱)
    static const Color colorVeryWeak = Color(0xFFF44336);  // 赤 (極めて微弱)
    static const Color colorCritical = Color(0xFF9C27B0);  // 深紫 (限界 / 圏外寸前)
    static const Color colorUnknown = Color(0xFF757575);   // グレー (未取得)

    // 実運用に即した電波バー表示範囲 (下限・上限のデッドスペースを解消)
    static const double rsrpMin = -120.0;
    static const double rsrpMax = -70.0;
    static const double rsrqMin = -22.0;
    static const double rsrqMax = -3.0;
    static const double sinrMin = -6.0;
    static const double sinrMax = 24.0;

    // 各指標の色替え閾値定義 (同期グラフ等の基準線用)
    static const List<MetricThreshold> rsrpThresholds = [
        MetricThreshold(value: -80.0, level: SignalRatingLevel.excellent, color: colorExcellent, label: "極めて優秀"),
        MetricThreshold(value: -90.0, level: SignalRatingLevel.good, color: colorGood, label: "良好"),
        MetricThreshold(value: -100.0, level: SignalRatingLevel.moderate, color: colorModerate, label: "普通"),
        MetricThreshold(value: -110.0, level: SignalRatingLevel.weak, color: colorWeak, label: "微弱"),
        MetricThreshold(value: -120.0, level: SignalRatingLevel.veryWeak, color: colorVeryWeak, label: "極めて微弱"),
    ];

    static const List<MetricThreshold> rsrqThresholds = [
        MetricThreshold(value: -10.0, level: SignalRatingLevel.excellent, color: colorExcellent, label: "極めて優秀"),
        MetricThreshold(value: -15.0, level: SignalRatingLevel.good, color: colorGood, label: "良好"),
        MetricThreshold(value: -18.0, level: SignalRatingLevel.moderate, color: colorModerate, label: "普通"),
        MetricThreshold(value: -20.0, level: SignalRatingLevel.weak, color: colorWeak, label: "微弱"),
        MetricThreshold(value: -22.0, level: SignalRatingLevel.veryWeak, color: colorVeryWeak, label: "極めて微弱"),
    ];

    static const List<MetricThreshold> sinrThresholds = [
        MetricThreshold(value: 20.0, level: SignalRatingLevel.excellent, color: colorExcellent, label: "極めて優秀"),
        MetricThreshold(value: 13.0, level: SignalRatingLevel.good, color: colorGood, label: "良好"),
        MetricThreshold(value: 0.0, level: SignalRatingLevel.moderate, color: colorModerate, label: "普通"),
        MetricThreshold(value: -3.0, level: SignalRatingLevel.weak, color: colorWeak, label: "微弱"),
        MetricThreshold(value: -6.0, level: SignalRatingLevel.veryWeak, color: colorVeryWeak, label: "極めて微弱"),
    ];

    static SignalRatingLevel rateRsrp(double? rsrp) {
        if (rsrp == null || !rsrp.isFinite || rsrp <= -200) return SignalRatingLevel.unknown;
        if (rsrp >= -80.0) return SignalRatingLevel.excellent;
        if (rsrp >= -90.0) return SignalRatingLevel.good;
        if (rsrp >= -100.0) return SignalRatingLevel.moderate;
        if (rsrp >= -110.0) return SignalRatingLevel.weak;
        if (rsrp >= -120.0) return SignalRatingLevel.veryWeak;
        return SignalRatingLevel.critical;
    }

    static SignalRatingLevel rateRsrq(double? rsrq) {
        if (rsrq == null || !rsrq.isFinite || rsrq <= -200) return SignalRatingLevel.unknown;
        if (rsrq >= -10.0) return SignalRatingLevel.excellent;
        if (rsrq >= -15.0) return SignalRatingLevel.good;
        if (rsrq >= -18.0) return SignalRatingLevel.moderate;
        if (rsrq >= -20.0) return SignalRatingLevel.weak;
        if (rsrq >= -22.0) return SignalRatingLevel.veryWeak;
        return SignalRatingLevel.critical;
    }

    static SignalRatingLevel rateSinr(double? sinr) {
        if (sinr == null || !sinr.isFinite || sinr <= -200) return SignalRatingLevel.unknown;
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

    /// イージング曲線の適用
    static double applyCurve(double ratio, String curveType) {
        final r = ratio.clamp(0.0, 1.0);
        switch (curveType) {
            case "easeOut":
                // 弱電界側の変化を敏感に表現 (Ease-out Quad)
                return 1.0 - math.pow(1.0 - r, 2.0).toDouble();
            case "easeIn":
                // 強電界側の変化を敏感に表現 (Ease-in Quad)
                return math.pow(r, 2.0).toDouble();
            case "easeInOut":
                // 中間域の変化を強調 (Ease-in-out Quad)
                return r < 0.5
                    ? 2.0 * r * r
                    : 1.0 - math.pow(-2.0 * r + 2.0, 2.0) / 2.0;
            case "linear":
            default:
                return r;
        }
    }

    /// シームレスカラー (グラデーション補間)
    /// ratio: 0.0 (紫) -> 0.2 (赤) -> 0.4 (橙) -> 0.6 (黄緑) -> 0.8 (緑) -> 1.0 (青)
    static Color getSmoothColor(double ratio, {String curve = "linear"}) {
        final curvedRatio = applyCurve(ratio, curve);
        final r = curvedRatio.clamp(0.0, 1.0);
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

    /// 連続値から正規化されたプログレス比率を計算 (イージング対応)
    static double calculateNormalizedRatio(
        double? val,
        double min,
        double max, {
        String curve = "linear",
    }) {
        if (val == null || val.isNaN) return 0.0;
        final rawRatio = ((val - min) / (max - min)).clamp(0.0, 1.0);
        return applyCurve(rawRatio, curve);
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
