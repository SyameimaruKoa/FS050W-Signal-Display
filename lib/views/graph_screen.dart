import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
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

        final cutoffTime = DateTime.now().subtract(Duration(minutes: _selectedSpanMinutes));
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white.withOpacity(0.03),
            child: Row(
                children: [
                    const Text(
                        "表示スパン: ",
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70),
                    ),
                    const SizedBox(width: 8),
                    for (final span in [1, 3, 5, 10]) ...[
                        Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: ChoiceChip(
                                label: Text("${span}分"),
                                selected: _selectedSpanMinutes == span,
                                onSelected: (selected) {
                                    if (selected) {
                                        setState(() {
                                            _selectedSpanMinutes = span;
                                        });
                                    }
                                },
                            ),
                        ),
                    ],
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
        required double? Function(SignalData) getY4g,
        required double? Function(SignalData) getY5g,
        bool hasZeroLine = false,
    }) {
        if (data.isEmpty) return const SizedBox.shrink();

        final startTime = data.first.timestamp;
        final List<FlSpot> spots4g = [];
        final List<FlSpot> spots5g = [];
        final List<VerticalLine> handoverLines = [];

        for (int i = 0; i < data.length; i++) {
            final sample = data[i];
            final x = sample.timestamp.difference(startTime).inSeconds.toDouble();

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

        final double maxX = data.last.timestamp.difference(startTime).inSeconds.toDouble().clamp(10.0, 600.0);

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
                                                reservedSize: 38,
                                                getTitlesWidget: (value, meta) {
                                                    return Text(
                                                        "${value.toInt()}",
                                                        style: GoogleFonts.notoSansMono(
                                                            fontSize: 10,
                                                            color: Colors.white54,
                                                        ),
                                                    );
                                                },
                                            ),
                                        ),
                                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                        bottomTitles: AxisTitles(
                                            sideTitles: SideTitles(
                                                showTitles: true,
                                                reservedSize: 20,
                                                interval: (maxX / 4).clamp(1.0, 300.0),
                                                getTitlesWidget: (value, meta) {
                                                    final sampleTime = startTime.add(Duration(seconds: value.toInt()));
                                                    return Text(
                                                        DateFormat("mm:ss").format(sampleTime),
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
                                        // 4G Line (Blue, sharp oscilloscope step/straight style)
                                        LineChartBarData(
                                            spots: spots4g,
                                            isCurved: false,
                                            color: const Color(0xFF2196F3),
                                            barWidth: 2,
                                            dotData: const FlDotData(show: false),
                                        ),
                                        // 5G Line (Cyan, sharp oscilloscope step/straight style)
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
