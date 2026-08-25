import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../models/signal_data.dart';
import '../models/app_settings.dart';

class BackgroundService {
    static void initService() {
        // Notifications are abolished; initialize minimal foreground task if needed
        FlutterForegroundTask.init(
            androidNotificationOptions: AndroidNotificationOptions(
                channelId: 'fs050w_empty_channel',
                channelName: 'FS050W Signal Display',
                channelDescription: 'FS050W Signal Display Background Service',
                channelImportance: NotificationChannelImportance.NONE,
                priority: NotificationPriority.LOW,
                playSound: false,
                enableVibration: false,
                visibility: NotificationVisibility.VISIBILITY_SECRET,
                showBadge: false,
            ),
            iosNotificationOptions: const IOSNotificationOptions(),
            foregroundTaskOptions: ForegroundTaskOptions(
                eventAction: ForegroundTaskEventAction.nothing(),
                autoRunOnBoot: false,
                autoRunOnMyPackageReplaced: false,
                allowWakeLock: false,
                allowWifiLock: false,
            ),
        );
    }

    static Future<void> startService() async {
        // Kept for backward compatibility; do not launch notification
    }

    static Future<void> stopService() async {
        if (await FlutterForegroundTask.isRunningService) {
            await FlutterForegroundTask.stopService();
        }
    }

    static Future<void> updateNotification(SignalData signal, AppSettings settings) async {
        // Notifications are abolished in SPECIFICATION_PIP_OVERLAY.md
    }
}
