/// Przypomnienie o treningu w wybrane dni tygodnia o stałej godzinie.
/// Ustawienie urządzenia (nie konta), jak powiadomienie o końcu przerwy.
class WorkoutReminder {
  const WorkoutReminder({
    this.enabled = false,
    this.weekdays = defaultWeekdays,
    this.hour = 18,
    this.minute = 0,
  });

  /// Pn, Śr, Pt — sensowny start przy pierwszym włączeniu.
  static const defaultWeekdays = {
    DateTime.monday,
    DateTime.wednesday,
    DateTime.friday,
  };

  final bool enabled;

  /// Numeracja jak [DateTime.weekday]: 1 = poniedziałek … 7 = niedziela.
  final Set<int> weekdays;
  final int hour;
  final int minute;

  /// Włączone i z co najmniej jednym dniem — tylko wtedy coś planujemy.
  bool get isActive => enabled && weekdays.isNotEmpty;

  WorkoutReminder copyWith({
    bool? enabled,
    Set<int>? weekdays,
    int? hour,
    int? minute,
  }) {
    return WorkoutReminder(
      enabled: enabled ?? this.enabled,
      weekdays: weekdays ?? this.weekdays,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
    );
  }

  WorkoutReminder toggleWeekday(int weekday) {
    final next = {...weekdays};
    if (!next.remove(weekday)) next.add(weekday);
    return copyWith(weekdays: next);
  }

  @override
  bool operator ==(Object other) =>
      other is WorkoutReminder &&
      other.enabled == enabled &&
      other.hour == hour &&
      other.minute == minute &&
      other.weekdays.length == weekdays.length &&
      other.weekdays.containsAll(weekdays);

  @override
  int get hashCode =>
      Object.hash(enabled, hour, minute, Object.hashAllUnordered(weekdays));
}

/// Najbliższy moment przypomnienia w dniu [weekday] o [hour]:[minute],
/// liczony od [now] (ściśle w przyszłości). Czysta funkcja — strefę czasową
/// dokłada wywołujący.
DateTime nextWorkoutReminderOccurrence({
  required DateTime now,
  required int weekday,
  required int hour,
  required int minute,
}) {
  final daysAhead = (weekday - now.weekday) % DateTime.daysPerWeek;
  var candidate = DateTime(
    now.year,
    now.month,
    now.day + daysAhead,
    hour,
    minute,
  );
  if (!candidate.isAfter(now)) {
    candidate = DateTime(
      candidate.year,
      candidate.month,
      candidate.day + DateTime.daysPerWeek,
      hour,
      minute,
    );
  }
  return candidate;
}
