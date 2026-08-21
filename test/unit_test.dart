import 'package:flutter_test/flutter_test.dart';
import 'package:fs050w_monitor/utils/calc_frequency.dart';
import 'package:fs050w_monitor/utils/crypto_utils.dart';
import 'package:fs050w_monitor/utils/color_gauge.dart';
import 'package:fs050w_monitor/models/signal_data.dart';
import 'package:fs050w_monitor/models/connection_state.dart';
import 'package:fs050w_monitor/models/app_settings.dart';
import 'package:fs050w_monitor/services/pip_service.dart';
import 'package:fs050w_monitor/views/widgets/intensity_bar_metric.dart';

void main() {
    group('3GPP Band Naming Tests', () {
        test('LTE Band 3 and 1 names', () {
            expect(FrequencyCalculator.getLteBandName(3), equals("B3 (1.7GHz帯)"));
            expect(FrequencyCalculator.getLteBandName(1), equals("B1 (2.1GHz帯)"));
        });

        test('5G sub6 and refarmed band names', () {
            expect(FrequencyCalculator.getNrBandName(77), equals("n77 (3.7GHz帯 sub6)"));
            expect(FrequencyCalculator.getNrBandName(28), equals("n28 (700MHz帯 転用5G)"));
            expect(FrequencyCalculator.isSub6Band(77), isTrue);
            expect(FrequencyCalculator.isSub6Band(28), isFalse);
        });
    });

    group('Challenge-Response Hash Calculation Tests', () {
        test('HMAC-MD5 and MD5 digest pipeline produces valid 32-char hex string', () {
            final hash = CryptoUtils.computeLoginPasswordHash('admin123', 'abcdef123456');
            expect(hash.length, equals(32));
            expect(RegExp(r'^[a-f0-9]{32}$').hasMatch(hash), isTrue);
        });
    });

    group('6-Tier Color Gauge Evaluation Tests', () {
        test('RSRP levels evaluation', () {
            expect(ColorGauge.rateRsrp(-75.0), equals(SignalRatingLevel.excellent));
            expect(ColorGauge.rateRsrp(-85.0), equals(SignalRatingLevel.good));
            expect(ColorGauge.rateRsrp(-95.0), equals(SignalRatingLevel.moderate));
            expect(ColorGauge.rateRsrp(-105.0), equals(SignalRatingLevel.weak));
            expect(ColorGauge.rateRsrp(-115.0), equals(SignalRatingLevel.veryWeak));
            expect(ColorGauge.rateRsrp(-125.0), equals(SignalRatingLevel.critical));
        });

        test('RSRQ levels evaluation', () {
            expect(ColorGauge.rateRsrq(-8.0), equals(SignalRatingLevel.excellent));
            expect(ColorGauge.rateRsrq(-10.0), equals(SignalRatingLevel.good));
            expect(ColorGauge.rateRsrq(-13.0), equals(SignalRatingLevel.moderate));
            expect(ColorGauge.rateRsrq(-16.0), equals(SignalRatingLevel.weak));
            expect(ColorGauge.rateRsrq(-18.5), equals(SignalRatingLevel.veryWeak));
            expect(ColorGauge.rateRsrq(-20.0), equals(SignalRatingLevel.critical));
        });

        test('SINR levels evaluation', () {
            expect(ColorGauge.rateSinr(25.0), equals(SignalRatingLevel.excellent));
            expect(ColorGauge.rateSinr(15.0), equals(SignalRatingLevel.good));
            expect(ColorGauge.rateSinr(8.0), equals(SignalRatingLevel.moderate));
            expect(ColorGauge.rateSinr(2.0), equals(SignalRatingLevel.weak));
            expect(ColorGauge.rateSinr(-5.0), equals(SignalRatingLevel.veryWeak));
            expect(ColorGauge.rateSinr(-15.0), equals(SignalRatingLevel.critical));
        });
    });

    group('SignalData Parsing and 6-Pattern Mode Determination Tests', () {
        test('Pattern 1: 4G LTE Single', () {
            final json = {
                'mnet_sysmode': 'lte',
                'mnet_operator_name': 'Rakuten',
                'mnet_rsrp': '68', // 68 - 141 = -73.0
                'mnet_wnw_band': '3',
                'mnet_wnw_pci': '315',
            };
            final data = SignalData.fromApiResponse(json, hasCa: false);
            expect(data.connectionMode, equals(Fs050wConnectionMode.lte));
            expect(data.lteRsrp, equals(-73.0));
            expect(data.lteBand, equals(3));
            expect(data.ltePci, equals(315));
        });

        test('Pattern 2: 4G+ LTE CA', () {
            final json = {
                'mnet_sysmode': 'lte',
                'mnet_operator_name': 'Rakuten',
                'mnet_rsrp': '68',
                'mnet_wnw_band': '3',
            };
            final data = SignalData.fromApiResponse(json, hasCa: true, caBands: ['B18']);
            expect(data.connectionMode, equals(Fs050wConnectionMode.lteCa));
            expect(data.hasCa, isTrue);
        });

        test('Pattern 3: 4GN 5G NSA Standby', () {
            final json = {
                'mnet_sysmode': 'nsa',
                'mnet_operator_name': 'Rakuten',
                'mnet_rsrp': '68',
                'mnet_endc_rsrp': '0', // 0 indicates standby
                'mnet_wnw_band': '3',
            };
            final data = SignalData.fromApiResponse(json, hasCa: false);
            expect(data.connectionMode, equals(Fs050wConnectionMode.nsaReady));
        });

        test('Pattern 4: 4GN+ 5G NSA Standby CA', () {
            final json = {
                'mnet_sysmode': 'nsa',
                'mnet_operator_name': 'Rakuten',
                'mnet_rsrp': '68',
                'mnet_endc_rsrp': '0',
                'mnet_wnw_band': '3',
            };
            final data = SignalData.fromApiResponse(json, hasCa: true);
            expect(data.connectionMode, equals(Fs050wConnectionMode.nsaReadyCa));
        });

        test('Pattern 5: 5G Refarmed (n28)', () {
            final json = {
                'mnet_sysmode': 'nsa',
                'mnet_operator_name': 'Rakuten',
                'mnet_rsrp': '68',
                'mnet_endc_rsrp': '68', // 68 - 157 = -89.0
                'mnet_wnw_psband': '28',
                'mnet_wnw_pspci': '454',
            };
            final data = SignalData.fromApiResponse(json);
            expect(data.connectionMode, equals(Fs050wConnectionMode.nr5g));
            expect(data.nrRsrp, equals(-89.0));
            expect(data.nrBand, equals(28));
        });

        test('Pattern 6: 5G+ sub6 (n77)', () {
            final json = {
                'mnet_sysmode': 'nsa',
                'mnet_operator_name': 'Rakuten',
                'mnet_rsrp': '68',
                'mnet_endc_rsrp': '68', // 68 - 157 = -89.0
                'mnet_endc_snr': '77', // (77 - 1) / 2 - 23 = 15.0
                'mnet_wnw_psband': '77',
                'mnet_wnw_pspci': '723',
            };
            final data = SignalData.fromApiResponse(json);
            expect(data.connectionMode, equals(Fs050wConnectionMode.nr5gSub6));
            expect(data.nrRsrp, equals(-89.0));
            expect(data.nrSnr, equals(15.0));
        });

        test('Handover Detection when PCI changes', () {
            final prevJson = {
                'mnet_sysmode': 'lte',
                'mnet_wnw_pci': '29',
                'mnet_wnw_band': '3',
            };
            final prevData = SignalData.fromApiResponse(prevJson);

            final nextJson = {
                'mnet_sysmode': 'lte',
                'mnet_wnw_pci': '57',
                'mnet_wnw_band': '3',
            };
            final nextData = SignalData.fromApiResponse(nextJson, previousData: prevData);

            expect(nextData.handoverDescription, equals("PCI 29 → 57 (B3)"));
        });
    });

    group('PiP Aspect Ratio & Clamping Tests', () {
        test('7 Supported Aspect Ratios Parsing and Values', () {
            expect(PipService.parseAspectRatio('16:9'), equals((16, 9)));
            expect(PipService.parseAspectRatio('9:16'), equals((9, 16)));
            expect(PipService.parseAspectRatio('1:1'), equals((1, 1)));
            expect(PipService.parseAspectRatio('4:3'), equals((4, 3)));
            expect(PipService.parseAspectRatio('3:4'), equals((3, 4)));
            expect(PipService.parseAspectRatio('21:9'), equals((21, 9)));
            expect(PipService.parseAspectRatio('9:21'), equals((9, 21)));

            // Verify ratio is within Android PiP limit (0.418 to 2.39)
            final minRatio = PipService.getAspectRatioValue('9:21');
            final maxRatio = PipService.getAspectRatioValue('21:9');
            expect(minRatio, greaterThan(0.418));
            expect(maxRatio, lessThan(2.39));
        });
    });

    group('Intensity Bar Normalization Tests', () {
        test('RSRP Normalization (-140 to -50 dBm)', () {
            expect(IntensityBarMetric.calculateNormalizedRatio(-140.0, -140.0, -50.0), equals(0.0));
            expect(IntensityBarMetric.calculateNormalizedRatio(-50.0, -140.0, -50.0), equals(1.0));
            expect(IntensityBarMetric.calculateNormalizedRatio(-95.0, -140.0, -50.0), closeTo(0.5, 0.001));
            expect(IntensityBarMetric.calculateNormalizedRatio(-150.0, -140.0, -50.0), equals(0.0));
            expect(IntensityBarMetric.calculateNormalizedRatio(-40.0, -140.0, -50.0), equals(1.0));
            expect(IntensityBarMetric.calculateNormalizedRatio(null, -140.0, -50.0), equals(0.0));
        });

        test('RSRQ Normalization (-25 to -3 dB)', () {
            expect(IntensityBarMetric.calculateNormalizedRatio(-25.0, -25.0, -3.0), equals(0.0));
            expect(IntensityBarMetric.calculateNormalizedRatio(-3.0, -25.0, -3.0), equals(1.0));
            expect(IntensityBarMetric.calculateNormalizedRatio(-14.0, -25.0, -3.0), equals(0.5));
            expect(IntensityBarMetric.calculateNormalizedRatio(null, -25.0, -3.0), equals(0.0));
        });

        test('SINR/SNR Normalization (-10 to 30 dB)', () {
            expect(IntensityBarMetric.calculateNormalizedRatio(-10.0, -10.0, 30.0), equals(0.0));
            expect(IntensityBarMetric.calculateNormalizedRatio(30.0, -10.0, 30.0), equals(1.0));
            expect(IntensityBarMetric.calculateNormalizedRatio(10.0, -10.0, 30.0), equals(0.5));
            expect(IntensityBarMetric.calculateNormalizedRatio(null, -10.0, 30.0), equals(0.0));
        });
    });

    group('AppSettings Serialization Tests', () {
        test('Full JSON Roundtrip with PiP, Overlay and Lamp fields', () {
            final original = AppSettings(
                routerIp: "192.168.100.1",
                webPassword: "secretPassword",
                autoPipOnHome: false,
                pipAspectRatio: "21:9",
                overlayEnabled: true,
                overlayStyle: "compact",
                overlayOpacity: 0.65,
                overlayScale: 1.25,
                eventLampEnabled: true,
                eventLampShape: "dot",
                eventLampPosition: "topRight",
                vibrateOn5gSub6: true,
                vibrateOnHandover: false,
                vibrateOnCriticalSignal: true,
            );

            final json = original.toJson();
            final restored = AppSettings.fromJson(json);

            expect(restored.routerIp, equals("192.168.100.1"));
            expect(restored.webPassword, equals("secretPassword"));
            expect(restored.autoPipOnHome, isFalse);
            expect(restored.pipAspectRatio, equals("21:9"));
            expect(restored.overlayEnabled, isTrue);
            expect(restored.overlayStyle, equals("compact"));
            expect(restored.overlayOpacity, equals(0.65));
            expect(restored.overlayScale, equals(1.25));
            expect(restored.eventLampEnabled, isTrue);
            expect(restored.eventLampShape, equals("dot"));
            expect(restored.eventLampPosition, equals("topRight"));
            expect(restored.vibrateOn5gSub6, isTrue);
            expect(restored.vibrateOnHandover, isFalse);
            expect(restored.vibrateOnCriticalSignal, isTrue);
        });
    });
}
