import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/cursor_page.dart';
import '../domain/repositories/feed_repository.dart';
import 'feed_json.dart';

/// Pierwsza strona feedu jako JSON w `shared_preferences`, osobno dla każdego
/// konta. Cache jest best-effort: każdy błąd (brak pluginu, uszkodzony zapis)
/// kończy się pustym odczytem, a nie wyjątkiem.
class SharedPreferencesFeedCache implements FeedCache {
  const SharedPreferencesFeedCache();

  static String keyFor(String userId) => 'feed_first_page_v1_$userId';

  @override
  Future<FeedPage?> read(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(keyFor(userId));
      if (raw == null || raw.isEmpty) return null;
      return FeedJson.feedPageFromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String userId, FeedPage page) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        keyFor(userId),
        jsonEncode(FeedJson.feedPageToJson(page)),
      );
    } catch (_) {
      /* cache jest best-effort */
    }
  }
}
