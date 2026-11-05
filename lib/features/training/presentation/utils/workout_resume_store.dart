import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Gdzie użytkownik był w trwającym treningu: ćwiczenie na ekranie
/// i przerwa, która trwała, gdy wyszedł.
class WorkoutResumeSnapshot {
  const WorkoutResumeSnapshot({
    required this.sessionId,
    this.exerciseId,
    this.restEndsAt,
    this.restTotal,
    this.restTitle,
  });

  final String sessionId;

  /// Id ćwiczenia w sesji (nie indeks — kolejność może się zmienić).
  final String? exerciseId;

  /// Koniec przerwy (także już minionej, gdy panel stał na „0:00”).
  final DateTime? restEndsAt;
  final Duration? restTotal;
  final String? restTitle;

  Map<String, Object?> toJson() => {
    'sessionId': sessionId,
    'exerciseId': exerciseId,
    'restEndsAt': restEndsAt?.millisecondsSinceEpoch,
    'restTotal': restTotal?.inSeconds,
    'restTitle': restTitle,
  };

  static WorkoutResumeSnapshot? fromJson(Object? json) {
    if (json is! Map) return null;
    final sessionId = json['sessionId'];
    if (sessionId is! String) return null;
    final endsAt = json['restEndsAt'];
    final total = json['restTotal'];
    final exerciseId = json['exerciseId'];
    final title = json['restTitle'];
    return WorkoutResumeSnapshot(
      sessionId: sessionId,
      exerciseId: exerciseId is String ? exerciseId : null,
      restEndsAt: endsAt is int
          ? DateTime.fromMillisecondsSinceEpoch(endsAt)
          : null,
      restTotal: total is int ? Duration(seconds: total) : null,
      restTitle: title is String ? title : null,
    );
  }
}

/// Pamięta [WorkoutResumeSnapshot] między wyjściem z ekranu treningu
/// a powrotem do niego. Kopia w pamięci daje stan od pierwszej klatki;
/// kopia w SharedPreferences przeżywa zamknięcie aplikacji.
class WorkoutResumeStore {
  WorkoutResumeStore._();

  static const _key = 'ongoing_workout_resume';

  static WorkoutResumeSnapshot? _memory;

  /// Stan z pamięci, jeśli dotyczy [sessionId].
  static WorkoutResumeSnapshot? peek(String sessionId) {
    final memory = _memory;
    return memory?.sessionId == sessionId ? memory : null;
  }

  /// Stan zapisany na dysku (np. po zamknięciu aplikacji).
  static Future<WorkoutResumeSnapshot?> load(String sessionId) async {
    final cached = peek(sessionId);
    if (cached != null) return cached;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;
      final snapshot = WorkoutResumeSnapshot.fromJson(jsonDecode(raw));
      if (snapshot?.sessionId != sessionId) return null;
      _memory = snapshot;
      return snapshot;
    } catch (_) {
      return null;
    }
  }

  static void save(WorkoutResumeSnapshot snapshot) {
    _memory = snapshot;
    unawaited(_write(jsonEncode(snapshot.toJson())));
  }

  /// Po zakończeniu albo odrzuceniu treningu.
  static void clear() {
    _memory = null;
    unawaited(_write(null));
  }

  static Future<void> _write(String? value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value == null) {
        await prefs.remove(_key);
      } else {
        await prefs.setString(_key, value);
      }
    } catch (_) {
      /* brak zapisu = start od wyliczonego ćwiczenia, nic więcej */
    }
  }

  /// Tylko testy.
  static void resetForTest() => _memory = null;
}
