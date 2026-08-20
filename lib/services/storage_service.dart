import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';

class StorageService {
    static const String _kSettingsKey = "fs050w_app_settings";

    static Future<AppSettings> loadSettings() async {
        try {
            final prefs = await SharedPreferences.getInstance();
            final jsonStr = prefs.getString(_kSettingsKey);
            if (jsonStr != null && jsonStr.isNotEmpty) {
                final Map<String, dynamic> map = jsonDecode(jsonStr);
                return AppSettings.fromJson(map);
            }
        } catch (e) {
            // fallback to default
        }
        return AppSettings();
    }

    static Future<void> saveSettings(AppSettings settings) async {
        try {
            final prefs = await SharedPreferences.getInstance();
            final jsonStr = jsonEncode(settings.toJson());
            await prefs.setString(_kSettingsKey, jsonStr);
        } catch (e) {
            // log error
        }
    }
}
