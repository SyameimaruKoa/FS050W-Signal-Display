import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/app_settings.dart';
import '../models/signal_data.dart';
import '../models/connection_state.dart';

class OverlayService {
    static const MethodChannel _channel = MethodChannel('com.syameimarukoa.fs050w_signal_display/overlay');

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
                'pipAspectRatio': settings.pipAspectRatio,
                'smoothGaugeCurve': settings.smoothGaugeCurve,
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
        bool isLoggedIn = false,
    }) async {
        if (!settings.overlayEnabled) return;

        try {
            final mode = signal?.connectionMode ?? Fs050wConnectionMode.disconnected;
            final notation = settings.generationNotation;
            final modeBadge = ConnectionModeHelper.getIconBadgeText(mode, notation: notation);
            final modeText = ConnectionModeHelper.getUiModeText(mode, isSa: signal?.isSa ?? false, notation: notation);

            final Map<String, dynamic> dataMap = {
                'isConnecting': isConnecting,
                'isLoggedIn': isLoggedIn,
                'modeBadge': modeBadge,
                'modeText': modeText,
                'generationNotation': notation,
                'smoothGaugeColor': settings.smoothGaugeColor,
                'smoothGaugeCurve': settings.smoothGaugeCurve,
                'operatorName': signal?.operatorName ?? '--',
                'lteBand': isLoggedIn && (signal?.lteBand != null && signal!.lteBand! > 0) ? 'B${signal!.lteBand}' : '--',
                'ltePci': isLoggedIn && (signal?.ltePci != null && signal!.ltePci! > 0) ? '${signal!.ltePci}' : '--',
                'lteRsrp': signal?.lteRsrp,
                'lteRsrq': isLoggedIn ? signal?.lteRsrq : null,
                'lteSinr': isLoggedIn ? signal?.lteSinr : null,
                'nrBand': isLoggedIn && (signal?.nrBand != null && signal!.nrBand! > 0) ? 'n${signal!.nrBand}' : '--',
                'nrPci': isLoggedIn && (signal?.nrPci != null && signal!.nrPci! > 0) ? '${signal!.nrPci}' : '--',
                'nrRsrp': signal?.nrRsrp,
                'nrRsrq': isLoggedIn ? signal?.nrRsrq : null,
                'nrSnr': isLoggedIn ? signal?.nrSnr : null,
                'batteryPercent': signal?.batteryPercent,
                'scaledBatteryPercent': signal?.scaledBatteryPercent,
                'isCharging': signal?.isCharging ?? false,
                'isBatteryPresent': signal?.isBatteryPresent ?? true,
                'batteryTemperature': signal?.batteryTemperature,
                'remainingTimeHHMM': signal?.remainingTimeHHMM,
                'isTempWarning': settings.batteryTempWarningEnabled && ((signal?.batteryTemperature ?? 0) >= settings.batteryTempWarningThreshold),
            };

            await _channel.invokeMethod('updateOverlayData', {
                'jsonData': jsonEncode(dataMap),
                'overlayStyle': settings.overlayStyle,
                'overlayOpacity': settings.overlayOpacity,
                'overlayScale': settings.overlayScale,
                'smoothGaugeCurve': settings.smoothGaugeCurve,
                'pipAspectRatio': settings.pipAspectRatio,
            });
        } catch (_) {}
    }

    static Future<void> triggerLamp(String type, AppSettings settings) async {
        if (!settings.eventLampEnabled) return;

        try {
            await _channel.invokeMethod('triggerLamp', {
                'type': type,
                'shape': settings.eventLampShape,
                'position': settings.eventLampPosition,
            });
        } catch (_) {}
    }

    static Future<void> triggerVibration(String type) async {
        try {
            await _channel.invokeMethod('vibrate', {
                'type': type,
            });
        } catch (_) {}
    }
}
