import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:fs050w_signal_display/models/app_settings.dart';
import 'package:fs050w_signal_display/models/connection_state.dart';
import 'package:fs050w_signal_display/models/signal_data.dart';
import 'package:fs050w_signal_display/services/api_service.dart';
import 'package:fs050w_signal_display/services/overlay_service.dart';
import 'dart:convert';
import 'package:fs050w_signal_display/utils/color_gauge.dart';
import 'package:fs050w_signal_display/views/graph_screen.dart';
import 'package:fs050w_signal_display/views/widgets/fs050w_app_bar.dart';

class DisplayApiService extends ApiService {
    DisplayApiService(this.samples) : super(AppSettings());

    final List<SignalData> samples;

    @override
    List<SignalData> get signalHistory => samples;

    @override
    SignalData? get currentSignal => samples.last;
}

void main() {
    TestWidgetsFlutterBinding.ensureInitialized();
    test('Overlay receives shared colors and actual battery level', () async {
        const channel = MethodChannel('com.syameimarukoa.fs050w_signal_display/overlay');
        Map<String, dynamic>? payload;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
                payload = jsonDecode(call.arguments['jsonData'] as String) as Map<String, dynamic>;
                return null;
            });
        addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null));
        final settings = AppSettings(overlayEnabled: true, smoothGaugeColor: true,
            batteryTempWarningThreshold: 48.0);
        final signal = SignalData.fromApiResponse({
            'mnet_rsrp': '90',
            'device_battery_exist': 'present',
            'device_battery_level_percent': '70',
            'device_charge_long_life': 'enable',
            'device_battery_temperature': '44',
        });
        await OverlayService.updateOverlayData(signal, settings);
        expect(payload?['batteryPercent'], 70);
        expect(payload?['lteRsrpColor'], ColorGauge.metricColor(signal.lteRsrp,
            ColorGauge.rateRsrp(signal.lteRsrp), ColorGauge.rsrpMin, ColorGauge.rsrpMax,
            smooth: true, curve: settings.smoothGaugeCurve).toARGB32());
        expect(payload?['batteryTemperatureColor'], const Color(0xFFFFD600).toARGB32());
        expect(payload?['lteRsrqColor'], ColorGauge.colorUnknown.toARGB32());
    });

    test('Unavailable signal values use the same unknown rating', () {
        for (final value in [null, double.nan, double.infinity, -200.0]) {
            expect(ColorGauge.rateRsrp(value), SignalRatingLevel.unknown);
            expect(ColorGauge.rateRsrq(value), SignalRatingLevel.unknown);
            expect(ColorGauge.rateSinr(value), SignalRatingLevel.unknown);
        }
        expect(ColorGauge.latencyColor(50), const Color(0xFF00E676));
        expect(ColorGauge.latencyColor(51), const Color(0xFFFFD600));
        expect(ColorGauge.latencyColor(150), const Color(0xFFFFD600));
        expect(ColorGauge.latencyColor(151), const Color(0xFFFF5252));
    });

    testWidgets('Router latency graph omits handover markers and expands its range', (tester) async {
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final now = DateTime.now();
        final samples = [
            SignalData.fromApiResponse({'mnet_rsrp': '80'}, routerLatencyMs: 20),
            SignalData(timestamp: now, sysmode: 'lte', operatorName: '--', connectionMode: Fs050wConnectionMode.disconnected, routerLatencyMs: 250, handoverDescription: '4G PCI 1 → 2'),
        ];
        await tester.pumpWidget(ChangeNotifierProvider<ApiService>(
            create: (_) => DisplayApiService(samples),
            child: const MaterialApp(home: GraphScreen()),
        ));
        expect(find.text('4. ルーター ping'), findsOneWidget);
        final charts = tester.widgetList<LineChart>(find.byType(LineChart)).toList();
        expect(charts, hasLength(4));
        expect(charts.last.data.extraLinesData.verticalLines, isEmpty);
        expect(charts.first.data.extraLinesData.verticalLines, hasLength(1));
        expect(charts.last.data.maxY, greaterThan(250));
        expect(charts.last.data.lineBarsData.single.spots.map((s) => s.y), [20, 250]);
        expect(tester.takeException(), isNull);
    });

    testWidgets('App bar displays actual battery level during long life charging', (tester) async {
        final signal = SignalData.fromApiResponse({
            'device_battery_exist': 'present',
            'device_battery_level_percent': '70',
            'device_charge_long_life': 'enable',
        });
        await tester.pumpWidget(ChangeNotifierProvider<ApiService>(
            create: (_) => DisplayApiService([signal]),
            child: const MaterialApp(home: Scaffold(appBar: Fs050wAppBar())),
        ));
        expect(find.text('70%'), findsOneWidget);
        expect(find.text('100%'), findsNothing);
        expect(signal.scaledBatteryPercent, 100);
        expect(tester.takeException(), isNull);
    });
}
