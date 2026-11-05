import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/warmup.dart';

/// Ustawienia rozgrzewki zalogowanego konta (Ustawienia → Rozgrzewka przed
/// treningiem). Zapisane na telefonie, osobno dla każdego konta — klucz
/// kończy się id konta, więc usunięcie konta czyści je razem z resztą.
class WarmupSettingsStore {
  WarmupSettingsStore({SharedPreferences? prefs}) : _prefs = prefs;

  SharedPreferences? _prefs;

  final ValueNotifier<WarmupSettings> notifier = ValueNotifier(
    const WarmupSettings(),
  );

  WarmupSettings get current => notifier.value;

  String? _userId;
  Future<void> _queue = Future.value();

  static String key(String userId) => 'warmup_settings_$userId';

  Future<SharedPreferences> get _store async =>
      _prefs ??= await SharedPreferences.getInstance();

  /// Przełącza na konto [userId] (`null` — wylogowanie).
  Future<void> attach(String? userId) {
    _userId = userId;
    return _queue = _queue.then((_) => _load(userId));
  }

  Future<void> _load(String? userId) async {
    if (userId == null) {
      notifier.value = const WarmupSettings();
      return;
    }
    try {
      final prefs = await _store;
      final raw = prefs.getString(key(userId));
      if (_userId != userId) return;
      notifier.value = raw == null
          ? const WarmupSettings()
          : _fromJson(jsonDecode(raw));
    } catch (_) {
      if (_userId == userId) notifier.value = const WarmupSettings();
    }
  }

  static WarmupSettings _fromJson(Object? json) {
    if (json is! Map) return const WarmupSettings();
    final enabled = json['enabled'];
    final minutes = json['targetMinutes'];
    return WarmupSettings(
      enabled: enabled is bool ? enabled : null,
      targetMinutes: minutes is int && kWarmupTargetChoices.contains(minutes)
          ? minutes
          : kWarmupDefaultTargetMinutes,
    );
  }

  /// Każdy wybór (także „nie”) zapisuje decyzję, więc pytanie przy starcie
  /// już się nie powtórzy.
  Future<void> setEnabled(bool enabled) =>
      _set(current.copyWith(enabled: enabled));

  Future<void> setTargetMinutes(int minutes) =>
      _set(current.copyWith(targetMinutes: minutes));

  Future<void> _set(WarmupSettings settings) {
    final userId = _userId;
    notifier.value = settings;
    if (userId == null) return Future.value();
    return _queue = _queue.then((_) async {
      try {
        final prefs = await _store;
        await prefs.setString(
          key(userId),
          jsonEncode({
            'enabled': settings.enabled,
            'targetMinutes': settings.targetMinutes,
          }),
        );
      } catch (_) {
        /* zostaje w pamięci do końca działania aplikacji */
      }
    });
  }
}

/// Trwająca rozgrzewka (jedna naraz). Stoper liczy od zapisanej godziny
/// startu, więc przeżywa zablokowany ekran i zamknięcie aplikacji; ekran
/// Trening słucha [notifier], żeby pokazać kartę „Trwa rozgrzewka”.
class WarmupSessionStore {
  WarmupSessionStore({SharedPreferences? prefs, DateTime Function()? clock})
    : _prefs = prefs,
      _clock = clock ?? DateTime.now;

  SharedPreferences? _prefs;
  final DateTime Function() _clock;

  final ValueNotifier<WarmupInProgress?> notifier = ValueNotifier(null);

  WarmupInProgress? get current => notifier.value;

  String? _userId;
  Future<void> _queue = Future.value();

  static String key(String userId) => 'warmup_active_$userId';

  Future<SharedPreferences> get _store async =>
      _prefs ??= await SharedPreferences.getInstance();

  /// Przełącza na konto [userId]; rozgrzewka starsza niż [kWarmupMaxAge]
  /// jest uznawana za zapomnianą.
  Future<void> attach(String? userId) {
    _userId = userId;
    return _queue = _queue.then((_) => _load(userId));
  }

  Future<void> _load(String? userId) async {
    if (userId == null) {
      notifier.value = null;
      return;
    }
    try {
      final prefs = await _store;
      final raw = prefs.getString(key(userId));
      if (_userId != userId) return;
      final saved = raw == null
          ? null
          : WarmupInProgress.fromJson(jsonDecode(raw));
      if (saved == null) {
        notifier.value = null;
        return;
      }
      if (_isStale(saved)) {
        notifier.value = null;
        await prefs.remove(key(userId));
        return;
      }
      notifier.value = saved;
    } catch (_) {
      if (_userId == userId) notifier.value = null;
    }
  }

  bool _isStale(WarmupInProgress warmup) =>
      _clock().difference(warmup.startedAt) > kWarmupMaxAge;

  /// Trwająca rozgrzewka albo `null` (także gdy ją zapomniano). Nie zmienia
  /// stanu, więc można ją wołać z `build`; zapomniany wpis znika przy
  /// następnym starcie rozgrzewki albo po ponownym wczytaniu konta.
  WarmupInProgress? get active {
    final warmup = current;
    if (warmup == null || _isStale(warmup)) return null;
    return warmup;
  }

  Future<void> begin(WarmupTarget target, int targetMinutes) => _set(
    WarmupInProgress(
      target: target,
      startedAt: _clock(),
      targetMinutes: targetMinutes,
    ),
  );

  /// Zmiana celu tylko na dziś — nie dotyka ustawień konta.
  Future<void> setTargetMinutes(int minutes) {
    final warmup = current;
    if (warmup == null) return Future.value();
    return _set(warmup.copyWith(targetMinutes: minutes));
  }

  Future<void> clear() => _set(null);

  Future<void> _set(WarmupInProgress? warmup) {
    final userId = _userId;
    notifier.value = warmup;
    if (userId == null) return Future.value();
    return _queue = _queue.then((_) async {
      try {
        final prefs = await _store;
        if (warmup == null) {
          await prefs.remove(key(userId));
        } else {
          await prefs.setString(key(userId), jsonEncode(warmup.toJson()));
        }
      } catch (_) {
        /* zostaje w pamięci do końca działania aplikacji */
      }
    });
  }
}
