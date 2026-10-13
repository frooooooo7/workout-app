import 'dart:math' as math;

import '../models/body_weight_entry.dart';

/// Okres wykresu na ekranie masy ciała.
enum BodyWeightRange {
  days30('30 dni', 30),
  days90('3 mies.', 90),
  year('Rok', 365),
  all('Całość', null);

  const BodyWeightRange(this.label, this.days);

  final String label;

  /// `null` — cała historia.
  final int? days;

  /// Pierwszy dzień okresu kończącego się w [today] (włącznie); `null`
  /// dla całej historii.
  DateTime? startFor(DateTime today) {
    final d = days;
    if (d == null) return null;
    return DateTime(today.year, today.month, today.day - (d - 1));
  }
}

/// Zmiana wagi między pierwszym a ostatnim pomiarem w okresie.
class BodyWeightTrend {
  const BodyWeightTrend({required this.first, required this.last});

  final BodyWeightEntry first;
  final BodyWeightEntry last;

  /// Ujemna — spadek. Zaokrąglona do 0,1 kg, jak same pomiary.
  double get changeKg => ((last.weightKg - first.weightKg) * 10).round() / 10;
}

/// Pomiary z dni [start]..[end] (oba włącznie, `null` = bez granicy).
/// [sorted] musi być posortowana od najstarszego.
List<BodyWeightEntry> bodyWeightEntriesBetween(
  List<BodyWeightEntry> sorted, {
  DateTime? start,
  DateTime? end,
}) {
  return [
    for (final e in sorted)
      if ((start == null || !e.date.isBefore(start)) &&
          (end == null || !e.date.isAfter(end)))
        e,
  ];
}

/// Trend z pomiarów okresu; `null`, gdy są mniej niż dwa.
BodyWeightTrend? bodyWeightTrend(List<BodyWeightEntry> entriesInRange) {
  if (entriesInRange.length < 2) return null;
  return BodyWeightTrend(
    first: entriesInRange.first,
    last: entriesInRange.last,
  );
}

/// Dni między dwiema datami (liczą się tylko daty; UTC — bez skoków przy
/// zmianie czasu).
int bodyWeightDaysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// Linia trendu: wygładzona średnia wykładnicza pomiarów (stała czasowa
/// [timeConstantDays] dni, z uwzględnieniem przerw między pomiarami).
/// Dzienny szum (woda, posiłki) znika, kierunek zostaje. Jedna wartość na
/// pomiar; [sorted] musi być posortowana od najstarszego.
List<double> bodyWeightSmoothedTrend(
  List<BodyWeightEntry> sorted, {
  double timeConstantDays = 7,
}) {
  final result = <double>[];
  for (var i = 0; i < sorted.length; i++) {
    if (i == 0) {
      result.add(sorted[i].weightKg);
      continue;
    }
    final gap = bodyWeightDaysBetween(sorted[i - 1].date, sorted[i].date);
    final weight = 1 - math.exp(-gap / timeConstantDays);
    final previous = result.last;
    result.add(previous + weight * (sorted[i].weightKg - previous));
  }
  return result;
}

/// Średnia z pomiarów z [days] dni kończących się ostatnim pomiarem;
/// `null` bez pomiarów.
double? bodyWeightRecentAverage(List<BodyWeightEntry> sorted, {int days = 7}) {
  if (sorted.isEmpty) return null;
  final last = sorted.last.date;
  final recent = [
    for (final e in sorted)
      if (bodyWeightDaysBetween(e.date, last) < days) e.weightKg,
  ];
  return recent.reduce((a, b) => a + b) / recent.length;
}

/// Tempo zmiany w kg na tydzień — nachylenie prostej dopasowanej
/// (najmniejsze kwadraty) do pomiarów z [days] dni kończących się
/// ostatnim pomiarem. `null`, gdy pomiary nie obejmują co najmniej tygodnia.
double? bodyWeightWeeklyPace(List<BodyWeightEntry> sorted, {int days = 28}) {
  if (sorted.length < 2) return null;
  final last = sorted.last.date;
  final window = [
    for (final e in sorted)
      if (bodyWeightDaysBetween(e.date, last) < days) e,
  ];
  if (window.length < 2 || bodyWeightDaysBetween(window.first.date, last) < 7) {
    return null;
  }
  final xs = [for (final e in window) bodyWeightDaysBetween(last, e.date)];
  final meanX = xs.reduce((a, b) => a + b) / xs.length;
  final meanY =
      window.map((e) => e.weightKg).reduce((a, b) => a + b) / window.length;
  var cov = 0.0;
  var varX = 0.0;
  for (var i = 0; i < window.length; i++) {
    cov += (xs[i] - meanX) * (window[i].weightKg - meanY);
    varX += (xs[i] - meanX) * (xs[i] - meanX);
  }
  return cov / varX * 7;
}

/// Postęp do celu masy ciała: od pierwszego pomiaru w historii ([startKg])
/// do [goalKg], według ostatniego pomiaru ([currentKg]).
class BodyWeightGoalProgress {
  const BodyWeightGoalProgress({
    required this.startKg,
    required this.currentKg,
    required this.goalKg,
  });

  final double startKg;
  final double currentKg;
  final double goalKg;

  /// Ile jeszcze zostało (zawsze nieujemne, 0 po osiągnięciu celu).
  double get remainingKg => reached ? 0 : (goalKg - currentKg).abs();

  /// Cel osiągnięty albo przekroczony w kierunku, w którym prowadził.
  bool get reached {
    final direction = (goalKg - startKg).sign;
    if (direction == 0) return (currentKg - goalKg).abs() < 0.05;
    return (goalKg - currentKg) * direction <= 0;
  }

  /// 0–1. Oddalenie się od celu względem startu liczy się jako 0.
  double get fraction {
    if (reached) return 1;
    final total = goalKg - startKg;
    if (total == 0) return 0;
    return ((currentKg - startKg) / total).clamp(0.0, 1.0);
  }

  /// Czy zmiana [changeKg] przybliża do celu.
  bool isTowardGoal(double changeKg) =>
      changeKg != 0 && changeKg.sign == (goalKg - currentKg).sign;
}

/// Przewidywany dzień osiągnięcia celu przy tempie [pacePerWeekKg], licząc
/// od [fromKg] w dniu [from]. `null`, gdy trend prowadzi w złą stronę, stoi
/// w miejscu albo cel jest dalej niż [maxDays] dni.
DateTime? bodyWeightGoalDate({
  required double fromKg,
  required double goalKg,
  required double? pacePerWeekKg,
  required DateTime from,
  int maxDays = 730,
}) {
  final pace = pacePerWeekKg;
  if (pace == null || pace == 0) return null;
  final days = (goalKg - fromKg) / pace * 7;
  if (days <= 0 || days > maxDays) return null;
  return DateTime(from.year, from.month, from.day + days.ceil());
}

/// Tydzień (poniedziałek–niedziela) na liście pomiarów.
class BodyWeightWeek {
  const BodyWeightWeek({
    required this.start,
    required this.entries,
    this.previousAverageKg,
  });

  /// Poniedziałek.
  final DateTime start;

  /// Od najnowszego.
  final List<BodyWeightEntry> entries;

  /// Średnia z poprzedniego tygodnia z pomiarami; `null` dla najstarszego.
  final double? previousAverageKg;

  DateTime get end => DateTime(start.year, start.month, start.day + 6);

  double get averageKg =>
      entries.map((e) => e.weightKg).reduce((a, b) => a + b) / entries.length;

  /// Zmiana średniej względem poprzedniego tygodnia, zaokrąglona do 0,1 kg.
  double? get changeKg {
    final previous = previousAverageKg;
    if (previous == null) return null;
    return ((averageKg - previous) * 10).round() / 10;
  }
}

/// Pomiary pogrupowane w tygodnie, od najnowszego. Tygodnie bez pomiarów
/// są pomijane. [sorted] musi być posortowana od najstarszego.
List<BodyWeightWeek> bodyWeightWeeks(List<BodyWeightEntry> sorted) {
  final groups = <DateTime, List<BodyWeightEntry>>{};
  for (final e in sorted) {
    final monday = DateTime(
      e.date.year,
      e.date.month,
      e.date.day - (e.date.weekday - 1),
    );
    (groups[monday] ??= []).add(e);
  }
  final weeks = <BodyWeightWeek>[];
  double? previous;
  for (final MapEntry(key: start, value: entries) in groups.entries) {
    final week = BodyWeightWeek(
      start: start,
      entries: entries.reversed.toList(),
      previousAverageKg: previous,
    );
    weeks.add(week);
    previous = week.averageKg;
  }
  return weeks.reversed.toList();
}
