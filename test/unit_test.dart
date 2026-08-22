import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:fs050w_monitor/utils/calc_frequency.dart';
import 'package:fs050w_monitor/utils/crypto_utils.dart';
import 'package:fs050w_monitor/utils/color_gauge.dart';
import 'package:fs050w_monitor/models/signal_data.dart';
import 'package:fs050w_monitor/models/connection_state.dart';
import 'package:fs050w_monitor/models/app_settings.dart';
import 'package:fs050w_monitor/services/pip_service.dart';
import 'package:fs050w_monitor/views/widgets/intensity_bar_metric.dart';

void main() {
    group('3GPP & Rakuten Specific Band Naming and Badge Tests', () {
        test('Standard LTE & 5G Band Names', () {
            expect(FrequencyCalculator.getLteBandName(3), equals("B3 (1.7GHz)"));
            expect(FrequencyCalculator.getLteBandName(1), equals("B1 (2.1GHz)"));
            expect(FrequencyCalculator.getLteBandName(18), equals("B18 (800MHz)"));
            expect(FrequencyCalculator.getLteBandName(41), equals("B41 (2.5GHz)"));
            expect(FrequencyCalculator.getNrBandName(77), equals("n77 (3.8GHz)"));
            expect(FrequencyCalculator.getNrBandName(28), equals("n28 (700MHz)"));
            expect(FrequencyCalculator.isSub6Band(77), isTrue);
            expect(FrequencyCalculator.isSub6Band(28), isFalse);
        });

        test('Rakuten and General Badge Tests', () {
            expect(FrequencyCalculator.getLteBadgeText(3, operatorName: "Rakuten"), equals("楽天回線"));
            expect(FrequencyCalculator.getLteBadgeText(18, operatorName: "Rakuten"), equals("auローミング"));
            expect(FrequencyCalculator.getLteBadgeText(28, operatorName: "Rakuten"), equals("楽天プラチナ"));
            expect(FrequencyCalculator.getLteBadgeText(1), equals("FDD"));
            expect(FrequencyCalculator.getLteBadgeText(19), equals("プラチナ"));
            expect(FrequencyCalculator.getLteBadgeText(41), equals("TDD"));

            expect(FrequencyCalculator.getNrBadgeText(77), equals("Sub6"));
            expect(FrequencyCalculator.getNrBadgeText(28), equals("転用5G"));
        });
    });

    group('Challenge-Response Hash Calculation Tests', () {
        test('HMAC-MD5 and MD5 digest pipeline produces valid 32-char hex string', () {
            final hash = CryptoUtils.computeLoginPasswordHash('admin123', 'abcdef123456');
            expect(hash.length, equals(32));
            expect(RegExp(r'^[a-f0-9]{32}$').hasMatch(hash), isTrue);
        });
    });

    group('6-Tier Color Gauge and Smooth Color Tests', () {
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
            expect(ColorGauge.rateRsrq(-12.0), equals(SignalRatingLevel.good));
            expect(ColorGauge.rateRsrq(-16.0), equals(SignalRatingLevel.moderate));
            expect(ColorGauge.rateRsrq(-19.0), equals(SignalRatingLevel.weak));
            expect(ColorGauge.rateRsrq(-21.0), equals(SignalRatingLevel.veryWeak));
            expect(ColorGauge.rateRsrq(-23.0), equals(SignalRatingLevel.critical));
        });

        test('SINR levels evaluation', () {
            expect(ColorGauge.rateSinr(25.0), equals(SignalRatingLevel.excellent));
            expect(ColorGauge.rateSinr(15.0), equals(SignalRatingLevel.good));
            expect(ColorGauge.rateSinr(5.0), equals(SignalRatingLevel.moderate));
            expect(ColorGauge.rateSinr(-1.0), equals(SignalRatingLevel.weak));
            expect(ColorGauge.rateSinr(-4.5), equals(SignalRatingLevel.veryWeak));
            expect(ColorGauge.rateSinr(-8.0), equals(SignalRatingLevel.critical));
        });

        test('Smooth color interpolation returns valid non-null colors', () {
            expect(ColorGauge.getSmoothColor(0.0), isA<Color>());
            expect(ColorGauge.getSmoothColor(0.5), isA<Color>());
            expect(ColorGauge.getSmoothColor(1.0), isA<Color>());
        });
    });

    group('Notation Toggle Tests (4G/5G vs LTE/NR)', () {
        test('4G/5G Notation Mode', () {
            expect(ConnectionModeHelper.getIconBadgeText(Fs050wConnectionMode.lte, notation: "4g_5g"), equals("4G"));
            expect(ConnectionModeHelper.getIconBadgeText(Fs050wConnectionMode.nr5gSub6, notation: "4g_5g"), equals("5G+"));
            expect(ConnectionModeHelper.getIconBadgeText(Fs050wConnectionMode.nsaReady, notation: "4g_5g"), equals("e4G"));
            expect(ConnectionModeHelper.get4gCardTitle(Fs050wConnectionMode.nr5g, notation: "4g_5g"), equals("4G Anchor Cell"));
        });

        test('LTE/NR Notation Mode', () {
            expect(ConnectionModeHelper.getIconBadgeText(Fs050wConnectionMode.lte, notation: "lte_nr"), equals("LTE"));
            expect(ConnectionModeHelper.getIconBadgeText(Fs050wConnectionMode.nr5gSub6, notation: "lte_nr"), equals("NR+"));
            expect(ConnectionModeHelper.getIconBadgeText(Fs050wConnectionMode.nsaReady, notation: "lte_nr"), equals("eLTE"));
            expect(ConnectionModeHelper.get4gCardTitle(Fs050wConnectionMode.nr5g, notation: "lte_nr"), equals("LTE Anchor Cell"));
        });
    });

    group('SignalData Parsing & 5G SNR Adjust Tests', () {
        test('5G SNR with adjust5gSnr = true', () {
            final json = {
                'mnet_sysmode': 'nsa',
                'mnet_operator_name': 'Rakuten',
                'mnet_rsrp': '68',
                'mnet_endc_rsrp': '68',
                'mnet_endc_snr': '77', // (77 - 1) / 2 - 23 = 15.0
                'mnet_wnw_psband': '77',
            };
            final data = SignalData.fromApiResponse(json, adjust5gSnr: true);
            expect(data.nrSnr, equals(15.0));
        });

        test('5G SNR with adjust5gSnr = false', () {
            final json = {
                'mnet_sysmode': 'nsa',
                'mnet_operator_name': 'Rakuten',
                'mnet_rsrp': '68',
                'mnet_endc_rsrp': '68',
                'mnet_endc_snr': '77', // Raw 77.0
                'mnet_wnw_psband': '77',
            };
            final data = SignalData.fromApiResponse(json, adjust5gSnr: false);
            expect(data.nrSnr, equals(77.0));
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

            final minRatio = PipService.getAspectRatioValue('9:21');
            final maxRatio = PipService.getAspectRatioValue('21:9');
            expect(minRatio, greaterThan(0.418));
            expect(maxRatio, lessThan(2.39));
        });
    });

    group('AppSettings Serialization Tests', () {
        test('Full JSON Roundtrip with new notation, SNR adjust, and smooth color fields', () {
            final original = AppSettings(
                routerIp: "192.168.100.1",
                webPassword: "secretPassword",
                autoPipOnHome: false,
                pipAspectRatio: "21:9",
                pipGraphType: "snr",
                overlayEnabled: true,
                overlayStyle: "compact",
                overlayOpacity: 0.65,
                overlayScale: 1.25,
                eventLampEnabled: true,
                eventLampShape: "dot",
                eventLampPosition: "topRight",
                adjust5gSnr: false,
                generationNotation: "lte_nr",
                smoothGaugeColor: true,
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
            expect(restored.pipGraphType, equals("snr"));
            expect(restored.overlayEnabled, isTrue);
            expect(restored.overlayStyle, equals("compact"));
            expect(restored.overlayOpacity, equals(0.65));
            expect(restored.overlayScale, equals(1.25));
            expect(restored.eventLampEnabled, isTrue);
            expect(restored.eventLampShape, equals("dot"));
            expect(restored.eventLampPosition, equals("topRight"));
            expect(restored.adjust5gSnr, isFalse);
            expect(restored.generationNotation, equals("lte_nr"));
            expect(restored.smoothGaugeColor, isTrue);
            expect(restored.vibrateOn5gSub6, isTrue);
            expect(restored.vibrateOnHandover, isFalse);
            expect(restored.vibrateOnCriticalSignal, isTrue);
        });
    });
}
