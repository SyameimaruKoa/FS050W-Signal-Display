import 'package:flutter/material.dart';

enum AppThemeMode {
    oled,    // OLED 漆黒ダーク (#000000)
    dark,    // マテリアルダーク (#121212)
    light,   // ライトモード (#F8F9FA)
    system,  // OS システム追従
}

enum AppNavigationStyle {
    bottomNav,    // スタイルA: ボトムナビゲーション
    cardButtons,  // スタイルB: ページ遷移ボタン
}

enum NotificationDetailStyle {
    detailed,  // 2行詳細スタイル
    compact,   // 1行コンパクトスタイル
}

class AppSettings {
    String routerIp;
    String webPassword;
    bool autoPasswordless;
    int foregroundIntervalSeconds;
    int backgroundIntervalSeconds;
    bool foregroundNotificationEnabled;
    NotificationDetailStyle notificationStyle;
    bool vibrateOn5gSub6;
    bool vibrateOnHandover;
    bool vibrateOnCriticalSignal;
    AppNavigationStyle navigationStyle;
    bool keepScreenOn;
    int graphSpanMinutes;
    AppThemeMode appTheme;
    bool isSetupCompleted;

    AppSettings({
        this.routerIp = "192.168.155.1",
        this.webPassword = "",
        this.autoPasswordless = true,
        this.foregroundIntervalSeconds = 1,
        this.backgroundIntervalSeconds = 1,
        this.foregroundNotificationEnabled = true,
        this.notificationStyle = NotificationDetailStyle.detailed,
        this.vibrateOn5gSub6 = true,
        this.vibrateOnHandover = true,
        this.vibrateOnCriticalSignal = true,
        this.navigationStyle = AppNavigationStyle.bottomNav,
        this.keepScreenOn = true,
        this.graphSpanMinutes = 3,
        this.appTheme = AppThemeMode.system,
        this.isSetupCompleted = false,
    });

    Map<String, dynamic> toJson() {
        return {
            'routerIp': routerIp,
            'webPassword': webPassword,
            'autoPasswordless': autoPasswordless,
            'foregroundIntervalSeconds': foregroundIntervalSeconds,
            'backgroundIntervalSeconds': backgroundIntervalSeconds,
            'foregroundNotificationEnabled': foregroundNotificationEnabled,
            'notificationStyle': notificationStyle.index,
            'vibrateOn5gSub6': vibrateOn5gSub6,
            'vibrateOnHandover': vibrateOnHandover,
            'vibrateOnCriticalSignal': vibrateOnCriticalSignal,
            'navigationStyle': navigationStyle.index,
            'keepScreenOn': keepScreenOn,
            'graphSpanMinutes': graphSpanMinutes,
            'appTheme': appTheme.index,
            'isSetupCompleted': isSetupCompleted,
        };
    }

    factory AppSettings.fromJson(Map<String, dynamic> json) {
        return AppSettings(
            routerIp: json['routerIp'] ?? "192.168.155.1",
            webPassword: json['webPassword'] ?? "",
            autoPasswordless: json['autoPasswordless'] ?? true,
            foregroundIntervalSeconds: json['foregroundIntervalSeconds'] ?? 1,
            backgroundIntervalSeconds: json['backgroundIntervalSeconds'] ?? 1,
            foregroundNotificationEnabled: json['foregroundNotificationEnabled'] ?? true,
            notificationStyle: NotificationDetailStyle.values[json['notificationStyle'] ?? 0],
            vibrateOn5gSub6: json['vibrateOn5gSub6'] ?? true,
            vibrateOnHandover: json['vibrateOnHandover'] ?? true,
            vibrateOnCriticalSignal: json['vibrateOnCriticalSignal'] ?? true,
            navigationStyle: AppNavigationStyle.values[json['navigationStyle'] ?? 0],
            keepScreenOn: json['keepScreenOn'] ?? true,
            graphSpanMinutes: json['graphSpanMinutes'] ?? 3,
            appTheme: AppThemeMode.values[json['appTheme'] ?? 3],
            isSetupCompleted: json['isSetupCompleted'] ?? false,
        );
    }
}
