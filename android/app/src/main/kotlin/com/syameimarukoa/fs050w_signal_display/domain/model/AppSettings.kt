package com.syameimarukoa.fs050w_signal_display.domain.model

import org.json.JSONObject

enum class AppThemeMode { OLED, DARK, LIGHT, SYSTEM }
enum class AppNavigationStyle { BOTTOM_NAV, CARD_BUTTONS }
enum class NotificationDetailStyle { DETAILED, COMPACT }

/** Full settings schema, migrated from the Flutter AppSettings JSON model. */
data class AppSettings(
    var routerIp: String = "",
    var webPassword: String = "",
    var autoPasswordless: Boolean = true,
    var foregroundIntervalSeconds: Int = 1,
    var unauthIntervalSeconds: Int = 3,
    var backgroundIntervalSeconds: Int = 5,
    var language: String = "ja",
    var appTheme: AppThemeMode = AppThemeMode.SYSTEM,
    var graphSpanMinutes: Int = 3,
    var keepScreenOn: Boolean = true,
    var navigationStyle: AppNavigationStyle = AppNavigationStyle.BOTTOM_NAV,
    var isSetupCompleted: Boolean = false,

    var vibrateOn5gSub6: Boolean = true,
    var vibrateOnHandover: Boolean = true,
    var vibrateOnCriticalSignal: Boolean = true,
    var batteryTempWarningEnabled: Boolean = true,
    var batteryTempWarningThreshold: Double = 45.0,

    var autoPipOnHome: Boolean = false,
    var pipAspectRatio: String = "16:9",
    var pipGraphType: String = "rsrp",
    var pipGraphScaleThreshold: Double = 1.0,

    var overlayEnabled: Boolean = false,
    var overlayStyle: String = "card",
    var overlayOpacity: Double = 0.85,
    var overlayScale: Double = 1.0,

    var eventLampEnabled: Boolean = true,
    var eventLampShape: String = "bar",
    var eventLampPosition: String = "topCenter",

    var adjust5gSnr: Boolean = true,
    var generationNotation: String = "4g_5g",
    var smoothGaugeColor: Boolean = false,
    var smoothGaugeCurve: String = "easeOut",
    var updateFlashDotEnabled: Boolean = true,

    @Deprecated("Notifications are abolished by specification; kept only for JSON compatibility.")
    var foregroundNotificationEnabled: Boolean = false,
    @Deprecated("Notifications are abolished by specification; kept only for JSON compatibility.")
    var notificationStyle: NotificationDetailStyle = NotificationDetailStyle.DETAILED,
) {
    fun toJson(): JSONObject = JSONObject().apply {
        put("routerIp", routerIp)
        put("webPassword", webPassword)
        put("autoPasswordless", autoPasswordless)
        put("foregroundIntervalSeconds", foregroundIntervalSeconds)
        put("unauthIntervalSeconds", unauthIntervalSeconds)
        put("backgroundIntervalSeconds", backgroundIntervalSeconds)
        put("language", language)
        put("appTheme", appTheme.ordinal)
        put("graphSpanMinutes", graphSpanMinutes)
        put("keepScreenOn", keepScreenOn)
        put("navigationStyle", navigationStyle.ordinal)
        put("isSetupCompleted", isSetupCompleted)
        put("vibrateOn5gSub6", vibrateOn5gSub6)
        put("vibrateOnHandover", vibrateOnHandover)
        put("vibrateOnCriticalSignal", vibrateOnCriticalSignal)
        put("batteryTempWarningEnabled", batteryTempWarningEnabled)
        put("batteryTempWarningThreshold", batteryTempWarningThreshold)
        put("autoPipOnHome", autoPipOnHome)
        put("pipAspectRatio", pipAspectRatio)
        put("pipGraphType", pipGraphType)
        put("pipGraphScaleThreshold", pipGraphScaleThreshold)
        put("overlayEnabled", overlayEnabled)
        put("overlayStyle", overlayStyle)
        put("overlayOpacity", overlayOpacity)
        put("overlayScale", overlayScale)
        put("eventLampEnabled", eventLampEnabled)
        put("eventLampShape", eventLampShape)
        put("eventLampPosition", eventLampPosition)
        put("adjust5gSnr", adjust5gSnr)
        put("generationNotation", generationNotation)
        put("smoothGaugeColor", smoothGaugeColor)
        put("smoothGaugeCurve", smoothGaugeCurve)
        put("updateFlashDotEnabled", updateFlashDotEnabled)
        put("foregroundNotificationEnabled", foregroundNotificationEnabled)
        put("notificationStyle", notificationStyle.ordinal)
    }

    companion object {
        fun fromJson(json: JSONObject): AppSettings = AppSettings(
            routerIp = json.optString("routerIp", ""),
            webPassword = json.optString("webPassword", ""),
            autoPasswordless = json.optBoolean("autoPasswordless", true),
            foregroundIntervalSeconds = json.optInt("foregroundIntervalSeconds", 1),
            unauthIntervalSeconds = json.optInt("unauthIntervalSeconds", 3),
            backgroundIntervalSeconds = json.optInt("backgroundIntervalSeconds", 5),
            language = json.optString("language", "ja"),
            appTheme = enumValue(json.optInt("appTheme", 3), AppThemeMode.entries),
            graphSpanMinutes = json.optInt("graphSpanMinutes", 3),
            keepScreenOn = json.optBoolean("keepScreenOn", true),
            navigationStyle = enumValue(json.optInt("navigationStyle", 0), AppNavigationStyle.entries),
            isSetupCompleted = json.optBoolean("isSetupCompleted", false),
            vibrateOn5gSub6 = json.optBoolean("vibrateOn5gSub6", true),
            vibrateOnHandover = json.optBoolean("vibrateOnHandover", true),
            vibrateOnCriticalSignal = json.optBoolean("vibrateOnCriticalSignal", true),
            batteryTempWarningEnabled = json.optBoolean("batteryTempWarningEnabled", true),
            batteryTempWarningThreshold = json.optDouble("batteryTempWarningThreshold", 45.0),
            autoPipOnHome = json.optBoolean("autoPipOnHome", false),
            pipAspectRatio = json.optString("pipAspectRatio", "16:9"),
            pipGraphType = json.optString("pipGraphType", "rsrp"),
            pipGraphScaleThreshold = json.optDouble("pipGraphScaleThreshold", 1.0),
            overlayEnabled = json.optBoolean("overlayEnabled", false),
            overlayStyle = json.optString("overlayStyle", "card"),
            overlayOpacity = json.optDouble("overlayOpacity", 0.85),
            overlayScale = json.optDouble("overlayScale", 1.0),
            eventLampEnabled = json.optBoolean("eventLampEnabled", true),
            eventLampShape = json.optString("eventLampShape", "bar"),
            eventLampPosition = json.optString("eventLampPosition", "topCenter"),
            adjust5gSnr = json.optBoolean("adjust5gSnr", true),
            generationNotation = json.optString("generationNotation", "4g_5g"),
            smoothGaugeColor = json.optBoolean("smoothGaugeColor", false),
            smoothGaugeCurve = json.optString("smoothGaugeCurve", "easeOut"),
            updateFlashDotEnabled = json.optBoolean("updateFlashDotEnabled", true),
            foregroundNotificationEnabled = json.optBoolean("foregroundNotificationEnabled", false),
            notificationStyle = enumValue(json.optInt("notificationStyle", 0), NotificationDetailStyle.entries),
        )

        private fun <T : Enum<T>> enumValue(index: Int, values: Collection<T>): T =
            values.elementAt(index.coerceIn(0, values.size - 1))
    }
}
