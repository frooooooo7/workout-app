import 'package:shared_preferences/shared_preferences.dart';

import '../domain/services/rest_timer_notification_settings.dart';

/// Ustawienie urządzenia (nie konta) — domyślnie włączone.
class SharedPreferencesRestTimerNotificationSettings
    implements RestTimerNotificationSettings {
  const SharedPreferencesRestTimerNotificationSettings();

  static const key = 'rest_timer_notifications_enabled';

  @override
  Future<bool> isEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(key) ?? true;
    } catch (_) {
      return true;
    }
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, enabled);
  }
}
