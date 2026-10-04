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
