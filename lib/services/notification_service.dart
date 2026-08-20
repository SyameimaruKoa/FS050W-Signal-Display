import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';
import '../models/app_settings.dart';
import '../models/signal_data.dart';
import '../models/connection_state.dart';

class NotificationService {
    static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
    static bool _initialized = false;

    static Fs050wConnectionMode? _lastMode;
    static int? _lastPci;
    static bool _lastWasCritical = false;

    static Future<void> initialize() async {
        if (_initialized) return;

        const AndroidInitializationSettings initializationSettingsAndroid =
            AndroidInitializationSettings('@mipmap/ic_launcher');

        const InitializationSettings initializationSettings = InitializationSettings(
            android: initializationSettingsAndroid,
        );

        await _notificationsPlugin.initialize(initializationSettings);
        _initialized = true;
    }

    static void handleSignalEvents(SignalData signal, AppSettings settings) {
        // 1. 5G+ (sub6) area entry
        if (settings.vibrateOn5gSub6) {
            final isNowSub6 = signal.connectionMode == Fs050wConnectionMode.nr5gSub6;
            final wasSub6 = _lastMode == Fs050wConnectionMode.nr5gSub6;
            if (isNowSub6 && !wasSub6) {
                _trigger5gSub6Alert();
            }
        }
        _lastMode = signal.connectionMode;

        // 2. Handover (PCI change)
        if (settings.vibrateOnHandover && signal.handoverDescription != null) {
            _triggerHandoverAlert(signal.handoverDescription!);
        }
        _lastPci = signal.ltePci;

        // 3. Critical Signal (RSRP < -120dBm)
        if (settings.vibrateOnCriticalSignal) {
            final isCritical = (signal.lteRsrp != null && signal.lteRsrp! < -120.0);
            if (isCritical && !_lastWasCritical) {
                _triggerCriticalSignalAlert();
            }
            _lastWasCritical = isCritical;
        }
    }

    static Future<void> _trigger5gSub6Alert() async {
        try {
            final hasVib = await Vibration.hasVibrator() ?? false;
            if (hasVib) {
                Vibration.vibrate(duration: 150);
            }
            _showNotification(
                id: 101,
                title: "⚡ 5G+ (sub6) エリア突入",
                body: "高速 sub6 通信エリアに接続しました。",
            );
        } catch (e) {
            // ignore
        }
    }

    static Future<void> _triggerHandoverAlert(String message) async {
        try {
            final hasVib = await Vibration.hasVibrator() ?? false;
            if (hasVib) {
                Vibration.vibrate(duration: 50);
            }
            _showNotification(
                id: 102,
                title: "📡 基地局ハンドオーバー",
                body: message,
            );
        } catch (e) {
            // ignore
        }
    }

    static Future<void> _triggerCriticalSignalAlert() async {
        try {
            final hasVib = await Vibration.hasVibrator() ?? false;
            if (hasVib) {
                Vibration.vibrate(pattern: [0, 200, 100, 200]);
            }
            _showNotification(
                id: 103,
                title: "⚠️ 電波限界警告",
                body: "電波強度が極めて微弱 (RSRP < -120dBm) です。",
            );
        } catch (e) {
            // ignore
        }
    }

    static Future<void> _showNotification({
        required int id,
        required String title,
        required String body,
    }) async {
        const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
            'fs050w_events_channel',
            'FS050W イベント通知',
            channelDescription: 'ハンドオーバーや5G+突入時のイベント通知',
            importance: Importance.high,
            priority: Priority.high,
        );

        const NotificationDetails notificationDetails = NotificationDetails(android: androidDetails);
        await _notificationsPlugin.show(id, title, body, notificationDetails);
    }
}
