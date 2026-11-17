package com.syameimarukoa.fs050w_signal_display.data

import android.content.Context
import com.syameimarukoa.fs050w_signal_display.domain.model.AppSettings
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/** Owns settings persistence, including migration from the Flutter shared_preferences file. */
class SettingsStore(private val context: Context) {
    private val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    private val _settings = MutableStateFlow(load())
    val settings: StateFlow<AppSettings> = _settings.asStateFlow()

    var value: AppSettings
        get() = _settings.value
        set(value) = set(value)

    private fun load(): AppSettings {
        val stored = prefs.getString(KEY_SETTINGS, null)
        if (!stored.isNullOrEmpty()) {
            return try {
                AppSettings.fromJson(org.json.JSONObject(stored))
            } catch (e: Exception) {
                AppLogger.warn("Failed to parse stored settings: ${e.message}")
                AppSettings()
            }
        }
        // Migrate the JSON written by the Flutter shared_preferences plugin.
        val legacy = context.getSharedPreferences(LEGACY_PREFS_NAME, Context.MODE_PRIVATE)
            .getString(LEGACY_KEY, null)
        if (!legacy.isNullOrEmpty()) {
            return try {
                val migrated = AppSettings.fromJson(org.json.JSONObject(legacy))
                prefs.edit().putString(KEY_SETTINGS, migrated.toJson().toString()).apply()
                AppLogger.info("Migrated settings from Flutter shared_preferences")
                migrated
            } catch (e: Exception) {
                AppLogger.warn("Failed to migrate Flutter settings: ${e.message}")
                AppSettings()
            }
        }
        return AppSettings()
    }

    fun set(settings: AppSettings) {
        _settings.value = settings
        prefs.edit().putString(KEY_SETTINGS, settings.toJson().toString()).apply()
    }

    fun update(transform: (AppSettings) -> AppSettings) = set(transform(_settings.value))

    companion object {
        private const val PREFS_NAME = "fs050w_prefs"
        private const val KEY_SETTINGS = "settings"
        private const val LEGACY_PREFS_NAME = "FlutterSharedPreferences"
        private const val LEGACY_KEY = "flutter.fs050w_app_settings"
    }
}
