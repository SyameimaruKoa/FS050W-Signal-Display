import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/app_settings.dart';
import '../models/signal_data.dart';
import '../models/connection_state.dart';

class NotificationService {
    static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

    static Future<void> initialize() async {
        await init();
    }

    static Future<void> init() async {
        const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
        const initSettings = InitializationSettings(android: androidInit);
        await _notificationsPlugin.initialize(initSettings);

        const eventChannel = AndroidNotificationChannel(
            'fs050w_event_alerts',
            'FS050W イベント通知',
            description: '5G+接続時やハンドオーバー発生時の通知',
            importance: Importance.high,
        );

        await _notificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(eventChannel);
    }

    static Future<void> showSimpleAlert({
        required int id,
        required String title,
        required String body,
    }) async {
        const androidDetails = AndroidNotificationDetails(
            'fs050w_event_alerts',
            'FS050W イベント通知',
            importance: Importance.high,
            priority: Priority.high,
        );

        const details = NotificationDetails(android: androidDetails);
        await _notificationsPlugin.show(id, title, body, details);
    }

    static void handleSignalEvents(SignalData signal, AppSettings settings) {
        if (signal.connectionMode == Fs050wConnectionMode.nr5gSub6) {
            trigger5gSub6Notification(settings);
        }

        if (signal.handoverDescription != null) {
            triggerHandoverNotification(settings, signal.handoverDescription!);
        }

        if (signal.lteRsrp != null && signal.lteRsrp! <= -115.0) {
            triggerCriticalSignalNotification(settings, signal.lteRsrp!);
        }
    }

    static Future<void> trigger5gSub6Notification(AppSettings settings) async {
        if (!settings.vibrateOn5gSub6) return;

        HapticFeedback.heavyImpact();
        Future.delayed(const Duration(milliseconds: 150), () {
            HapticFeedback.heavyImpact();
        });

        await showSimpleAlert(
            id: 1001,
            title: '5G+ (Sub6) 接続検知',
            body: '超高速 5G+ (Sub6 / n77等) に接続しました。',
        );
    }

    static Future<void> triggerHandoverNotification(AppSettings settings, String handoverText) async {
        if (!settings.vibrateOnHandover) return;

        HapticFeedback.mediumImpact();

        await showSimpleAlert(
            id: 1002,
            title: 'ハンドオーバー検知 (PCI更新)',
            body: '基地局が切り替わりました: $handoverText',
        );
    }

    static Future<void> triggerCriticalSignalNotification(AppSettings settings, double rsrp) async {
        if (!settings.vibrateOnCriticalSignal) return;

        HapticFeedback.vibrate();
        Future.delayed(const Duration(milliseconds: 150), () {
            HapticFeedback.vibrate();
        });

        await showSimpleAlert(
            id: 1003,
            title: '電波レベル警告 (圏外寸前)',
            body: 'RSRPが極めて低調です (${rsrp.toStringAsFixed(1)} dBm)。通信切断にご注意ください。',
        );
    }
}
