import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

                    // 拡大判定: グラフ表示設定かつ十分な領域がある場合
                    final showGraph = settings.pipGraphType != 'none' &&
                        history.length >= 2 &&
                        (height >= 140 || (width >= 240 && height >= 100));

                    return Container(
                        color: Colors.black,
                        width: width,
                        height: height,
                        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 3.0),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                                _buildHeader(context, apiService, signal, isConnecting, aspectRatioStr),
                                const SizedBox(height: 3.0),
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
            padding: EdgeInsets.symmetric(horizontal: 5.0, vertical: is1to1 ? 3.0 : 2.0),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(4.0),
            ),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                    Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.5),
                        decoration: BoxDecoration(
                            color: isConnecting ? Colors.amber.withOpacity(0.25) : const Color(0xFF00E5FF).withOpacity(0.25),
                            borderRadius: BorderRadius.circular(3.0),
                        ),
                        child: Text(
                            isConnecting ? "[ 接続中... ]" : "[ $modeBadge ]",
                            style: GoogleFonts.notoSansJp(
                                fontSize: is1to1 ? 11.0 : 9.5,
                                fontWeight: FontWeight.bold,
                                color: isConnecting ? Colors.amberAccent : const Color(0xFF00E5FF),
                            ),
                        ),
                    ),
                    Text(
                        opName,
                        style: GoogleFonts.notoSansJp(
                            fontSize: is1to1 ? 11.0 : 9.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white70,
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
    ) {
        final notation = apiService.settings.generationNotation;
        final smooth = apiService.settings.smoothGaugeColor;
        final curve = apiService.settings.smoothGaugeCurve;
        final signalSection = _buildSignalGrid(signal, aspectRatioStr, notation, smooth, curve, height);

        if (!showGraph) {
            return signalSection;
        }

        // グラフを表示する場合のレイアウト
        final graphWidget = _buildMiniGraph(context, apiService, history);

        return Column(
            children: [
                Expanded(flex: aspectRatioStr.contains("9:16") || aspectRatioStr.contains("3:4") ? 3 : 2, child: signalSection),
                const SizedBox(height: 3.0),
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
    ) {
        final is5gActive = signal?.nrRsrp != null && signal!.nrRsrp! < 0;

        switch (aspectRatioStr) {
            case '1:1':
                // 1:1 は 4G/5G の片方のみ大画面表示 (5G 接続中は 5G、圏外時は 4G)
                if (is5gActive) {
                    return _build5gSection(signal, notation, smoothGaugeColor, smoothGaugeCurve, isSingleMode: true);
                } else {
                    return _build4gSection(signal, notation, smoothGaugeColor, smoothGaugeCurve, isSingleMode: true);
                }
            case '16:9':
            case '4:3':
            case '21:9':
                return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                        Expanded(child: _build5gSection(signal, notation, smoothGaugeColor, smoothGaugeCurve)),
                        const SizedBox(width: 4.0),
                        Expanded(child: _build4gSection(signal, notation, smoothGaugeColor, smoothGaugeCurve)),
                    ],
                );
            case '9:16':
            case '3:4':
            case '9:21':
            default:
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                        Expanded(child: _build5gSection(signal, notation, smoothGaugeColor, smoothGaugeCurve)),
                        const SizedBox(height: 3.0),
                        Expanded(child: _build4gSection(signal, notation, smoothGaugeColor, smoothGaugeCurve)),
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
    }) {
        final isSub6 = signal?.connectionMode == Fs050wConnectionMode.nr5gSub6;
        final genName = ConnectionModeHelper.getGenerationName(true, notation: notation);
        final titlePrefix = isSub6 ? "$genName+" : genName;
        final nrBandStr = signal?.nrBand != null ? "n${signal!.nrBand}" : "--";
        final pciStr = signal?.nrPci != null ? "${signal!.nrPci}" : "--";

        final barH = isSingleMode ? 22.0 : 13.0;
        final fontSz = isSingleMode ? 10.5 : 8.5;

        return Container(
            padding: EdgeInsets.all(isSingleMode ? 4.0 : 3.0),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(4.0),
                border: Border.all(color: const Color(0xFF00ADB5).withOpacity(0.3), width: 0.8),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                            Text(
                                "$titlePrefix ($nrBandStr)",
                                style: GoogleFonts.notoSansJp(
                                    fontSize: fontSz + 1.0,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF00E5FF),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                                "PCI: $pciStr",
                                style: GoogleFonts.notoSansMono(
                                    fontSize: fontSz + 0.5,
                                    color: Colors.white70,
                                ),
                            ),
                        ],
                    ),
                    IntensityBarMetric(
                        label: "RSRP",
                        value: signal?.nrRsrp,
                        unit: "dBm",
                        minVal: ColorGauge.rsrpMin,
                        maxVal: ColorGauge.rsrpMax,
                        barColor: const Color(0xFF00ADB5),
                        height: barH,
                        fontSize: fontSz,
                        smoothGaugeColor: smoothGaugeColor,
                        smoothGaugeCurve: smoothGaugeCurve,
                    ),
                    IntensityBarMetric(
                        label: "RSRQ",
                        value: signal?.nrRsrq,
                        unit: "dB",
                        minVal: ColorGauge.rsrqMin,
                        maxVal: ColorGauge.rsrqMax,
                        barColor: const Color(0xFF00ADB5),
                        height: barH,
                        fontSize: fontSz,
                        smoothGaugeColor: smoothGaugeColor,
                        smoothGaugeCurve: smoothGaugeCurve,
                    ),
                    IntensityBarMetric(
                        label: "SNR",
                        value: signal?.nrSnr,
                        unit: "dB",
                        minVal: ColorGauge.sinrMin,
                        maxVal: ColorGauge.sinrMax,
                        barColor: const Color(0xFF00ADB5),
                        height: barH,
                        fontSize: fontSz,
                        smoothGaugeColor: smoothGaugeColor,
                        smoothGaugeCurve: smoothGaugeCurve,
                    ),
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
    }) {
        final genName = ConnectionModeHelper.getGenerationName(false, notation: notation);
        final lteBandStr = signal?.lteBand != null ? "B${signal!.lteBand}" : "--";
        final pciStr = signal?.ltePci != null ? "${signal!.ltePci}" : "--";

        final barH = isSingleMode ? 22.0 : 13.0;
        final fontSz = isSingleMode ? 10.5 : 8.5;

        return Container(
            padding: EdgeInsets.all(isSingleMode ? 4.0 : 3.0),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(4.0),
                border: Border.all(color: const Color(0xFF2196F3).withOpacity(0.3), width: 0.8),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                            Text(
                                "$genName ($lteBandStr)",
                                style: GoogleFonts.notoSansJp(
                                    fontSize: fontSz + 1.0,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF64B5F6),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                                "PCI: $pciStr",
                                style: GoogleFonts.notoSansMono(
                                    fontSize: fontSz + 0.5,
                                    color: Colors.white70,
                                ),
                            ),
                        ],
                    ),
                    IntensityBarMetric(
                        label: "RSRP",
                        value: signal?.lteRsrp,
                        unit: "dBm",
                        minVal: ColorGauge.rsrpMin,
                        maxVal: ColorGauge.rsrpMax,
                        barColor: const Color(0xFF2196F3),
                        height: barH,
                        fontSize: fontSz,
                        smoothGaugeColor: smoothGaugeColor,
                        smoothGaugeCurve: smoothGaugeCurve,
                    ),
                    IntensityBarMetric(
                        label: "RSRQ",
                        value: signal?.lteRsrq,
                        unit: "dB",
                        minVal: ColorGauge.rsrqMin,
                        maxVal: ColorGauge.rsrqMax,
                        barColor: const Color(0xFF2196F3),
                        height: barH,
                        fontSize: fontSz,
                        smoothGaugeColor: smoothGaugeColor,
                        smoothGaugeCurve: smoothGaugeCurve,
                    ),
                    IntensityBarMetric(
                        label: "SINR",
                        value: signal?.lteSinr,
                        unit: "dB",
                        minVal: ColorGauge.sinrMin,
                        maxVal: ColorGauge.sinrMax,
                        barColor: const Color(0xFF2196F3),
                        height: barH,
                        fontSize: fontSz,
                        smoothGaugeColor: smoothGaugeColor,
                        smoothGaugeCurve: smoothGaugeCurve,
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
                // タップでグラフ種類をサイクル切り替え
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
                    borderRadius: BorderRadius.circular(4.0),
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
                                    style: GoogleFonts.notoSansJp(
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

        final double minVal;
        final double maxVal;

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

            // 前のデータ点との時間差が4秒以上ある場合は途切れとみなす
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
