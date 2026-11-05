import 'package:flutter/foundation.dart';

/// Cele czasu rozgrzewki do wyboru (minuty).
const kWarmupTargetChoices = [5, 8, 10, 15];

/// Domyślny cel czasu rozgrzewki (minuty).
const kWarmupDefaultTargetMinutes = 8;

/// Rozgrzewka starsza niż tyle jest uznawana za zapomnianą i znika.
const kWarmupMaxAge = Duration(minutes: 60);

/// Ustawienia rozgrzewki przed treningiem (osobno dla konta, na telefonie).
@immutable
class WarmupSettings {
  const WarmupSettings({
    this.enabled,
    this.targetMinutes = kWarmupDefaultTargetMinutes,
  });

  /// `null` — użytkownik jeszcze nie wybierał (przy pierwszym starcie
  /// zapytamy). Wygląda jak wyłączona.
  final bool? enabled;
  final int targetMinutes;

  /// Czy zapytać przy najbliższym starcie treningu.
  bool get shouldAsk => enabled == null;

  /// Czy start treningu ma najpierw otwierać panel rozgrzewki.
  bool get isOn => enabled == true;

  WarmupSettings copyWith({bool? enabled, int? targetMinutes}) =>
      WarmupSettings(
        enabled: enabled ?? this.enabled,
        targetMinutes: targetMinutes ?? this.targetMinutes,
      );

  @override
  bool operator ==(Object other) =>
      other is WarmupSettings &&
      other.enabled == enabled &&
      other.targetMinutes == targetMinutes;

  @override
  int get hashCode => Object.hash(enabled, targetMinutes);
}

/// Z jakiego miejsca użytkownik zaczął trening, przed którym jest rozgrzewka.
enum WarmupTargetKind {
  /// Trening z planu ([WarmupTarget.refId] to id planu).
  plan,

  /// Trening bez planu.
  custom,

  /// „Powtórz” z historii ([WarmupTarget.refId] to id powtarzanej sesji).
  repeat,
}

/// Trening, przed którym trwa rozgrzewka.
@immutable
class WarmupTarget {
  const WarmupTarget({required this.kind, this.refId, required this.name});

  const WarmupTarget.plan({required String planId, required String name})
    : this(kind: WarmupTargetKind.plan, refId: planId, name: name);

  const WarmupTarget.custom({String name = 'Trening bez planu'})
    : this(kind: WarmupTargetKind.custom, name: name);

  const WarmupTarget.repeat({required String sessionId, required String name})
    : this(kind: WarmupTargetKind.repeat, refId: sessionId, name: name);

  final WarmupTargetKind kind;
  final String? refId;

  /// Nazwa do pokazania („przed: Push A”).
  final String name;

  /// Dwa starty z tym samym kluczem to ten sam trening.
  String get key => '${kind.name}:${refId ?? ''}';

  @override
  bool operator ==(Object other) =>
      other is WarmupTarget && other.key == key && other.name == name;

  @override
  int get hashCode => Object.hash(key, name);
}

/// Trwająca rozgrzewka: stoper liczy od [startedAt].
@immutable
class WarmupInProgress {
  const WarmupInProgress({
    required this.target,
    required this.startedAt,
    required this.targetMinutes,
  });

  final WarmupTarget target;
  final DateTime startedAt;
  final int targetMinutes;

  Duration get targetDuration => Duration(minutes: targetMinutes);

  /// Ile już trwa rozgrzewka (nigdy ujemne, nawet gdy zegar telefonu cofnięto).
  Duration elapsed(DateTime now) {
    final value = now.difference(startedAt);
    return value.isNegative ? Duration.zero : value;
  }

  bool isGoalReached(DateTime now) => elapsed(now) >= targetDuration;

  WarmupInProgress copyWith({int? targetMinutes}) => WarmupInProgress(
    target: target,
    startedAt: startedAt,
    targetMinutes: targetMinutes ?? this.targetMinutes,
  );

  Map<String, Object?> toJson() => {
    'kind': target.kind.name,
    'refId': target.refId,
    'name': target.name,
    'startedAt': startedAt.millisecondsSinceEpoch,
    'targetMinutes': targetMinutes,
  };

  static WarmupInProgress? fromJson(Object? json) {
    if (json is! Map) return null;
    final kindName = json['kind'];
    final name = json['name'];
    final startedAt = json['startedAt'];
    final targetMinutes = json['targetMinutes'];
    final refId = json['refId'];
    if (kindName is! String || name is! String || startedAt is! int) {
      return null;
    }
    WarmupTargetKind? kind;
    for (final value in WarmupTargetKind.values) {
      if (value.name == kindName) kind = value;
    }
    if (kind == null) return null;
    return WarmupInProgress(
      target: WarmupTarget(
        kind: kind,
        refId: refId is String ? refId : null,
        name: name,
      ),
      startedAt: DateTime.fromMillisecondsSinceEpoch(startedAt),
      targetMinutes: targetMinutes is int && targetMinutes > 0
          ? targetMinutes
          : kWarmupDefaultTargetMinutes,
    );
  }
}

/// Minuty `mm:ss` do stopera (`03:12`, `12:05`).
/// Najkrótsza rozgrzewka, którą zapisujemy przy treningu (krótsza to brak).
const int kWarmupSaveMinSeconds = 60;

/// Najdłuższa zapisywana rozgrzewka (jak limit na serwerze).
const int kWarmupSaveMaxSeconds = 7200;

/// Sekundy rozgrzewki do zapisania przy sesji: `null`, gdy była krótsza niż
/// minuta (przypadkowe stuknięcie), a zbyt długa jest obcinana do limitu.
int? warmupSecondsToSave(Duration elapsed) {
  final seconds = elapsed.inSeconds;
  if (seconds < kWarmupSaveMinSeconds) return null;
  return seconds > kWarmupSaveMaxSeconds ? kWarmupSaveMaxSeconds : seconds;
}

String formatWarmupClock(Duration duration) {
  final total = duration.inSeconds;
  final minutes = total ~/ 60;
  final seconds = total % 60;
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}
