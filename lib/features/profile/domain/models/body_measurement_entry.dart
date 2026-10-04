import 'profile_details.dart';

/// Rodzaj pomiaru ciała. Obwody w centymetrach, tkanka tłuszczowa w %.
enum BodyMeasurementField {
  waist('waistCm', 'waist_cm', 'Talia'),
  chest('chestCm', 'chest_cm', 'Klatka piersiowa'),
  hips('hipsCm', 'hips_cm', 'Biodra'),
  neck('neckCm', 'neck_cm', 'Szyja'),
  arm('armCm', 'arm_cm', 'Ramię'),
  thigh('thighCm', 'thigh_cm', 'Udo'),
  calf('calfCm', 'calf_cm', 'Łydka'),
  bodyFat('bodyFatPct', 'body_fat_pct', 'Tkanka tłuszczowa');

  const BodyMeasurementField(this.jsonKey, this.column, this.label);

  /// Klucz w API (`/profile/me/body-measurements`).
  final String jsonKey;

  /// Kolumna w lokalnej bazie.
  final String column;
  final String label;

  bool get isPercent => this == BodyMeasurementField.bodyFat;

  String get unit => isPercent ? '%' : 'cm';

  /// Te same granice co walidacja na serwerze.
  double get min => isPercent ? 2 : 10;
  double get max => isPercent ? 75 : 300;

  bool accepts(double value) => value >= min && value <= max;
}

/// Pomiary ciała z jednego dnia — najwyżej jeden wpis na dzień
/// kalendarzowy, z co najmniej jedną wartością.
class BodyMeasurementEntry {
  BodyMeasurementEntry({
    required this.date,
    required Map<BodyMeasurementField, double> values,
  }) : values = Map.unmodifiable(values);

  /// Sama data (lokalna północ) — dzień pomiaru w strefie użytkownika.
  final DateTime date;

  /// Tylko zmierzone wartości, zaokrąglone do 0,1.
  final Map<BodyMeasurementField, double> values;

  double? operator [](BodyMeasurementField field) => values[field];

  factory BodyMeasurementEntry.fromJson(Map<String, dynamic> json) {
    final date = parseIsoDate(json['date'] as String?);
    if (date == null) {
      throw FormatException('Invalid body measurement entry: $json');
    }
    return BodyMeasurementEntry(
      date: date,
      values: {
        for (final field in BodyMeasurementField.values)
          if (json[field.jsonKey] case final num value) field: value.toDouble(),
      },
    );
  }

  /// Ciało `PUT` — brakujące pola jako `null` (serwer je czyści).
  Map<String, dynamic> toJson() => {
    for (final field in BodyMeasurementField.values)
      field.jsonKey: values[field],
  };

  @override
  bool operator ==(Object other) {
    if (other is! BodyMeasurementEntry ||
        other.date != date ||
        other.values.length != values.length) {
      return false;
    }
    for (final MapEntry(:key, :value) in values.entries) {
      if (other.values[key] != value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    date,
    Object.hashAllUnordered([
      for (final MapEntry(:key, :value) in values.entries)
        Object.hash(key, value),
    ]),
  );

  @override
  String toString() => 'BodyMeasurementEntry(${formatIsoDate(date)}, $values)';
}

/// Wartość pola w kolejnych wpisach — punkty wykresu i zmiana.
typedef BodyMeasurementPoint = ({DateTime date, double value});

/// Wpisy, w których zmierzono [field], od najstarszego.
/// [sorted] musi być posortowana od najstarszego.
List<BodyMeasurementPoint> bodyMeasurementSeries(
  List<BodyMeasurementEntry> sorted,
  BodyMeasurementField field,
) {
  return [
    for (final e in sorted)
      if (e[field] case final value?) (date: e.date, value: value),
  ];
}
