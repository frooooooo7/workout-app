import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/images/offline_network_image.dart';
import '../../../core/network/api_asset_uri.dart';
import '../../feed/data/shared_preferences_feed_cache.dart';

/// Usuwa dane konta zapisane na urządzeniu — po usunięciu konta na serwerze.
///
/// * baza per-user `gym_library_<userId>.db` (ćwiczenia, plany, sesje,
///   kolejka synchronizacji, cache historii treningów),
/// * cache feedu i inne klucze `shared_preferences` z sufiksem `_<userId>`,
/// * pliki awatarów konta w cache obrazków ([ownImageUrls] — adresy znane
///   w tej sesji aplikacji, np. z `/profile/me`).
///
/// Bazę trzeba wcześniej zamknąć. Ustawienia urządzenia (np. powiadomienia
/// timera) i pozostałe obrazki we wspólnym cache (ćwiczenia, awatary innych
/// osób) zostają.
class LocalAccountDataCleaner {
  const LocalAccountDataCleaner({
    this.databaseDirectory,
    this.ownImageUrls,
    this.evictImage,
  });

  /// Katalog baz (testy); domyślnie `getDatabasesPath()`.
  final String? databaseDirectory;

  /// Ścieżki (względne z API albo pełne adresy) obrazków konta do usunięcia.
  final Iterable<String> Function(String userId)? ownImageUrls;

  /// Usuwa obrazek z cache; domyślnie [OfflineImageStore.evict].
  final Future<void> Function(String url)? evictImage;

  static String databaseFileName(String userId) => 'gym_library_$userId.db';

  Future<void> wipe(String userId) async {
    await _deleteDatabase(userId);
    await _clearPreferences(userId);
    await _evictImages(userId);
  }

  Future<void> _evictImages(String userId) async {
    try {
      final urls = ownImageUrls?.call(userId) ?? const <String>[];
      final evict = evictImage ?? OfflineImageStore.instance.evict;
      for (final path in urls) {
        final uri = apiAssetUri(path);
        if (uri != null) await evict(uri.toString());
      }
    } catch (_) {
      /* best-effort */
    }
  }

  Future<void> _deleteDatabase(String userId) async {
    try {
      final directory = databaseDirectory ?? await getDatabasesPath();
      final path = p.join(directory, databaseFileName(userId));
      await deleteDatabase(path);
      if (kIsWeb) return;
      for (final suffix in const ['-wal', '-shm', '-journal']) {
        final file = File('$path$suffix');
        if (await file.exists()) await file.delete();
      }
    } catch (_) {
      /* best-effort */
    }
  }

  Future<void> _clearPreferences(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = {
        SharedPreferencesFeedCache.keyFor(userId),
        ...prefs.getKeys().where((key) => key.endsWith('_$userId')),
      };
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (_) {
      /* best-effort */
    }
  }
}
