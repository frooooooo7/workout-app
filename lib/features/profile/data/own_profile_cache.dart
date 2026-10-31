import 'dart:convert';

import '../../library/data/exercise_database.dart';

/// Ostatnia odpowiedź `GET /profile/me`, trzymana lokalnie — ekrany z danymi
/// profilu („Dane i cele”, cel masy ciała, profil) otwierają się od razu,
/// także bez internetu, a świeże dane dociągają się w tle.
abstract interface class OwnProfileCache {
  Future<Map<String, dynamic>?> read();

  Future<void> write(Map<String, dynamic> json);
}

/// Cache w bazie konta (tabela `sync_state`) — znika razem z danymi konta.
class DatabaseOwnProfileCache implements OwnProfileCache {
  const DatabaseOwnProfileCache(this._db);

  final ExerciseDatabase _db;

  static const key = 'own_profile_json';

  @override
  Future<Map<String, dynamic>?> read() async {
    final raw = await _db.readSyncState(key);
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  @override
  Future<void> write(Map<String, dynamic> json) =>
      _db.writeSyncState(key, jsonEncode(json));
}
