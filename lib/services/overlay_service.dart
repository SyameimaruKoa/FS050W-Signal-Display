import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/app_settings.dart';
import '../models/signal_data.dart';
import '../models/connection_state.dart';

class OverlayService {
    static const MethodChannel _channel = MethodChannel('com.syameimarukoa.fs050w_monitor/overlay');

    // Callback stream for in-app LED lamp overlay
    static final ValueNotifier<Map<String, dynamic>?> inAppLampNotifier = ValueNotifier<Map<String, dynamic>?>(null);

    static Future<bool> checkPermission() async {
        try {
            final bool? result = await _channel.invokeMethod<bool>('checkPermission');
            return result ?? false;
        } catch (_) {
            return false;
        }
    }

    static Future<void> requestPermission() async {
        try {
            await _channel.invokeMethod('requestPermission');
        } catch (_) {}
    }

    static Future<void> startOverlay(AppSettings settings) async {
        try {
            await _channel.invokeMethod('startOverlay', {
                'overlayStyle': settings.overlayStyle,
                'overlayOpacity': settings.overlayOpacity,
                'overlayScale': settings.overlayScale,
            });
        } catch (_) {}
    }

    static Future<void> stopOverlay() async {
        try {
            await _channel.invokeMethod('stopOverlay');
        } catch (_) {}
    }

    static Future<void> updateOverlayData(
        SignalData? signal,
        AppSettings settings, {
        bool isConnecting = false,
    }) async {
        if (!settings.overlayEnabled) return;

        try {
            final mode = signal?.connectionMode ?? Fs050wConnectionMode.disconnected;
            final notation = settings.generationNotation;
            final modeBadge = ConnectionModeHelper.getIconBadgeText(mode, notation: notation);
            final modeText = ConnectionModeHelper.getUiModeText(mode, isSa: signal?.isSa ?? false, notation: notation);

            final Map<String, dynamic> dataMap = {
                'isConnecting': isConnecting,
                'modeBadge': modeBadge,
                'modeText': modeText,
                'generationNotation': notation,
                'smoothGaugeColor': settings.smoothGaugeColor,
                'smoothGaugeCurve': settings.smoothGaugeCurve,
                'operatorName': signal?.operatorName ?? '--',
                'lteBand': signal?.lteBand != null ? 'B${signal!.lteBand}' : '--',
                'ltePci': signal?.ltePci != null ? '${signal!.ltePci}' : '--',
                'lteRsrp': signal?.lteRsrp,
                'lteRsrq': signal?.lteRsrq,
                'lteSinr': signal?.lteSinr,
                'nrBand': signal?.nrBand != null ? 'n${signal!.nrBand}' : '--',
                'nrPci': signal?.nrPci != null ? '${signal!.nrPci}' : '--',
                'nrRsrp': signal?.nrRsrp,
                'nrRsrq': signal?.nrRsrq,
                'nrSnr': signal?.nrSnr,
            };

            await _channel.invokeMethod('updateOverlayData', {
                'jsonData': jsonEncode(dataMap),
                'overlayStyle': settings.overlayStyle,
                'overlayOpacity': settings.overlayOpacity,
                'overlayScale': settings.overlayScale,
                'smoothGaugeCurve': settings.smoothGaugeCurve,
            });
        } catch (_) {}
    }

    static Future<void> triggerLamp(String type, AppSettings settings) async {
        if (!settings.eventLampEnabled) return;

        // In-app lamp update
        inAppLampNotifier.value = {
            'type': type,
            'shape': settings.eventLampShape,
            'position': settings.eventLampPosition,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
        };

        // System overlay lamp update
        try {
            await _channel.invokeMethod('triggerLamp', {
                'type': type,
                'shape': settings.eventLampShape,
                'position': settings.eventLampPosition,
            });
        } catch (_) {}
    }
}
