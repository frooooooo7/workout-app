import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../domain/models/progression_settings.dart';

/// Ustawienia progresji konta na serwerze (`/profile/me/progression`).
abstract interface class ProgressionSettingsRemote {
  /// `null` — konto nigdy jej nie ustawiało.
  Future<ProgressionSettings?> fetch();
  Future<void> save(ProgressionSettings settings);
}

class ApiProgressionSettingsRemote implements ProgressionSettingsRemote {
  const ApiProgressionSettingsRemote(this._api);

  final ApiClient _api;

  static const path = '/profile/me/progression';

  @override
  Future<ProgressionSettings?> fetch() async {
    final json = await _api.get(path, auth: true);
    if (json is! Map) return null;
    return ProgressionSettings.fromJson(json['progression']);
  }

  @override
  Future<void> save(ProgressionSettings settings) async {
    await _api.put(path, {'progression': settings.toJson()}, auth: true);
  }
}

/// Metoda progresji zalogowanego konta (Ustawienia → Progresja).
///
/// Działa offline: wybór trafia od razu do [notifier] i do pamięci telefonu
/// (osobno dla każdego konta), a na serwer, gdy się da. Niewysłana zmiana
/// ma flagę „dirty” i idzie przy następnym [attach]/[set]; bez niej
/// serwer wygrywa (zmiana z innego telefonu). Klucze kończą się id konta,
/// więc usunięcie konta czyści je razem z resztą jego ustawień.
class ProgressionSettingsStore {
  ProgressionSettingsStore({SharedPreferences? prefs}) : _prefs = prefs;

  SharedPreferences? _prefs;

  final ValueNotifier<ProgressionSettings> notifier = ValueNotifier(
    ProgressionSettings.off,
  );

  ProgressionSettings get current => notifier.value;

  String? _userId;
  ProgressionSettingsRemote? _remote;
  Future<void> _queue = Future.value();

  static String _key(String userId) => 'progression_settings_$userId';
  static String _dirtyKey(String userId) =>
      'progression_settings_dirty_$userId';

  Future<SharedPreferences> get _store async =>
      _prefs ??= await SharedPreferences.getInstance();

  /// Przełącza na konto [userId] (`null` — wylogowanie: progresja wyłączona).
  Future<void> attach(String? userId, ProgressionSettingsRemote? remote) {
    _userId = userId;
    _remote = remote;
    return _queue = _queue.then((_) => _attach(userId, remote));
  }

  Future<void> _attach(
    String? userId,
    ProgressionSettingsRemote? remote,
  ) async {
    if (userId == null) {
      notifier.value = ProgressionSettings.off;
      return;
    }
    var dirty = false;
    try {
      final prefs = await _store;
      final raw = prefs.getString(_key(userId));
      if (_userId != userId) return;
      final cached = raw == null
          ? null
          : ProgressionSettings.fromJson(jsonDecode(raw));
      notifier.value = cached ?? ProgressionSettings.off;
      dirty = prefs.getBool(_dirtyKey(userId)) ?? false;
    } catch (_) {
      notifier.value = ProgressionSettings.off;
    }
    if (remote == null) return;
    try {
      if (dirty) {
        await _push(userId, remote, notifier.value);
      } else {
        final fromServer = await remote.fetch();
        if (_userId != userId || fromServer == null) return;
        if (fromServer != notifier.value) {
          notifier.value = fromServer;
          await _cache(userId, fromServer, dirty: false);
        }
      }
    } catch (_) {
      /* offline — zostaje kopia z telefonu */
    }
  }

  /// Zapisuje wybór: od razu lokalnie, potem na serwer.
  Future<void> set(ProgressionSettings settings) {
    final userId = _userId;
    notifier.value = settings;
    if (userId == null) return Future.value();
    final remote = _remote;
    return _queue = _queue.then((_) async {
      try {
        await _cache(userId, settings, dirty: true);
        if (remote != null && notifier.value == settings) {
          await _push(userId, remote, settings);
        }
      } catch (_) {
        /* zostaje „dirty” — pójdzie przy następnym starcie */
      }
    });
  }

  Future<void> _push(
    String userId,
    ProgressionSettingsRemote remote,
    ProgressionSettings settings,
  ) async {
    await remote.save(settings);
    if (notifier.value == settings) {
      await _cache(userId, settings, dirty: false);
    }
  }

  Future<void> _cache(
    String userId,
    ProgressionSettings settings, {
    required bool dirty,
  }) async {
    final prefs = await _store;
    await prefs.setString(_key(userId), jsonEncode(settings.toJson()));
    await prefs.setBool(_dirtyKey(userId), dirty);
  }

  /// Czeka, aż zapisy i synchronizacja się skończą (testy).
  @visibleForTesting
  Future<void> get idle => _queue;
}
