import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/app_settings.dart';
import '../models/signal_data.dart';
import '../models/connection_state.dart';
import 'overlay_service.dart';

class NotificationService {
    static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

    static Future<void> initialize() async {
        // Notifications are fully abolished according to SPECIFICATION_PIP_OVERLAY.md.
        // Clean up legacy channels and cancel any leftover notifications.
        try {
            const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
            const initSettings = InitializationSettings(android: androidInit);
            await _notificationsPlugin.initialize(initSettings);

            final androidPlugin = _notificationsPlugin
                .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

            await _notificationsPlugin.cancelAll();
            await androidPlugin?.deleteNotificationChannel('fs050w_status_channel');
            await androidPlugin?.deleteNotificationChannel('fs050w_monitor_channel');
            await androidPlugin?.deleteNotificationChannel('fs050w_live_status_v3');
            await androidPlugin?.deleteNotificationChannel('fs050w_live_monitor_v3');
            await androidPlugin?.deleteNotificationChannel('fs050w_alert_status_v4');
            await androidPlugin?.deleteNotificationChannel('fs050w_event_alerts');
            await androidPlugin?.deleteNotificationChannel('fs050w_live_status_v5');
        } catch (_) {}
    }

    static Fs050wConnectionMode? _lastConnectionMode;
    static String? _lastHandoverKey;
    static bool _wasCriticalSignal = false;

    static void handleSignalEvents(SignalData signal, AppSettings settings) {
        // 1. 5G+ Sub6 connection trigger (only on transition into 5G Sub6)
        if (signal.connectionMode == Fs050wConnectionMode.nr5gSub6) {
            if (_lastConnectionMode != Fs050wConnectionMode.nr5gSub6) {
                trigger5gSub6Event(settings);
            }
        }
        _lastConnectionMode = signal.connectionMode;

        // 2. Handover trigger (only on new handover event)
        if (signal.handoverDescription != null) {
            if (_lastHandoverKey != signal.handoverDescription) {
                triggerHandoverEvent(settings);
                _lastHandoverKey = signal.handoverDescription;
            }
        } else {
            _lastHandoverKey = null;
        }

        // 3. Critical low signal trigger (only on transition to critical <= -115 dBm)
        final isCrit = (signal.lteRsrp != null && signal.lteRsrp! <= -115.0) ||
            (signal.nrRsrp != null && signal.nrRsrp! <= -115.0);
        if (isCrit && !_wasCriticalSignal) {
            triggerCriticalSignalEvent(settings);
        }
        _wasCriticalSignal = isCrit;
    }

    static Future<void> trigger5gSub6Event(AppSettings settings) async {
        if (settings.vibrateOn5gSub6) {
            HapticFeedback.heavyImpact();
            Future.delayed(const Duration(milliseconds: 150), () {
                HapticFeedback.heavyImpact();
            });
        }
        OverlayService.triggerLamp("5g", settings);
    }

    static Future<void> triggerHandoverEvent(AppSettings settings) async {
        if (settings.vibrateOnHandover) {
            HapticFeedback.mediumImpact();
        }
        OverlayService.triggerLamp("handover", settings);
    }

    static Future<void> triggerCriticalSignalEvent(AppSettings settings) async {
        if (settings.vibrateOnCriticalSignal) {
            HapticFeedback.vibrate();
            Future.delayed(const Duration(milliseconds: 150), () {
                HapticFeedback.vibrate();
            });
        }
        OverlayService.triggerLamp("critical", settings);
    }
}
