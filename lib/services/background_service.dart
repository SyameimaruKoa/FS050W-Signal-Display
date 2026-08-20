import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../models/signal_data.dart';
import '../models/app_settings.dart';
import '../models/connection_state.dart';

class BackgroundService {
    static void initService() {
        FlutterForegroundTask.init(
            androidNotificationOptions: AndroidNotificationOptions(
                channelId: 'fs050w_monitor_channel',
                channelName: 'FS050W 電波常駐監視',
                channelDescription: 'FS050Wの電波状態をリアルタイムで常駐通知します',
                channelImportance: NotificationChannelImportance.LOW,
                priority: NotificationPriority.LOW,
                iconData: const NotificationIconData(
                    resType: ResourceType.mipmap,
                    resPrefix: ResourcePrefix.ic,
                    name: 'launcher',
                ),
            ),
            iosNotificationOptions: const IOSNotificationOptions(),
            foregroundTaskOptions: ForegroundTaskOptions(
                eventAction: ForegroundTaskEventAction.nothing(),
                autoRunOnBoot: false,
                autoRunOnMyPackageReplaced: false,
                allowWakeLock: true,
                allowWifiLock: true,
            ),
        );
    }

    static Future<void> startService() async {
        if (await FlutterForegroundTask.isRunningService) {
            return;
        }

        await FlutterForegroundTask.startService(
            notificationTitle: 'FS050W Monitor',
            notificationText: 'ルーターに接続中...',
            callback: startCallback,
        );
    }

    static Future<void> stopService() async {
        if (await FlutterForegroundTask.isRunningService) {
            await FlutterForegroundTask.stopService();
        }
    }

    static void updateNotification(SignalData signal, AppSettings settings) {
        if (!settings.foregroundNotificationEnabled) {
            stopService();
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
            // Compact 1-line style
            text = "4G RSRP: $lteRsrpStr${signal.nrRsrp != null ? ' | 5G: $nrRsrpStr' : ''}";
        }

        FlutterForegroundTask.updateService(
            notificationTitle: title,
            notificationText: text,
        );
    }
}

@pragma('vm:entry-point')
void startCallback() {
    FlutterForegroundTask.setTaskHandler(MonitorTaskHandler());
}

class MonitorTaskHandler extends TaskHandler {
    @override
    Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

    @override
    void onRepeatEvent(DateTime timestamp) {}

    @override
    Future<void> onDestroy(DateTime timestamp) async {}

    @override
    void onReceiveData(Object data) {}

    @override
    void onNotificationButtonPressed(String id) {}

    @override
    void onNotificationPressed() {
        FlutterForegroundTask.launchApp();
    }

    @override
    void onNotificationDismissed() {}
}
