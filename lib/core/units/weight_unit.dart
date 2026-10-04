import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Jednostka, w której aplikacja pokazuje i przyjmuje ciężary.
///
/// Dane (lokalna baza, API) zawsze trzymają kilogramy — jednostka zmienia
/// tylko to, co widzi użytkownik, i to, jak rozumiemy wpisaną liczbę.
enum WeightUnit {
  kg,
  lb;

  /// `kg` / `lb` — dopisek za liczbą.
  String get label => name;

  /// Nagłówek kolumny w tabeli serii.
  String get columnLabel => name.toUpperCase();

  /// Ciężar w kilogramach przeliczony na tę jednostkę.
  double fromKg(double kg) => this == WeightUnit.kg ? kg : kg / kKgPerLb;

  /// Liczba w tej jednostce przeliczona na kilogramy.
  double toKg(double value) => this == WeightUnit.kg ? value : value * kKgPerLb;
}

/// Definicja funta międzynarodowego.
const kKgPerLb = 0.45359237;

/// Aktualna jednostka ciężaru — ustawienie urządzenia (nie konta), domyślnie
/// kilogramy. Formatery czytają [current]; po zmianie [WeightUnitScope]
/// przebudowuje całe drzewo, żeby nowa jednostka pojawiła się wszędzie,
/// także na ekranach pod spodem w stosie nawigacji.
abstract final class WeightUnits {
  static const prefsKey = 'weight_unit';

  static final ValueNotifier<WeightUnit> notifier = ValueNotifier(
    WeightUnit.kg,
  );

  static WeightUnit get current => notifier.value;

  /// Wczytuje zapisaną jednostkę; błąd odczytu zostawia kilogramy.
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(prefsKey);
      notifier.value = WeightUnit.values.firstWhere(
        (u) => u.name == saved,
        orElse: () => WeightUnit.kg,
      );
    } catch (_) {
      notifier.value = WeightUnit.kg;
    }
  }

  static Future<void> set(WeightUnit unit) async {
    notifier.value = unit;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, unit.name);
  }
}

/// Ciężar w aktualnej jednostce: `82,5`, `80` — ułamek tylko gdy coś wnosi.
/// W funtach do jednego miejsca po przecinku (`182,5`), bo krążki funtowe
/// mają 2,5 lb.
String formatWeightNumber(double kg, {WeightUnit? unit}) =>
    formatDisplayNumber((unit ?? WeightUnits.current).fromKg(kg));

/// `82,5 kg` / `182 lb`.
String formatWeightWithUnit(double kg, {WeightUnit? unit}) {
  final u = unit ?? WeightUnits.current;
  return '${formatWeightNumber(kg, unit: u)} ${u.label}';
}

/// Liczba z jednym miejscem po przecinku, bez zbędnego zera: `80`, `82,5`.
String formatDisplayNumber(double value) {
  final rounded = (value * 10).round() / 10;
  if (rounded == rounded.roundToDouble()) return rounded.toInt().toString();
  return rounded.toStringAsFixed(1).replaceAll('.', ',');
}

/// `82,5` → 82.5; `60 kg` → 60; `''` / `abc` → `null`.
double? parseWeightNumber(String? raw) {
  if (raw == null) return null;
  final cleaned = raw
      .trim()
      .replaceAll(',', '.')
      .replaceAll(RegExp(r'[^0-9.]'), '');
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}

/// Surowy ciężar serii (tekst w kilogramach, tak jak leży w bazie) w postaci
/// do pola tekstowego w aktualnej jednostce. W kilogramach tekst wraca bez
/// zmian, żeby nie ruszać tego, co użytkownik wpisał.
String weightTextForInput(String? rawKg, {WeightUnit? unit}) {
  final u = unit ?? WeightUnits.current;
  final raw = rawKg ?? '';
  if (u == WeightUnit.kg) return raw;
  final kg = parseWeightNumber(raw);
  if (kg == null) return raw.trim().isEmpty ? '' : raw;
  return formatDisplayNumber(u.fromKg(kg));
}

/// Odwrotność [weightTextForInput]: tekst wpisany w aktualnej jednostce jako
/// tekst w kilogramach do zapisu. Funty zapisujemy z dokładnością do 0,01 kg —
/// tyle wystarcza, żeby 225 lb wróciło jako 225 lb.
String weightTextFromInput(String text, {WeightUnit? unit}) {
  final u = unit ?? WeightUnits.current;
  if (u == WeightUnit.kg) return text;
  final value = parseWeightNumber(text);
  if (value == null) return text;
  final kg = (u.toKg(value) * 100).round() / 100;
  return kg == kg.roundToDouble() ? kg.toInt().toString() : kg.toString();
}
