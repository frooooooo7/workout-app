import 'package:shared_preferences/shared_preferences.dart';

import '../domain/repositories/feed_repository.dart';

/// Id obejrzanych postów w `shared_preferences`, osobno dla każdego konta.
/// Best-effort jak cache feedu: błąd odczytu oznacza „brak zapisu”, a błąd
/// zapisu jest ignorowany.
class SharedPreferencesFeedSeenStore implements FeedSeenStore {
  const SharedPreferencesFeedSeenStore();

  /// Kończy się na `_$userId`, więc czyszczenie danych konta usuwa go razem
  /// z resztą preferencji użytkownika.
  static String keyFor(String userId) => 'feed_seen_posts_v1_$userId';

  /// Wystarczy z zapasem na kilka stron feedu — starsze posty i tak nie
  /// wracają na pierwszą stronę.
  static const maxEntries = 500;

  @override
  Future<List<String>?> read(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(keyFor(userId));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String userId, List<String> postIds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        keyFor(userId),
        postIds.take(maxEntries).toList(growable: false),
      );
    } catch (_) {
      /* best-effort */
    }
  }
}
