import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../models/signal_data.dart';
import '../models/connection_state.dart';
import '../utils/color_gauge.dart';
import 'widgets/intensity_bar_metric.dart';

class PipScreen extends StatelessWidget {
    const PipScreen({super.key});

    @override
    Widget build(BuildContext context) {
        final apiService = context.watch<ApiService>();
        final signal = apiService.currentSignal;
        final settings = apiService.settings;
        final isConnecting = apiService.isConnecting;
        final aspectRatioStr = settings.pipAspectRatio;
        final history = apiService.signalHistory;

        return Scaffold(
            backgroundColor: Colors.black,
            body: LayoutBuilder(
                builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final height = constraints.maxHeight;

                    final bool isPortrait = aspectRatioStr.contains("9:16") || aspectRatioStr.contains("3:4") || aspectRatioStr.contains("9:21");
                    final bool isSquare = aspectRatioStr == '1:1';

                    final double thresholdMultiplier = settings.pipGraphScaleThreshold;

                    // 拡大判定: スペースに十分な余裕がある場合のみ履歴グラフを表示
                    final showGraph = settings.pipGraphType != 'none' &&
                        history.length >= 2 &&
                        (isSquare
                            ? (width >= (220 * thresholdMultiplier) && height >= (220 * thresholdMultiplier))
                            : isPortrait
                                ? (height >= (260 * thresholdMultiplier) && width >= (140 * thresholdMultiplier))
                                : (height >= (170 * thresholdMultiplier) && width >= (280 * thresholdMultiplier)));

                    return Container(
                        color: Colors.black,
                        width: width,
                        height: height,
                        padding: const EdgeInsets.symmetric(horizontal: 3.0, vertical: 2.0),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                                _buildHeader(context, apiService, signal, isConnecting, aspectRatioStr),
                                const SizedBox(height: 2.0),
                                Expanded(
                                    child: _buildMainContent(
                                        context,
                                        apiService,
                                        signal,
                                        aspectRatioStr,
                                        showGraph,
                                        history,
                                        width,
                                        height,
                                        apiService.isLoggedIn,
                                    ),
                                ),
                            ],
                        ),
                    );
                },
            ),
        );
    }

    Widget _buildHeader(
        BuildContext context,
        ApiService apiService,
        SignalData? signal,
        bool isConnecting,
        String aspectRatioStr,
    ) {
        final mode = signal?.connectionMode ?? Fs050wConnectionMode.disconnected;
        final notation = apiService.settings.generationNotation;
        final modeBadge = ConnectionModeHelper.getIconBadgeText(mode, notation: notation);
        final opName = signal?.operatorName ?? "--";
        final is1to1 = aspectRatioStr == '1:1';

        return Container(
            padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: is1to1 ? 2.5 : 1.5),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(3.0),
            ),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                    Flexible(
                        flex: 3,
                        child: Align(
                            alignment: Alignment.centerLeft,
                            child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.0),
                                    decoration: BoxDecoration(
                                        color: isConnecting ? Colors.amber.withOpacity(0.25) : const Color(0xFF00E5FF).withOpacity(0.25),
                                        borderRadius: BorderRadius.circular(2.5),
                                    ),
                                    child: Text(
                                        isConnecting ? "[ 接続中... ]" : "[ $modeBadge ]",
                                        style: TextStyle(
                                            fontFamilyFallback: const ['Noto Sans JP', 'sans-serif'],
                                            fontSize: is1to1 ? 11.0 : 9.5,
                                            fontWeight: FontWeight.bold,
                                            color: isConnecting ? Colors.amberAccent : const Color(0xFF00E5FF),
                                        ),
                                    ),
                                ),
                            ),
                        ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                        flex: 4,
                        child: Align(
                            alignment: Alignment.centerRight,
                            child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text(
                                    opName,
                                    style: TextStyle(
                                        fontFamilyFallback: const ['Noto Sans JP', 'sans-serif'],
                                        fontSize: is1to1 ? 11.0 : 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white70,
                                    ),
                                ),
                            ),
                        ),
                    ),
                ],
            ),
        );
    }

    Widget _buildMainContent(
        BuildContext context,
        ApiService apiService,
        SignalData? signal,
        String aspectRatioStr,
        bool showGraph,
        List<SignalData> history,
        double width,
        double height,
        bool isLoggedIn,
    ) {
        final notation = apiService.settings.generationNotation;
        final smooth = apiService.settings.smoothGaugeColor;
        final curve = apiService.settings.smoothGaugeCurve;
        final signalSection = _buildSignalGrid(signal, aspectRatioStr, notation, smooth, curve, height, isLoggedIn, width);

        if (!showGraph) {
            return signalSection;
        }

        final graphWidget = _buildMiniGraph(context, apiService, history);

        return Column(
            children: [
                Expanded(flex: aspectRatioStr.contains("9:16") || aspectRatioStr.contains("3:4") ? 3 : 2, child: signalSection),
                const SizedBox(height: 2.0),
                Expanded(flex: aspectRatioStr.contains("9:16") || aspectRatioStr.contains("3:4") ? 2 : 1, child: graphWidget),
            ],
        );
    }

    Widget _buildSignalGrid(
        SignalData? signal,
        String aspectRatioStr,
        String notation,
        bool smoothGaugeColor,
        String smoothGaugeCurve,
        double totalHeight,
        bool isLoggedIn,
        double totalWidth,
    ) {
        final is5gActive = signal?.nrRsrp != null && signal!.nrRsrp! < 0;
        final bool compactRefMetrics = (aspectRatioStr == '16:9' || aspectRatioStr == '4:3') && totalWidth < 320;

        switch (aspectRatioStr) {
            case '1:1':
                if (is5gActive) {
                    return _build5gSection(signal, notation, smoothGaugeColor, smoothGaugeCurve, isSingleMode: true, isLoggedIn: isLoggedIn, compactRefMetrics: compactRefMetrics);
                } else {
                    return _build4gSection(signal, notation, smoothGaugeColor, smoothGaugeCurve, isSingleMode: true, isLoggedIn: isLoggedIn, compactRefMetrics: compactRefMetrics);
                }
            case '16:9':
            case '4:3':
            case '21:9':
                return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                        Expanded(child: _build5gSection(signal, notation, smoothGaugeColor, smoothGaugeCurve, isLoggedIn: isLoggedIn, compactRefMetrics: compactRefMetrics)),
                        const SizedBox(width: 3.0),
                        Expanded(child: _build4gSection(signal, notation, smoothGaugeColor, smoothGaugeCurve, isLoggedIn: isLoggedIn, compactRefMetrics: compactRefMetrics)),
                    ],
                );
            case '9:16':
            case '3:4':
            case '9:21':
            default:
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                        Expanded(child: _build5gSection(signal, notation, smoothGaugeColor, smoothGaugeCurve, isLoggedIn: isLoggedIn, compactRefMetrics: compactRefMetrics)),
                        const SizedBox(height: 2.0),
                        Expanded(child: _build4gSection(signal, notation, smoothGaugeColor, smoothGaugeCurve, isLoggedIn: isLoggedIn, compactRefMetrics: compactRefMetrics)),
                    ],
                );
        }
    }

    Widget _build5gSection(
        SignalData? signal,
        String notation,
        bool smoothGaugeColor,
        String smoothGaugeCurve, {
        bool isSingleMode = false,
        bool isLoggedIn = false,
        bool compactRefMetrics = false,
    }) {
        final isSub6 = signal?.connectionMode == Fs050wConnectionMode.nr5gSub6;
        final genName = ConnectionModeHelper.getGenerationName(true, notation: notation);
        final titlePrefix = isSub6 ? "$genName+" : genName;
        final nrBandStr = isLoggedIn && (signal?.nrBand != null && signal!.nrBand! > 0) ? "n${signal!.nrBand}" : "--";
        final pciStr = isLoggedIn && (signal?.nrPci != null && signal!.nrPci! > 0) ? "${signal!.nrPci}" : "--";

        final fontSz = isSingleMode ? 10.5 : 8.5;

        return Container(
            padding: const EdgeInsets.symmetric(horizontal: 3.0, vertical: 2.0),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(3.5),
                border: Border.all(color: const Color(0xFF00ADB5).withOpacity(0.3), width: 0.6),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                    SizedBox(
                        height: 14,
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                                Expanded(
                                    flex: 3,
                                    child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                                isLoggedIn ? "$titlePrefix ($nrBandStr)" : titlePrefix,
                                                style: TextStyle(
                                                    fontFamilyFallback: const ['Noto Sans JP', 'sans-serif'],
                                                    fontSize: fontSz + 1.0,
                                                    fontWeight: FontWeight.bold,
                                                    color: const Color(0xFF00E5FF),
                                                ),
                                            ),
                                        ),
                                    ),
                                ),
                                if (isLoggedIn) ...[
                                    const SizedBox(width: 4),
                                    Expanded(
                                        flex: 2,
                                        child: Align(
                                            alignment: Alignment.centerRight,
                                            child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                alignment: Alignment.centerRight,
                                                child: Text(
                                                    "PCI: $pciStr",
                                                    style: TextStyle(
                                                        fontFamily: 'monospace',
                                                        fontSize: fontSz + 0.5,
                                                        color: Colors.white70,
                                                    ),
                                                ),
                                            ),
                                        ),
                                    ),
                                ],
                            ],
                        ),
                    ),
                    const SizedBox(height: 1.0),
                    Expanded(
                        flex: 3,
                        child: IntensityBarMetric(
                            label: "RSRP",
                            value: signal?.nrRsrp,
                            unit: "dBm",
                            minVal: ColorGauge.rsrpMin,
                            maxVal: ColorGauge.rsrpMax,
                            barColor: const Color(0xFF00ADB5),
                            height: null,
                            fontSize: fontSz + 0.5,
                            smoothGaugeColor: smoothGaugeColor,
                            smoothGaugeCurve: smoothGaugeCurve,
                        ),
                    ),
                    if (isLoggedIn) ...[
                        const SizedBox(height: 1.0),
                        Expanded(
                            flex: compactRefMetrics ? 3 : 2,
                            child: compactRefMetrics
                                ? _buildCompactRefMetrics(
                                    label1: "RQ",
                                    value1: signal?.nrRsrq,
                                    unit1: "dB",
                                    label2: "SNR",
                                    value2: signal?.nrSnr,
                                    unit2: "dB",
                                    fontSize: fontSz,
                                    accentColor: const Color(0xFF00ADB5),
                                )
                                : _buildRefMetricsRow(
                                    label1: "RQ",
                                    value1: signal?.nrRsrq,
                                    unit1: "dB",
                                    label2: "SNR",
                                    value2: signal?.nrSnr,
                                    unit2: "dB",
                                    fontSize: fontSz,
                                    accentColor: const Color(0xFF00ADB5),
                                ),
                        ),
                    ],
                ],
            ),
        );
    }

    Widget _build4gSection(
        SignalData? signal,
        String notation,
        bool smoothGaugeColor,
        String smoothGaugeCurve, {
        bool isSingleMode = false,
        bool isLoggedIn = false,
        bool compactRefMetrics = false,
    }) {
        final genName = ConnectionModeHelper.getGenerationName(false, notation: notation);
        final lteBandStr = isLoggedIn && (signal?.lteBand != null && signal!.lteBand! > 0) ? "B${signal!.lteBand}" : "--";
        final pciStr = isLoggedIn && (signal?.ltePci != null && signal!.ltePci! > 0) ? "${signal!.ltePci}" : "--";

        final fontSz = isSingleMode ? 10.5 : 8.5;

        return Container(
            padding: const EdgeInsets.symmetric(horizontal: 3.0, vertical: 2.0),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(3.5),
                border: Border.all(color: const Color(0xFF2196F3).withOpacity(0.3), width: 0.6),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                    SizedBox(
                        height: 14,
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                                Expanded(
                                    flex: 3,
                                    child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                                isLoggedIn ? "$genName ($lteBandStr)" : genName,
                                                style: TextStyle(
                                                    fontFamilyFallback: const ['Noto Sans JP', 'sans-serif'],
                                                    fontSize: fontSz + 1.0,
                                                    fontWeight: FontWeight.bold,
                                                    color: const Color(0xFF64B5F6),
                                                ),
                                            ),
                                        ),
                                    ),
                                ),
                                if (isLoggedIn) ...[
                                    const SizedBox(width: 4),
                                    Expanded(
                                        flex: 2,
                                        child: Align(
                                            alignment: Alignment.centerRight,
                                            child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                alignment: Alignment.centerRight,
                                                child: Text(
                                                    "PCI: $pciStr",
                                                    style: TextStyle(
                                                        fontFamily: 'monospace',
                                                        fontSize: fontSz + 0.5,
                                                        color: Colors.white70,
                                                    ),
                                                ),
                                            ),
                                        ),
                                    ),
                                ],
                            ],
                        ),
                    ),
                    const SizedBox(height: 1.0),
                    Expanded(
                        flex: 3,
                        child: IntensityBarMetric(
                            label: "RSRP",
                            value: signal?.lteRsrp,
                            unit: "dBm",
                            minVal: ColorGauge.rsrpMin,
                            maxVal: ColorGauge.rsrpMax,
                            barColor: const Color(0xFF2196F3),
                            height: null,
                            fontSize: fontSz + 0.5,
                            smoothGaugeColor: smoothGaugeColor,
                            smoothGaugeCurve: smoothGaugeCurve,
                        ),
                    ),
                    if (isLoggedIn) ...[
                        const SizedBox(height: 1.0),
                        Expanded(
                            flex: compactRefMetrics ? 3 : 2,
                            child: compactRefMetrics
                                ? _buildCompactRefMetrics(
                                    label1: "RQ",
                                    value1: signal?.lteRsrq,
                                    unit1: "dB",
                                    label2: "SINR",
                                    value2: signal?.lteSinr,
                                    unit2: "dB",
                                    fontSize: fontSz,
                                    accentColor: const Color(0xFF2196F3),
                                )
                                : _buildRefMetricsRow(
                                    label1: "RQ",
                                    value1: signal?.lteRsrq,
                                    unit1: "dB",
                                    label2: "SINR",
                                    value2: signal?.lteSinr,
                                    unit2: "dB",
                                    fontSize: fontSz,
                                    accentColor: const Color(0xFF2196F3),
                                ),
                        ),
                    ],
                ],
            ),
        );
    }

    /// RQ/SNR を縦積み (0.5行×1列) で表示するコンパクトレイアウト
    Widget _buildCompactRefMetrics({
        required String label1,
        required double? value1,
        required String unit1,
        required String label2,
        required double? value2,
        required String unit2,
        required double fontSize,
        required Color accentColor,
    }) {
        final level1 = label1 == "RQ" ? ColorGauge.rateRsrq(value1) : ColorGauge.rateSinr(value1);
        final level2 = (label2 == "SNR" || label2 == "SINR") ? ColorGauge.rateSinr(value2) : ColorGauge.rateRsrq(value2);

        return Column(
            children: [
                Expanded(
                    child: _buildMiniRefBox(
                        label: label1,
                        value: value1,
                        unit: unit1,
                        level: level1,
                        fontSize: fontSize - 0.5,
                    ),
                ),
                const SizedBox(height: 1.0),
                Expanded(
                    child: _buildMiniRefBox(
                        label: label2,
                        value: value2,
                        unit: unit2,
                        level: level2,
                        fontSize: fontSize - 0.5,
                    ),
                ),
            ],
        );
    }

    Widget _buildRefMetricsRow({
        required String label1,
        required double? value1,
        required String unit1,
        required String label2,
        required double? value2,
        required String unit2,
        required double fontSize,
        required Color accentColor,
    }) {
        final level1 = label1 == "RQ" ? ColorGauge.rateRsrq(value1) : ColorGauge.rateSinr(value1);
        final level2 = (label2 == "SNR" || label2 == "SINR") ? ColorGauge.rateSinr(value2) : ColorGauge.rateRsrq(value2);

        return Row(
            children: [
                Expanded(
                    child: _buildMiniRefBox(
                        label: label1,
                        value: value1,
                        unit: unit1,
                        level: level1,
                        fontSize: fontSize,
                    ),
                ),
                const SizedBox(width: 2.5),
                Expanded(
                    child: _buildMiniRefBox(
                        label: label2,
                        value: value2,
                        unit: unit2,
                        level: level2,
                        fontSize: fontSize,
                    ),
                ),
            ],
        );
    }

    Widget _buildMiniRefBox({
        required String label,
        required double? value,
        required String unit,
        required SignalRatingLevel level,
        required double fontSize,
    }) {
        final hasVal = value != null && !value.isNaN && value > -200;
        final color = hasVal ? ColorGauge.getColor(level) : Colors.white38;
        final valStr = hasVal
            ? "${value > 0 && (label == 'SNR' || label == 'SINR') ? '+' : ''}${value.toStringAsFixed(1)}"
            : "--";

        final double minVal = label == 'RQ' ? ColorGauge.rsrqMin : ColorGauge.sinrMin;
        final double maxVal = label == 'RQ' ? ColorGauge.rsrqMax : ColorGauge.sinrMax;
        final double ratio = hasVal ? ((value! - minVal) / (maxVal - minVal)).clamp(0.0, 1.0) : 0.0;

        return ClipRRect(
            borderRadius: BorderRadius.circular(3.0),
            child: Stack(
                fit: StackFit.passthrough,
                children: [
                    if (ratio > 0)
                        Positioned.fill(
                            child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: ratio,
                                child: Container(
                                    decoration: BoxDecoration(
                                        color: color.withOpacity(0.24),
                                    ),
                                ),
                            ),
                        ),
                    Container(
                        padding: const EdgeInsets.symmetric(horizontal: 3.5, vertical: 1.0),
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.035),
                            borderRadius: BorderRadius.circular(3.0),
                            border: Border.all(
                                color: (ratio > 0) ? color.withOpacity(0.35) : Colors.white.withOpacity(0.08),
                                width: 0.5,
                            ),
                        ),
                        child: Center(
                            child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.center,
                                child: Text.rich(
                                    TextSpan(
                                        children: [
                                            TextSpan(
                                                text: "$label ",
                                                style: TextStyle(
                                                    fontFamilyFallback: const ['Noto Sans JP', 'sans-serif'],
                                                    fontSize: fontSize,
                                                    color: Colors.white60,
                                                    fontWeight: FontWeight.w600,
                                                ),
                                            ),
                                            TextSpan(
                                                text: valStr,
                                                style: TextStyle(
                                                    fontFamily: 'monospace',
                                                    fontSize: fontSize + 0.5,
                                                    color: color,
                                                    fontWeight: FontWeight.bold,
                                                ),
                                            ),
                                        ],
                                    ),
                                ),
                            ),
                        ),
                    ),
                ],
            ),
        );
    }

    Widget _buildMiniGraph(
        BuildContext context,
        ApiService apiService,
        List<SignalData> history,
    ) {
        final graphType = apiService.settings.pipGraphType;
        final typeLabel = graphType == 'rsrp'
            ? "RSRP 履歴"
            : graphType == 'snr'
                ? "SNR / SINR 履歴"
                : "RSRQ 履歴";

        return GestureDetector(
            onTap: () {
                final nextType = graphType == 'rsrp'
                    ? 'snr'
                    : graphType == 'snr'
                        ? 'rsrq'
                        : 'rsrp';
                final updated = apiService.settings;
                updated.pipGraphType = nextType;
                apiService.updateSettings(updated);
                StorageService.saveSettings(updated);
            },
            child: Container(
                padding: const EdgeInsets.all(2.0),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(3.0),
                    border: Border.all(color: Colors.white12, width: 0.5),
                ),
                child: Stack(
                    children: [
                        Positioned.fill(
                            child: CustomPaint(
                                painter: PipMiniChartPainter(
                                    history: history,
                                    graphType: graphType,
                                ),
                            ),
                        ),
                        Positioned(
                            top: 2,
                            left: 4,
                            child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 3.0, vertical: 1.0),
                                decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(2.0),
                                ),
                                child: Text(
                                    "$typeLabel (タップで切替)",
                                    style: TextStyle(
                                        fontFamilyFallback: const ['Noto Sans JP', 'sans-serif'],
                                        fontSize: 7.0,
                                        color: Colors.white70,
                                    ),
                                ),
                            ),
                        ),
                    ],
                ),
            ),
        );
    }
}

class PipMiniChartPainter extends CustomPainter {
    final List<SignalData> history;
    final String graphType;

    PipMiniChartPainter({required this.history, required this.graphType});

    @override
    void paint(Canvas canvas, Size size) {
        if (history.length < 2 || size.width <= 0 || size.height <= 0) return;

        // 最大30点の最新データを取得
        final dataPoints = history.length > 30
            ? history.sublist(history.length - 30)
            : history;

        double minVal;
        double maxVal;

        if (graphType == 'rsrp') {
            minVal = -140.0;
            maxVal = -50.0;
        } else if (graphType == 'snr') {
            minVal = -10.0;
            maxVal = 30.0;
        } else {
            // rsrq
            minVal = -25.0;
            maxVal = -3.0;
        }

        // Auto scale if data points exceed default bounds
        double? dataMin;
        double? dataMax;
        for (final item in dataPoints) {
            double? v5;
            double? v4;
            if (graphType == 'rsrp') {
                v5 = item.nrRsrp;
                v4 = item.lteRsrp;
            } else if (graphType == 'snr') {
                v5 = item.nrSnr;
                v4 = item.lteSinr;
            } else {
                v5 = item.nrRsrq;
                v4 = item.lteRsrq;
            }
            if (v5 != null && !v5.isNaN && v5 > -200) {
                if (dataMin == null || v5 < dataMin) dataMin = v5;
                if (dataMax == null || v5 > dataMax) dataMax = v5;
            }
            if (v4 != null && !v4.isNaN && v4 > -200) {
                if (dataMin == null || v4 < dataMin) dataMin = v4;
                if (dataMax == null || v4 > dataMax) dataMax = v4;
            }
        }
        if (dataMin != null && dataMin < minVal) {
            minVal = dataMin - 2.0;
        }
        if (dataMax != null && dataMax > maxVal) {
            maxVal = dataMax + 2.0;
        }

        final p5g = Paint()
            ..color = const Color(0xFF00E5FF)
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke;

        final p4g = Paint()
            ..color = const Color(0xFF2196F3)
            ..strokeWidth = 1.2
            ..style = PaintingStyle.stroke;

        final gridPaint = Paint()
            ..color = Colors.white.withOpacity(0.06)
            ..strokeWidth = 0.5;

        // グリッド線
        canvas.drawLine(Offset(0, size.height * 0.5), Offset(size.width, size.height * 0.5), gridPaint);

        final path5g = Path();
        final path4g = Path();
        bool has5gStart = false;
        bool has4gStart = false;

        final stepX = size.width / (dataPoints.length - 1);

        for (int i = 0; i < dataPoints.length; i++) {
            final x = i * stepX;
            final item = dataPoints[i];

            final bool isTimeGap = i > 0 && item.timestamp.difference(dataPoints[i - 1].timestamp).inSeconds > 4;

            double? val5g;
            double? val4g;

            if (graphType == 'rsrp') {
                val5g = item.nrRsrp;
                val4g = item.lteRsrp;
            } else if (graphType == 'snr') {
                val5g = item.nrSnr;
                val4g = item.lteSinr;
            } else {
                val5g = item.nrRsrq;
                val4g = item.lteRsrq;
            }

            if (isTimeGap || val5g == null || val5g.isNaN || val5g <= -200) {
                has5gStart = false;
            } else {
                final normalized = ((val5g - minVal) / (maxVal - minVal)).clamp(0.0, 1.0);
                final y = size.height * (1.0 - normalized);
                if (!has5gStart) {
                    path5g.moveTo(x, y);
                    has5gStart = true;
                } else {
                    path5g.lineTo(x, y);
                }
            }

            if (isTimeGap || val4g == null || val4g.isNaN || val4g <= -200) {
                has4gStart = false;
            } else {
                final normalized = ((val4g - minVal) / (maxVal - minVal)).clamp(0.0, 1.0);
                final y = size.height * (1.0 - normalized);
                if (!has4gStart) {
                    path4g.moveTo(x, y);
                    has4gStart = true;
                } else {
                    path4g.lineTo(x, y);
                }
            }
        }

        canvas.drawPath(path4g, p4g);
        canvas.drawPath(path5g, p5g);
    }

    @override
    bool shouldRepaint(covariant PipMiniChartPainter oldDelegate) {
        return true;
    }
}
