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

        const statusChannel = AndroidNotificationChannel(
            'fs050w_alert_status_v4',
            'FS050W リアルタイム電波ステータス',
            description: 'FS050Wの電波状態をリアルタイムで常駐通知します',
            importance: Importance.max,
            enableVibration: false,
            playSound: true,
            showBadge: true,
        );

        final androidPlugin = _notificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        
        // Clean up legacy silent channels
        await androidPlugin?.deleteNotificationChannel('fs050w_status_channel');
        await androidPlugin?.deleteNotificationChannel('fs050w_monitor_channel');
        await androidPlugin?.deleteNotificationChannel('fs050w_live_status_v3');
        await androidPlugin?.deleteNotificationChannel('fs050w_live_monitor_v3');
        
        await androidPlugin?.createNotificationChannel(eventChannel);
        await androidPlugin?.createNotificationChannel(statusChannel);
        await androidPlugin?.requestNotificationsPermission();
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

    static Future<void> updatePersistentStatus(SignalData signal, AppSettings settings) async {
        if (!settings.foregroundNotificationEnabled) {
            await cancelPersistentStatus();
            return;
        }

        final modeBadge = ConnectionModeHelper.getIconBadgeText(signal.connectionMode);
        final uiMode = ConnectionModeHelper.getUiModeText(signal.connectionMode, isSa: signal.isSa);
        final lteRsrpStr = signal.lteRsrp != null ? "${signal.lteRsrp!.toStringAsFixed(1)} dBm" : "--";
        final nrRsrpStr = signal.nrRsrp != null ? "${signal.nrRsrp!.toStringAsFixed(1)} dBm" : "--";

        final title = "[$modeBadge] $uiMode | ${signal.operatorName}";

        String text;
        if (settings.notificationStyle == NotificationDetailStyle.detailed) {
            final band4g = signal.lteBand != null ? "B${signal.lteBand}" : "--";
            final pci4g = signal.ltePci != null ? "${signal.ltePci}" : "--";
            final batStr = signal.batteryPercent != null ? " | 🔋${signal.batteryPercent}%${signal.isCharging ? '⚡' : ''}" : "";

            if (signal.connectionMode == Fs050wConnectionMode.nr5g || signal.connectionMode == Fs050wConnectionMode.nr5gSub6) {
                final nrBand = signal.nrBand != null ? "n${signal.nrBand}" : "--";
                text = "5G: $nrBand (RSRP: $nrRsrpStr) | 4G: $band4g PCI:$pci4g (RSRP: $lteRsrpStr)$batStr";
            } else {
                final sinrStr = signal.lteSinr != null ? " | SINR: ${signal.lteSinr!.toStringAsFixed(1)}dB" : "";
                text = "4G: $band4g PCI: $pci4g | RSRP: $lteRsrpStr$sinrStr$batStr";
            }
        } else {
            text = "4G RSRP: $lteRsrpStr${signal.nrRsrp != null ? ' | 5G: $nrRsrpStr' : ''}";
        }

        const androidDetails = AndroidNotificationDetails(
            'fs050w_alert_status_v4',
            'FS050W リアルタイム電波ステータス',
            channelDescription: 'FS050Wの電波状態をリアルタイムで常駐通知します',
            importance: Importance.max,
            priority: Priority.max,
            category: AndroidNotificationCategory.status,
            visibility: NotificationVisibility.public,
            ongoing: true,
            autoCancel: false,
            showWhen: true,
            playSound: true,
            enableVibration: false,
            onlyAlertOnce: true,
            icon: '@mipmap/ic_launcher',
        );

        const details = NotificationDetails(android: androidDetails);
        await _notificationsPlugin.show(1000, title, text, details);
    }

    static Future<void> cancelPersistentStatus() async {
        await _notificationsPlugin.cancel(1000);
    }
}

