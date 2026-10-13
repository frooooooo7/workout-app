import '../../../../core/units/weight_unit.dart';
import '../../../training/presentation/widgets/stats/stats_format.dart';
import '../../domain/models/body_measurement_entry.dart';

/// `84,5`, `80` — obwody i tłuszcz nie zależą od jednostki ciężaru.
String formatMeasurementValue(double value) => formatDisplayNumber(value);

/// `84,5 cm`, `15,2%`
String formatMeasurement(BodyMeasurementField field, double value) =>
    field.isPercent
    ? '${formatMeasurementValue(value)}%'
    : '${formatMeasurementValue(value)} cm';

/// `−1,5 cm`, `+0,4%`, `0 cm` — znak zawsze widoczny przy zmianie.
String formatMeasurementChange(BodyMeasurementField field, double change) {
  if (change == 0) return formatMeasurement(field, 0);
  final sign = change > 0 ? '+' : '−';
  return '$sign${formatMeasurement(field, change.abs())}';
}

/// Krótka nazwa do listy wpisów.
String measurementShortLabel(BodyMeasurementField field) => switch (field) {
  BodyMeasurementField.chest => 'Klatka',
  BodyMeasurementField.bodyFat => 'Tłuszcz',
  _ => field.label,
};

/// `39,0`, `105,5` — zawsze jedno miejsce po przecinku, żeby wartości na
/// sylwetce i w tabeli miały tę samą szerokość.
String formatMeasurementFixed(double value) =>
    value.toStringAsFixed(1).replaceAll('.', ',');

/// `+1,3`, `−3,5`, `0,0` — zmiana bez jednostki (kolumny z jednostką
/// w nagłówku).
String formatMeasurementDelta(double change) {
  final text = formatMeasurementFixed(change.abs());
  if (change == 0) return text;
  return change > 0 ? '+$text' : '−$text';
}

/// `3 sie`, a dla innego roku niż [today]: `3 sie 2025`.
String formatMeasurementDate(DateTime date, DateTime today) {
  final dayMonth = formatStatsDayMonth(date);
  return date.year == today.year ? dayMonth : '$dayMonth ${date.year}';
}
