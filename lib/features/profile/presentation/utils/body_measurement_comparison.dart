import '../../domain/models/body_measurement_entry.dart';

/// Ostatnia wartość pomiaru w porównywanym okresie i zmiana od pierwszej
/// (`null`, gdy w okresie jest tylko jeden pomiar tego obwodu).
typedef BodyMeasurementDelta = ({double value, double? change});

/// Porównanie dwóch wpisów: wartości z końca okresu [from]–[to] i ich
/// zmiana od początku. Pomiar, którego nie było w danym wpisie, bierze
/// najbliższy wpis w okresie, który go ma.
class BodyMeasurementComparison {
  const BodyMeasurementComparison._(this.from, this.to, this.deltas);

  /// Porównanie [from]–[to] (daty wpisów z [sorted]); domyślnie, albo gdy
  /// któregoś wpisu już nie ma, pierwszy wpis z ostatnim. `null` — brak
  /// wpisów. [sorted] musi być posortowana od najstarszego.
  static BodyMeasurementComparison? of(
    List<BodyMeasurementEntry> sorted, {
    DateTime? from,
    DateTime? to,
  }) {
    if (sorted.isEmpty) return null;
    final dates = {for (final e in sorted) e.date};
    var start = sorted.first.date;
    var end = sorted.last.date;
    if (from != null &&
        to != null &&
        dates.contains(from) &&
        dates.contains(to) &&
        from.isBefore(to)) {
      start = from;
      end = to;
    }
    final inRange = [
      for (final e in sorted)
        if (!e.date.isBefore(start) && !e.date.isAfter(end)) e,
    ];
    return BodyMeasurementComparison._(start, end, {
      for (final field in BodyMeasurementField.values)
        field: ?_delta(bodyMeasurementSeries(inRange, field)),
    });
  }

  final DateTime from;
  final DateTime to;
  final Map<BodyMeasurementField, BodyMeasurementDelta> deltas;

  /// `false` przy jednym wpisie — nie ma czego porównywać.
  bool get hasRange => from != to;

  static BodyMeasurementDelta? _delta(List<BodyMeasurementPoint> series) {
    if (series.isEmpty) return null;
    final last = series.last.value;
    return (
      value: last,
      change: series.length < 2
          ? null
          : roundMeasurementChange(series.first.value, last),
    );
  }
}

/// Zmiana zaokrąglona do 0,1, jak same pomiary.
double roundMeasurementChange(double from, double to) =>
    ((to - from) * 10).round() / 10;
