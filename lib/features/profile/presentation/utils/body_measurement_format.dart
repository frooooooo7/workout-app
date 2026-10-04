import '../../domain/models/body_measurement_entry.dart';
import '../../../../core/units/weight_unit.dart';

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
