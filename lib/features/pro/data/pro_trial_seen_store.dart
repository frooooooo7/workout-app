import 'package:shared_preferences/shared_preferences.dart';

/// Zapamiętuje, które ekrany PRO użytkownik już widział, żeby pokazać
/// każdy tylko raz. Klucze są per konto (na jednym telefonie może być kilka).
abstract class ProTrialSeenStore {
  Future<bool> welcomeSeen(String userId);
  Future<void> markWelcomeSeen(String userId);
  Future<bool> endSeen(String userId);
  Future<void> markEndSeen(String userId);
}

class SharedPreferencesProTrialSeenStore implements ProTrialSeenStore {
  const SharedPreferencesProTrialSeenStore();

  static String welcomeKey(String userId) => 'pro_welcome_seen_$userId';
  static String endKey(String userId) => 'pro_end_seen_$userId';

  Future<bool> _read(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(key) ?? false;
    } catch (_) {
      // Bez dostępu do pamięci wolimy nie pokazywać ekranu za każdym razem.
      return true;
    }
  }

  Future<void> _write(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, true);
    } catch (_) {}
  }

  @override
  Future<bool> welcomeSeen(String userId) => _read(welcomeKey(userId));

  @override
  Future<void> markWelcomeSeen(String userId) => _write(welcomeKey(userId));

  @override
  Future<bool> endSeen(String userId) => _read(endKey(userId));

  @override
  Future<void> markEndSeen(String userId) => _write(endKey(userId));
}
