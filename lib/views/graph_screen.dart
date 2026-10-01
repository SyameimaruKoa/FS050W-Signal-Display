import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import '../models/signal_data.dart';
import '../models/connection_state.dart';
import '../utils/color_gauge.dart';
import 'widgets/fs050w_app_bar.dart';

class GraphScreen extends StatefulWidget {
    const GraphScreen({super.key});

    @override
    State<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends State<GraphScreen> {
    int _selectedSpanMinutes = 3;

    @override
    void initState() {
        super.initState();
        final settings = context.read<ApiService>().settings;
        _selectedSpanMinutes = settings.graphSpanMinutes;
    }

    @override
    Widget build(BuildContext context) {
        final apiService = context.watch<ApiService>();
        final history = apiService.signalHistory;
        final settings = apiService.settings;
        final notation = settings.generationNotation;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        final now = DateTime.now();
        final cutoffTime = now.subtract(Duration(minutes: _selectedSpanMinutes));

        // Include 1 point immediately before cutoff for seamless edge clipping
        final List<SignalData> chartData = [];
        final firstAfter = history.indexWhere((d) => d.timestamp.isAfter(cutoffTime));
        if (firstAfter > 0) {
            chartData.add(history[firstAfter - 1]);
            chartData.addAll(history.sublist(firstAfter));
        } else if (firstAfter == 0) {
            chartData.addAll(history);
        }

        return Scaffold(
            appBar: const Fs050wAppBar(),
            body: Column(
                children: [
                    _buildSpanSelector(isDark),
                    Expanded(
                        child: chartData.isEmpty
                            ? Center(
                                child: Text(
                                    "データ蓄積中...",
                                    style: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
                                ),
                            )
                            : LayoutBuilder(
                                builder: (context, constraints) {
                                    final availHeight = constraints.maxHeight;
                                    // 4カード分の隙間とパディングを考慮
                                    final idealCardHeight = (availHeight - 26) / 4.0;
                                    final bool canFitWithoutScroll = idealCardHeight >= 140.0;
                                    final cardHeight = canFitWithoutScroll ? idealCardHeight : 150.0;
                                    final physics = canFitWithoutScroll
                                        ? const NeverScrollableScrollPhysics()
                                        : const AlwaysScrollableScrollPhysics();

                                    return ListView(
                                        physics: physics,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        children: [
                                            _buildTierChart(
                                                title: "1. RSRP",
                                                unit: "dBm",
                                                minY: -130,
                                                maxY: -70,
                                                cardHeight: cardHeight,
                                                data: chartData,
                                                cutoffTime: cutoffTime,
                                                totalSpanSeconds: _selectedSpanMinutes * 60.0,
                                                intervalSeconds: settings.foregroundIntervalSeconds,
                                                getY4g: (d) => d.lteRsrp,
                                                getY5g: (d) => d.nrRsrp,
                                                isDark: isDark,
                                                notation: notation,
                                                thresholds: ColorGauge.rsrpThresholds,
                                            ),
                                            const SizedBox(height: 6),
                                            _buildTierChart(
                                                title: "2. RSRQ",
                                                unit: "dB",
                                                minY: -24,
                                                maxY: -8,
                                                cardHeight: cardHeight,
                                                data: chartData,
                                                cutoffTime: cutoffTime,
                                                totalSpanSeconds: _selectedSpanMinutes * 60.0,
                                                intervalSeconds: settings.foregroundIntervalSeconds,
                                                getY4g: (d) => d.lteRsrq,
                                                getY5g: (d) => d.nrRsrq,
                                                isDark: isDark,
                                                notation: notation,
                                                thresholds: ColorGauge.rsrqThresholds,
                                            ),
                                            const SizedBox(height: 6),
                                            _buildTierChart(
                                                title: "3. SNR / SINR",
                                                unit: "dB",
                                                minY: -10,
                                                maxY: 25,
                                                cardHeight: cardHeight,
                                                hasZeroLine: true,
                                                data: chartData,
                                                cutoffTime: cutoffTime,
                                                totalSpanSeconds: _selectedSpanMinutes * 60.0,
                                                intervalSeconds: settings.foregroundIntervalSeconds,
                                                getY4g: (d) => d.lteSinr,
                                                getY5g: (d) => d.nrSnr,
                                                isDark: isDark,
                                                notation: notation,
                                                thresholds: ColorGauge.sinrThresholds,
                                            ),
                                            const SizedBox(height: 6),
                                            _buildTierChart(
                                                title: "4. ルーター ping",
                                                unit: "ms",
                                                minY: 0,
                                                maxY: 100,
                                                cardHeight: cardHeight,
                                                data: chartData,
                                                cutoffTime: cutoffTime,
                                                totalSpanSeconds: _selectedSpanMinutes * 60.0,
                                                intervalSeconds: settings.foregroundIntervalSeconds,
                                                getY4g: (d) => d.routerLatencyMs?.toDouble(),
                                                getY5g: (d) => null,
                                                isDark: isDark,
                                                notation: notation,
                                                isRouterLatency: true,
                                            ),
                                        ],
                                    );
                                },
                            ),
                    ),
                ],
            ),
        );
    }

    Widget _buildSpanSelector(bool isDark) {
        return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade200,
            child: Row(
                children: [
                    Text(
                        "表示スパン: ",
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white70 : Colors.black87,
                        ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [1, 3, 5, 10].map((span) {
                                final isSelected = _selectedSpanMinutes == span;
                                final activeBg = isDark
                                    ? const Color(0xFF00E5FF).withOpacity(0.2)
                                    : const Color(0xFF00ADB5).withOpacity(0.15);
                                final inactiveBg = isDark
                                    ? Colors.white.withOpacity(0.06)
                                    : Colors.white;
                                final activeBorder = isDark ? const Color(0xFF00E5FF) : const Color(0xFF00ADB5);
                                final inactiveBorder = isDark ? Colors.white12 : Colors.black12;

                                return InkWell(
                                    onTap: () {
                                        setState(() {
                                            _selectedSpanMinutes = span;
                                        });
                                    },
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                        decoration: BoxDecoration(
                                            color: isSelected ? activeBg : inactiveBg,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                                color: isSelected ? activeBorder : inactiveBorder,
                                                width: isSelected ? 1.5 : 1.0,
                                            ),
                                        ),
                                        child: Text(
                                            "$span分",
                                            style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                color: isSelected
                                                    ? (isDark ? const Color(0xFF00E5FF) : const Color(0xFF007A78))
                                                    : (isDark ? Colors.white70 : Colors.black87),
                                            ),
                                        ),
                                    ),
                                );
                            }).toList(),
                        ),
                    ),
                ],
            ),
        );
    }

    Widget _buildTierChart({
        required String title,
        required String unit,
        required double minY,
        required double maxY,
        required double cardHeight,
        required List<SignalData> data,
        required DateTime cutoffTime,
        required double totalSpanSeconds,
        int intervalSeconds = 1,
        required double? Function(SignalData) getY4g,
        required double? Function(SignalData) getY5g,
        required bool isDark,
        required String notation,
        List<MetricThreshold>? thresholds,
        bool hasZeroLine = false,
        bool isRouterLatency = false,
    }) {
        if (data.isEmpty) return const SizedBox.shrink();

        final label4g = isRouterLatency ? "ルーター" : ConnectionModeHelper.getGenerationName(false, notation: notation);
        final label5g = ConnectionModeHelper.getGenerationName(true, notation: notation);

        // 圏外やスリープ空白で線が繋がらないようセグメント（List<List<FlSpot>>）に分割
        final List<List<FlSpot>> segments4g = [];
        final List<List<FlSpot>> segments5g = [];
        List<FlSpot> currentSeg4g = [];
        List<FlSpot> currentSeg5g = [];

        final List<VerticalLine> handoverLines = [];
        final double maxGapSeconds = max(intervalSeconds * 2.5, 8.0);

        for (int i = 0; i < data.length; i++) {
            final sample = data[i];
            final x = sample.timestamp.difference(cutoffTime).inMilliseconds / 1000.0;

            final isTimeGap = i > 0 && sample.timestamp.difference(data[i - 1].timestamp).inSeconds > maxGapSeconds;

            final y4g = getY4g(sample);
            if (isTimeGap || y4g == null || y4g.isNaN || y4g <= -200) {
                if (currentSeg4g.isNotEmpty) {
                    segments4g.add(currentSeg4g);
                    currentSeg4g = [];
                }
            } else {
                currentSeg4g.add(FlSpot(x, y4g));
            }

            final y5g = getY5g(sample);
            if (isTimeGap || y5g == null || y5g.isNaN || y5g <= -200) {
                if (currentSeg5g.isNotEmpty) {
                    segments5g.add(currentSeg5g);
                    currentSeg5g = [];
                }
            } else {
                currentSeg5g.add(FlSpot(x, y5g));
            }

            // Handover marker: vertical dashed line only
            if (!isRouterLatency && sample.handoverDescription != null) {
                handoverLines.add(
                    VerticalLine(
                        x: x,
                        color: Colors.yellowAccent,
                        strokeWidth: 1.5,
                        dashArray: [4, 4],
                    ),
                );
            }
        }

        if (currentSeg4g.isNotEmpty) segments4g.add(currentSeg4g);
        if (currentSeg5g.isNotEmpty) segments5g.add(currentSeg5g);

        final double maxX = max(totalSpanSeconds, 10.0);

        // Auto scale if data points exceed default minY / maxY
        double effectiveMinY = minY;
        double effectiveMaxY = maxY;

        double? dataMin;
        double? dataMax;

        for (final seg in segments4g) {
            for (final spot in seg) {
                if (dataMin == null || spot.y < dataMin) dataMin = spot.y;
                if (dataMax == null || spot.y > dataMax) dataMax = spot.y;
            }
        }
        for (final seg in segments5g) {
            for (final spot in seg) {
                if (dataMin == null || spot.y < dataMin) dataMin = spot.y;
                if (dataMax == null || spot.y > dataMax) dataMax = spot.y;
            }
        }

        if (dataMin != null && dataMin < minY) {
            final diff = minY - dataMin;
            effectiveMinY = minY - (diff + 2.0).ceilToDouble();
        }
        if (dataMax != null && dataMax > maxY) {
            final diff = dataMax - maxY;
            effectiveMaxY = maxY + (diff + 2.0).ceilToDouble();
        }

        // 各セグメントを LineChartBarData に変換
        final List<LineChartBarData> lineBarsData = [];
        for (final seg in segments4g) {
            lineBarsData.add(
                LineChartBarData(
                    spots: seg,
                    isCurved: false,
                    color: const Color(0xFF2196F3),
                    barWidth: 2,
                    dotData: FlDotData(
                        show: true,
                        checkToShowDot: (spot, barData) => barData.spots.length == 1,
                        getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                            radius: 3,
                            color: const Color(0xFF2196F3),
                            strokeWidth: 0,
                        ),
                    ),
                ),
            );
        }
        for (final seg in segments5g) {
            lineBarsData.add(
                LineChartBarData(
                    spots: seg,
                    isCurved: false,
                    color: const Color(0xFF00ADB5),
                    barWidth: 2,
                    dotData: FlDotData(
                        show: true,
                        checkToShowDot: (spot, barData) => barData.spots.length == 1,
                        getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                            radius: 3,
                            color: const Color(0xFF00ADB5),
                            strokeWidth: 0,
                        ),
                    ),
                ),
            );
        }

        // 閾値に応じた色付きの水平ガイドライン
        final List<HorizontalLine> horizontalThresholdLines = [];
        if (thresholds != null) {
            for (final t in thresholds) {
                horizontalThresholdLines.add(
                    HorizontalLine(
                        y: t.value,
                        color: t.color.withOpacity(0.45),
                        strokeWidth: 1.0,
                        dashArray: [4, 4],
                    ),
                );
            }
        }

        // チャート本体の高さはカード高さからヘッダー・パディング分を引いた値
        final chartHeight = max(60.0, cardHeight - 48.0);

        return Card(
            elevation: isDark ? 2 : 1,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
            ),
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                                Text(
                                    title,
                                    style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : Colors.black87,
                                    ),
                                ),
                                Row(
                                    children: [
                                        _buildLegendDot(const Color(0xFF2196F3), label4g, isDark),
                                        if (!isRouterLatency) ...[
                                            const SizedBox(width: 8),
                                            _buildLegendDot(const Color(0xFF00ADB5), label5g, isDark),
                                        ],
                                    ],
                                ),
                            ],
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                            height: chartHeight,
                            child: LineChart(
                                LineChartData(
                                    minY: effectiveMinY,
                                    maxY: effectiveMaxY,
                                    minX: 0,
                                    maxX: maxX,
                                    clipData: const FlClipData.all(),
                                    lineTouchData: LineTouchData(
                                        enabled: true,
                                        handleBuiltInTouches: true,
                                        touchTooltipData: LineTouchTooltipData(
                                            fitInsideHorizontally: true,
                                            fitInsideVertically: true,
                                            tooltipRoundedRadius: 6,
                                            getTooltipItems: (List<LineBarSpot> touchedSpots) {
                                                if (touchedSpots.isEmpty) return [];
                                                final sampleTime = cutoffTime.add(
                                                    Duration(milliseconds: (touchedSpots.first.x * 1000).round()),
                                                );
                                                final timeStr = "${sampleTime.hour.toString().padLeft(2, '0')}:${sampleTime.minute.toString().padLeft(2, '0')}:${sampleTime.second.toString().padLeft(2, '0')}";

                                                return touchedSpots.map((barSpot) {
                                                    final is5g = barSpot.bar.color == const Color(0xFF00ADB5);
                                                    return LineTooltipItem(
                                                        "[$timeStr]\n${is5g ? label5g : label4g}: ${barSpot.y.toStringAsFixed(1)} $unit",
                                                        TextStyle(
                                                            color: is5g ? const Color(0xFF00E5FF) : const Color(0xFF2196F3),
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 11,
                                                        ),
                                                    );
                                                }).toList();
                                            },
                                        ),
                                    ),
                                    gridData: FlGridData(
                                        show: true,
                                        drawVerticalLine: true,
                                        drawHorizontalLine: thresholds == null,
                                        getDrawingHorizontalLine: (val) {
                                            if (hasZeroLine && val == 0) {
                                                return FlLine(
                                                    color: isDark ? Colors.white54 : Colors.black45,
                                                    strokeWidth: 1.5,
                                                    dashArray: [5, 5],
                                                );
                                            }
                                            return FlLine(
                                                color: isDark ? Colors.white10 : Colors.black12,
                                                strokeWidth: 0.8,
                                            );
                                        },
                                        getDrawingVerticalLine: (val) {
                                            return FlLine(
                                                color: isDark ? Colors.white10 : Colors.black12,
                                                strokeWidth: 0.8,
                                            );
                                        },
                                    ),
                                    extraLinesData: ExtraLinesData(
                                        verticalLines: handoverLines,
                                        horizontalLines: horizontalThresholdLines,
                                    ),
                                    titlesData: FlTitlesData(
                                        leftTitles: AxisTitles(
                                            sideTitles: SideTitles(
                                                showTitles: true,
                                                reservedSize: 32,
                                                interval: isRouterLatency ? max(1.0, (effectiveMaxY / 4).ceilToDouble()) : 1.0,
                                                getTitlesWidget: (value, meta) {
                                                    if (thresholds != null) {
                                                        MetricThreshold? matched;
                                                        for (final t in thresholds) {
                                                            if ((t.value - value).abs() < 0.1) {
                                                                matched = t;
                                                                break;
                                                            }
                                                        }
                                                        if (matched != null) {
                                                            return Container(
                                                                alignment: Alignment.centerRight,
                                                                padding: const EdgeInsets.only(right: 3),
                                                                child: Text(
                                                                    "${matched.value.toInt()}",
                                                                    style: TextStyle(
                                                                        fontSize: 9.5,
                                                                        fontWeight: FontWeight.bold,
                                                                        color: matched.color,
                                                                    ),
                                                                ),
                                                            );
                                                        }
                                                        return const SizedBox.shrink();
                                                    }
                                                    return Container(
                                                        alignment: Alignment.centerRight,
                                                        padding: const EdgeInsets.only(right: 2),
                                                        child: Text(
                                                            "${value.toInt()}",
                                                            style: TextStyle(
                                                                fontSize: 9,
                                                                color: isDark ? Colors.white54 : Colors.black54,
                                                            ),
                                                        ),
                                                    );
                                                },
                                            ),
                                        ),
                                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false, reservedSize: 4)),
                                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                        bottomTitles: AxisTitles(
                                            sideTitles: SideTitles(
                                                showTitles: true,
                                                reservedSize: 18,
                                                interval: (maxX / 4).clamp(1.0, 300.0),
                                                getTitlesWidget: (value, meta) {
                                                    final diffSec = (maxX - value).round();
                                                    if (diffSec <= 2) {
                                                        return Text(
                                                            "現在",
                                                            style: TextStyle(
                                                                fontSize: 9,
                                                                fontWeight: FontWeight.bold,
                                                                color: isDark ? Colors.white70 : Colors.black87,
                                                            ),
                                                        );
                                                    }
                                                    final min = diffSec ~/ 60;
                                                    final sec = diffSec % 60;
                                                    String label;
                                                    if (min > 0 && sec == 0) {
                                                        label = "-${min}分";
                                                    } else if (min > 0) {
                                                        label = "-${min}分${sec}秒";
                                                    } else {
                                                        label = "-${sec}秒";
                                                    }
                                                    return Text(
                                                        label,
                                                        style: TextStyle(
                                                            fontSize: 9,
                                                            color: isDark ? Colors.white54 : Colors.black54,
                                                        ),
                                                    );
                                                },
                                            ),
                                        ),
                                    ),
                                    borderData: FlBorderData(
                                        show: true,
                                        border: Border.all(
                                            color: isDark ? Colors.white24 : Colors.black26,
                                            width: 0.8,
                                        ),
                                    ),
                                    lineBarsData: lineBarsData,
                                ),
                                duration: Duration.zero,
                            ),
                        ),
                    ],
                ),
            ),
        );
    }

    Widget _buildLegendDot(Color color, String label, bool isDark) {
        return Row(
            children: [
                Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
                Text(
                    label,
                    style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white70 : Colors.black87,
                        fontWeight: FontWeight.bold,
                    ),
                ),
            ],
        );
    }
}
