import 'profile_details.dart';

/// Jeden pomiar masy ciała — najwyżej jeden na dzień kalendarzowy.
class BodyWeightEntry {
  const BodyWeightEntry({required this.date, required this.weightKg});

  /// Sama data (lokalna północ) — dzień pomiaru w strefie użytkownika.
  final DateTime date;
  final double weightKg;

  factory BodyWeightEntry.fromJson(Map<String, dynamic> json) {
    final date = parseIsoDate(json['date'] as String?);
    final weight = json['weightKg'];
    if (date == null || weight is! num) {
      throw FormatException('Invalid body weight entry: $json');
    }
    return BodyWeightEntry(date: date, weightKg: weight.toDouble());
  }

  @override
  bool operator ==(Object other) =>
      other is BodyWeightEntry &&
      other.date == date &&
      other.weightKg == weightKg;

  @override
  int get hashCode => Object.hash(date, weightKg);

  @override
  String toString() => 'BodyWeightEntry(${formatIsoDate(date)}, $weightKg)';
}
