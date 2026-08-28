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
    // 1. 接続 & 通信設定
    String routerIp;
    String webPassword;
    bool autoPasswordless;
    int foregroundIntervalSeconds;
    int unauthIntervalSeconds;          // 未ログイン時のポーリング間隔 (3, 5, 10秒)
    int backgroundIntervalSeconds;
    String language;
    AppThemeMode appTheme;
    int graphSpanMinutes;
    bool keepScreenOn;
    AppNavigationStyle navigationStyle;
    bool isSetupCompleted;

    // 2. イベントハプティクス（バイブレーション）設定
    bool vibrateOn5gSub6;
    bool vibrateOnHandover;
    bool vibrateOnCriticalSignal;
    bool batteryTempWarningEnabled;     // バッテリー高温警告の有効/無効
    double batteryTempWarningThreshold; // バッテリー高温警告の温度閾値 (38〜50℃, デフォルト45℃)

    // 3. PiP (Picture-in-Picture) 設定
    bool autoPipOnHome;                 // ホーム画面に戻った時に自動PiP起動
    String pipAspectRatio;              // "16:9", "9:16", "1:1", "4:3", "3:4", "21:9", "9:21"
    String pipGraphType;                // "rsrp", "snr", "rsrq", "none" (拡大時グラフ種類)
    double pipGraphScaleThreshold;      // PiPグラフ表示のサイズ倍率閾値 (0.5 ~ 1.5)

    // 4. フローティングオーバーレイ設定
    bool overlayEnabled;                // オーバーレイ有効/無効
    String overlayStyle;                // "card" (スタイルA), "compact" (スタイルB)
    double overlayOpacity;              // 0.2 〜 1.0 (背景透過度)
    double overlayScale;                // 0.8 〜 1.5 (拡縮サイズ保持値)

    // 5. イベントLEDランプ設定
    bool eventLampEnabled;              // ランプ有効/無効
    String eventLampShape;              // "bar" (スリムバー), "dot" (丸型LED)
    String eventLampPosition;           // "topCenter", "topLeft", "topRight"

    // 6. 表示 & 表記設定
    bool adjust5gSnr;                   // 5G SNR値の補正 (-23dB) を適用するか
    String generationNotation;          // "4g_5g" (4G / 5G / e4G), "lte_nr" (LTE / NR / eLTE)
    bool smoothGaugeColor;              // シームレスゲージカラー (グラデーション変化)
    String smoothGaugeCurve;            // "easeOut", "easeIn", "easeInOut", "linear"

    // 7. レガシー通知設定 (非推奨/互換性保持用)
    bool foregroundNotificationEnabled;
    NotificationDetailStyle notificationStyle;

    AppSettings({
        this.routerIp = "",
        this.webPassword = "",
        this.autoPasswordless = true,
        this.foregroundIntervalSeconds = 1,
        this.unauthIntervalSeconds = 3,
        this.backgroundIntervalSeconds = 5,
        this.language = "ja",
        this.appTheme = AppThemeMode.system,
        this.graphSpanMinutes = 3,
        this.keepScreenOn = true,
        this.navigationStyle = AppNavigationStyle.bottomNav,
        this.isSetupCompleted = false,
        this.vibrateOn5gSub6 = true,
        this.vibrateOnHandover = true,
        this.vibrateOnCriticalSignal = true,
        this.batteryTempWarningEnabled = true,
        this.batteryTempWarningThreshold = 45.0,
        this.autoPipOnHome = true,
        this.pipAspectRatio = "16:9",
        this.pipGraphType = "rsrp",
        this.pipGraphScaleThreshold = 1.0,
        this.overlayEnabled = false,
        this.overlayStyle = "card",
        this.overlayOpacity = 0.85,
        this.overlayScale = 1.0,
        this.eventLampEnabled = true,
        this.eventLampShape = "bar",
        this.eventLampPosition = "topCenter",
        this.adjust5gSnr = true,
        this.generationNotation = "4g_5g",
        this.smoothGaugeColor = false,
        this.smoothGaugeCurve = "easeOut",
        this.foregroundNotificationEnabled = false,
        this.notificationStyle = NotificationDetailStyle.detailed,
    });

    Map<String, dynamic> toJson() {
        return {
            'routerIp': routerIp,
            'webPassword': webPassword,
            'autoPasswordless': autoPasswordless,
            'foregroundIntervalSeconds': foregroundIntervalSeconds,
            'unauthIntervalSeconds': unauthIntervalSeconds,
            'backgroundIntervalSeconds': backgroundIntervalSeconds,
            'language': language,
            'appTheme': appTheme.index,
            'graphSpanMinutes': graphSpanMinutes,
            'keepScreenOn': keepScreenOn,
            'navigationStyle': navigationStyle.index,
            'isSetupCompleted': isSetupCompleted,
            'vibrateOn5gSub6': vibrateOn5gSub6,
            'vibrateOnHandover': vibrateOnHandover,
            'vibrateOnCriticalSignal': vibrateOnCriticalSignal,
            'batteryTempWarningEnabled': batteryTempWarningEnabled,
            'batteryTempWarningThreshold': batteryTempWarningThreshold,
            'autoPipOnHome': autoPipOnHome,
            'pipAspectRatio': pipAspectRatio,
            'pipGraphType': pipGraphType,
            'pipGraphScaleThreshold': pipGraphScaleThreshold,
            'overlayEnabled': overlayEnabled,
            'overlayStyle': overlayStyle,
            'overlayOpacity': overlayOpacity,
            'overlayScale': overlayScale,
            'eventLampEnabled': eventLampEnabled,
            'eventLampShape': eventLampShape,
            'eventLampPosition': eventLampPosition,
            'adjust5gSnr': adjust5gSnr,
            'generationNotation': generationNotation,
            'smoothGaugeColor': smoothGaugeColor,
            'smoothGaugeCurve': smoothGaugeCurve,
            'foregroundNotificationEnabled': foregroundNotificationEnabled,
            'notificationStyle': notificationStyle.index,
        };
    }

    factory AppSettings.fromJson(Map<String, dynamic> json) {
        return AppSettings(
            routerIp: json['routerIp'] ?? "",
            webPassword: json['webPassword'] ?? "",
            autoPasswordless: json['autoPasswordless'] ?? true,
            foregroundIntervalSeconds: json['foregroundIntervalSeconds'] ?? 1,
            unauthIntervalSeconds: json['unauthIntervalSeconds'] ?? 3,
            backgroundIntervalSeconds: json['backgroundIntervalSeconds'] ?? 5,
            language: json['language'] ?? "ja",
            appTheme: AppThemeMode.values[json['appTheme'] ?? 3],
            graphSpanMinutes: json['graphSpanMinutes'] ?? 3,
            keepScreenOn: json['keepScreenOn'] ?? true,
            navigationStyle: AppNavigationStyle.values[json['navigationStyle'] ?? 0],
            isSetupCompleted: json['isSetupCompleted'] ?? false,
            vibrateOn5gSub6: json['vibrateOn5gSub6'] ?? true,
            vibrateOnHandover: json['vibrateOnHandover'] ?? true,
            vibrateOnCriticalSignal: json['vibrateOnCriticalSignal'] ?? true,
            batteryTempWarningEnabled: json['batteryTempWarningEnabled'] ?? true,
            batteryTempWarningThreshold: (json['batteryTempWarningThreshold'] as num?)?.toDouble() ?? 45.0,
            autoPipOnHome: json['autoPipOnHome'] ?? true,
            pipAspectRatio: json['pipAspectRatio'] ?? "16:9",
            pipGraphType: json['pipGraphType'] ?? "rsrp",
            pipGraphScaleThreshold: (json['pipGraphScaleThreshold'] as num?)?.toDouble() ?? 1.0,
            overlayEnabled: json['overlayEnabled'] ?? false,
            overlayStyle: json['overlayStyle'] ?? "card",
            overlayOpacity: (json['overlayOpacity'] as num?)?.toDouble() ?? 0.85,
            overlayScale: (json['overlayScale'] as num?)?.toDouble() ?? 1.0,
            eventLampEnabled: json['eventLampEnabled'] ?? true,
            eventLampShape: json['eventLampShape'] ?? "bar",
            eventLampPosition: json['eventLampPosition'] ?? "topCenter",
            adjust5gSnr: json['adjust5gSnr'] ?? true,
            generationNotation: json['generationNotation'] ?? "4g_5g",
            smoothGaugeColor: json['smoothGaugeColor'] ?? false,
            smoothGaugeCurve: json['smoothGaugeCurve'] ?? "easeOut",
            foregroundNotificationEnabled: json['foregroundNotificationEnabled'] ?? false,
            notificationStyle: NotificationDetailStyle.values[json['notificationStyle'] ?? 0],
        );
    }
}
