import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../feed/data/shared_preferences_feed_cache.dart';

/// Usuwa dane konta zapisane na urządzeniu — po usunięciu konta na serwerze.
///
/// * baza per-user `gym_library_<userId>.db` (ćwiczenia, plany, sesje,
///   kolejka synchronizacji, cache historii treningów),
/// * cache feedu i inne klucze `shared_preferences` z sufiksem `_<userId>`.
///
/// Bazę trzeba wcześniej zamknąć. Ustawienia urządzenia (np. powiadomienia
/// timera) i wspólny cache obrazków zostają.
class LocalAccountDataCleaner {
  const LocalAccountDataCleaner({this.databaseDirectory});

  /// Katalog baz (testy); domyślnie `getDatabasesPath()`.
  final String? databaseDirectory;

  static String databaseFileName(String userId) => 'gym_library_$userId.db';

  Future<void> wipe(String userId) async {
    await _deleteDatabase(userId);
    await _clearPreferences(userId);
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
