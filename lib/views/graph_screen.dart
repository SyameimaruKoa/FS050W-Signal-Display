import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../models/signal_data.dart';

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

        final now = DateTime.now();
        final cutoffTime = now.subtract(Duration(minutes: _selectedSpanMinutes));
        final filteredData = history.where((d) => d.timestamp.isAfter(cutoffTime)).toList();

        return Scaffold(
            appBar: AppBar(
                title: Text(
                    "📊 リアルタイム同期グラフ",
                    style: GoogleFonts.notoSansJp(fontWeight: FontWeight.bold, fontSize: 18),
                ),
            ),
            body: Column(
                children: [
                    _buildSpanSelector(),
                    Expanded(
                        child: filteredData.isEmpty
                            ? const Center(
                                child: Text(
                                    "データ蓄積中...",
                                    style: TextStyle(color: Colors.white54),
                                ),
                            )
                            : ListView(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                children: [
                                    _buildTierChart(
                                        title: "1. RSRP (電波受信強度)",
                                        unit: "dBm",
                                        minY: -140,
                                        maxY: -50,
                                        data: filteredData,
                                        cutoffTime: cutoffTime,
                                        totalSpanSeconds: _selectedSpanMinutes * 60.0,
                                        getY4g: (d) => d.lteRsrp,
                                        getY5g: (d) => d.nrRsrp,
                                    ),
                                    const SizedBox(height: 14),
                                    _buildTierChart(
                                        title: "2. RSRQ (受信信号品質)",
                                        unit: "dB",
                                        minY: -25,
                                        maxY: -3,
                                        data: filteredData,
                                        cutoffTime: cutoffTime,
                                        totalSpanSeconds: _selectedSpanMinutes * 60.0,
                                        getY4g: (d) => d.lteRsrq,
                                        getY5g: (d) => d.nrRsrq,
                                    ),
                                    const SizedBox(height: 14),
                                    _buildTierChart(
                                        title: "3. SINR / SNR (信号対雑音比)",
                                        unit: "dB",
                                        minY: -15,
                                        maxY: 35,
                                        hasZeroLine: true,
                                        data: filteredData,
                                        cutoffTime: cutoffTime,
                                        totalSpanSeconds: _selectedSpanMinutes * 60.0,
                                        getY4g: (d) => d.lteSinr,
                                        getY5g: (d) => d.nrSnr,
                                    ),
                                    const SizedBox(height: 16),
                                ],
                            ),
                    ),
                ],
            ),
        );
    }

    Widget _buildSpanSelector() {
        return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF1E1E1E),
            child: Row(
                children: [
                    const Text(
                        "表示スパン: ",
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [1, 3, 5, 10].map((span) {
                                final isSelected = _selectedSpanMinutes == span;
                                return Expanded(
                                    child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 3.0),
                                        child: InkWell(
                                            borderRadius: BorderRadius.circular(6),
                                            onTap: () {
                                                setState(() {
                                                    _selectedSpanMinutes = span;
                                                });
                                            },
                                            child: Container(
                                                padding: const EdgeInsets.symmetric(vertical: 7),
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                    color: isSelected ? const Color(0xFF00E5FF).withOpacity(0.2) : Colors.white.withOpacity(0.06),
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(
                                                        color: isSelected ? const Color(0xFF00E5FF) : Colors.white12,
                                                        width: 1.2,
                                                    ),
                                                ),
                                                child: Text(
                                                    "${span}分",
                                                    style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                        color: isSelected ? const Color(0xFF00E5FF) : Colors.white70,
                                                    ),
                                                ),
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
        required List<SignalData> data,
        required DateTime cutoffTime,
        required double totalSpanSeconds,
        required double? Function(SignalData) getY4g,
        required double? Function(SignalData) getY5g,
        bool hasZeroLine = false,
    }) {
        if (data.isEmpty) return const SizedBox.shrink();

        final List<FlSpot> spots4g = [];
        final List<FlSpot> spots5g = [];
        final List<VerticalLine> handoverLines = [];

        for (int i = 0; i < data.length; i++) {
            final sample = data[i];
            final x = sample.timestamp.difference(cutoffTime).inSeconds.toDouble().clamp(0.0, totalSpanSeconds);

            final y4g = getY4g(sample);
            if (y4g != null) {
                spots4g.add(FlSpot(x, y4g));
            }

            final y5g = getY5g(sample);
            if (y5g != null) {
                spots5g.add(FlSpot(x, y5g));
            }

            if (sample.handoverDescription != null) {
                handoverLines.add(
                    VerticalLine(
                        x: x,
                        color: Colors.yellowAccent,
                        strokeWidth: 1.5,
                        dashArray: [4, 4],
                        label: VerticalLineLabel(
                            show: true,
                            alignment: Alignment.topRight,
                            padding: const EdgeInsets.all(2),
                            style: const TextStyle(
                                color: Colors.yellowAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                            ),
                            labelResolver: (_) => sample.handoverDescription!,
                        ),
                    ),
                );
            }
        }

        final double maxX = max(totalSpanSeconds, 10.0);

        return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Colors.white12),
            ),
            color: const Color(0xFF1E1E1E),
            child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                                Text(
                                    title,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                    ),
                                ),
                                Row(
                                    children: [
                                        _buildLegendDot(const Color(0xFF2196F3), "4G"),
                                        const SizedBox(width: 10),
                                        _buildLegendDot(const Color(0xFF00E5FF), "5G"),
                                    ],
                                ),
                            ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                            height: 150,
                            child: LineChart(
                                LineChartData(
                                    minY: minY,
                                    maxY: maxY,
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
                                                return touchedSpots.map((barSpot) {
                                                    final is5g = barSpot.barIndex == 1;
                                                    return LineTooltipItem(
                                                        "${is5g ? '5G' : '4G'}: ${barSpot.y.toStringAsFixed(1)} $unit",
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
                                        getDrawingHorizontalLine: (val) {
                                            if (hasZeroLine && val == 0) {
                                                return const FlLine(
                                                    color: Colors.white54,
                                                    strokeWidth: 1.5,
                                                    dashArray: [5, 5],
                                                );
                                            }
                                            return const FlLine(color: Colors.white10, strokeWidth: 0.8);
                                        },
                                        getDrawingVerticalLine: (val) {
                                            return const FlLine(color: Colors.white10, strokeWidth: 0.8);
                                        },
                                    ),
                                    extraLinesData: ExtraLinesData(
                                        verticalLines: handoverLines,
                                    ),
                                    titlesData: FlTitlesData(
                                        leftTitles: AxisTitles(
                                            sideTitles: SideTitles(
                                                showTitles: true,
                                                reservedSize: 44,
                                                getTitlesWidget: (value, meta) {
                                                    return Container(
                                                        alignment: Alignment.centerRight,
                                                        padding: const EdgeInsets.only(right: 4),
                                                        child: Text(
                                                            "${value.toInt()}",
                                                            style: GoogleFonts.notoSansMono(
                                                                fontSize: 10,
                                                                color: Colors.white54,
                                                            ),
                                                        ),
                                                    );
                                                },
                                            ),
                                        ),
                                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false, reservedSize: 6)),
                                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                        bottomTitles: AxisTitles(
                                            sideTitles: SideTitles(
                                                showTitles: true,
                                                reservedSize: 22,
                                                interval: (maxX / 4).clamp(1.0, 300.0),
                                                getTitlesWidget: (value, meta) {
                                                    final sampleTime = cutoffTime.add(Duration(seconds: value.toInt()));
                                                    final minStr = sampleTime.minute.toString().padLeft(2, '0');
                                                    final secStr = sampleTime.second.toString().padLeft(2, '0');
                                                    return Text(
                                                        "$minStr:$secStr",
                                                        style: GoogleFonts.notoSansMono(
                                                            fontSize: 10,
                                                            color: Colors.white54,
                                                        ),
                                                    );
                                                },
                                            ),
                                        ),
                                    ),
                                    borderData: FlBorderData(
                                        show: true,
                                        border: Border.all(color: Colors.white24, width: 0.8),
                                    ),
                                    lineBarsData: [
                                        // 4G Line (Blue)
                                        LineChartBarData(
                                            spots: spots4g,
                                            isCurved: false,
                                            color: const Color(0xFF2196F3),
                                            barWidth: 2,
                                            dotData: const FlDotData(show: false),
                                        ),
                                        // 5G Line (Cyan)
                                        LineChartBarData(
                                            spots: spots5g,
                                            isCurved: false,
                                            color: const Color(0xFF00E5FF),
                                            barWidth: 2,
                                            dotData: const FlDotData(show: false),
                                        ),
                                    ],
                                ),
                            ),
                        ),
                    ],
                ),
            ),
        );
    }

    Widget _buildLegendDot(Color color, String label) {
        return Row(
            children: [
                Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
                Text(
                    label,
                    style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.bold),
                ),
            ],
        );
    }
}
