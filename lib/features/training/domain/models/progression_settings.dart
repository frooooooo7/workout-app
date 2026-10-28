import 'package:flutter/foundation.dart';

import '../../../../core/units/weight_unit.dart';

/// Krok albo procent do dwóch miejsc po przecinku: `2,5`, `1,25`, `5`
/// (zwykłe formatery ciężaru zaokrąglają do 0,1, a 1,25 kg to popularny
/// krok).
String formatStepNumber(double value) {
  final rounded = (value * 100).round() / 100;
  if (rounded == rounded.roundToDouble()) return rounded.toInt().toString();
  var text = rounded.toStringAsFixed(2);
  if (text.endsWith('0')) text = text.substring(0, text.length - 1);
  return text.replaceAll('.', ',');
}

/// Jak aplikacja podpowiada ciężar na następny trening.
enum ProgressionMethod {
  /// Bez zwyżki — podpowiedź to ostatni ciężar.
  none('none', 'Wyłączona'),

  /// +krok, gdy zrobiono wszystkie zaplanowane powtórzenia.
  fixed('fixed', 'Stały krok'),

  /// +X % ciężaru, zaokrąglone do kroku (najmniejszych krążków).
  percent('percent', 'Procentowo'),

  /// Najpierw powtórzenia do górnej granicy zakresu, potem +krok.
  doubleProgression('double', 'Podwójna progresja'),

  /// +krok, gdy w serii został zapas (RIR ≥ próg).
  rir('rir', 'Według RIR');

  const ProgressionMethod(this.apiName, this.label);

  /// Nazwa w API (`double` to słowo kluczowe typu w Dart, stąd różnica).
  final String apiName;
  final String label;

  static ProgressionMethod fromApi(String? value) {
    for (final method in values) {
      if (method.apiName == value) return method;
    }
    return none;
  }

  /// Metody, które dokładają ciężar o krok (mają „krok”, „zwiększaj po”
  /// i deload).
  bool get usesStep => this != none;
}

/// Ustawienia progresji konta albo jednego planu.
///
/// Krok trzymamy w jednostce, w której go wybrano ([unit]) — 5 lb zostaje
/// 5 lb, a nie 2,27 kg. Ciężary w sesjach są w kilogramach, więc liczymy
/// w kg przez [stepKg] / [legStepKg].
@immutable
class ProgressionSettings {
  const ProgressionSettings({
    this.method = ProgressionMethod.none,
    this.unit = WeightUnit.kg,
    this.step = 2.5,
    this.legStep,
    this.percent = 2.5,
    this.rirThreshold = 2,
    this.sessionsToIncrease = 1,
    this.deload = false,
  });

  /// Domyślnie progresja jest wyłączona — nikt nie dostaje +2,5 kg, którego
  /// nie wybrał.
  static const off = ProgressionSettings();

  /// Plany sprzed tej funkcji: wybrany w planie krok (w kg) to stały krok.
  factory ProgressionSettings.legacyStep(double stepKg) =>
      ProgressionSettings(method: ProgressionMethod.fixed, step: stepKg);

  /// Gotowe kroki w danej jednostce (reszta przez „Inny…”).
  static List<num> stepPresets(WeightUnit unit) => unit == WeightUnit.kg
      ? const [0.5, 1, 1.25, 2, 2.5, 5]
      : const [1, 2.5, 5, 10];

  static List<num> legStepPresets(WeightUnit unit) =>
      unit == WeightUnit.kg ? const [2.5, 5, 10] : const [5, 10, 20];

  static const percentPresets = <num>[1, 2.5, 5];

  /// Domyślny krok nóg, gdy ktoś włącza „Większy krok dla nóg”.
  static double defaultLegStep(WeightUnit unit) =>
      unit == WeightUnit.kg ? 5 : 10;

  final ProgressionMethod method;
  final WeightUnit unit;
  final double step;

  /// Większy krok dla ćwiczeń na nogi; `null` = jak [step].
  final double? legStep;
  final double percent;
  final int rirThreshold;

  /// Ile udanych treningów z rzędu przed zwyżką (1 albo 2).
  final int sessionsToIncrease;

  /// −10 % po 3 nieudanych treningach z rzędu.
  final bool deload;

  static const deloadAfterFailures = 3;
  static const deloadFactor = 0.9;

  bool get isOff => method == ProgressionMethod.none;

  double get stepKg => unit.toKg(step);
  double? get legStepKg => legStep == null ? null : unit.toKg(legStep!);

  /// Krok dla ćwiczenia (nogi mogą mieć większy), w kg.
  double stepKgFor({required bool legs}) =>
      legs ? (legStepKg ?? stepKg) : stepKg;

  /// Te same ustawienia z krokiem przeliczonym na [target] i zaokrąglonym do
  /// najbliższej gotowej wartości (2,5 kg → 5 lb) — po zmianie jednostki.
  ProgressionSettings inUnit(WeightUnit target) {
    if (target == unit) return this;
    num nearest(double value, List<num> presets) {
      final converted = target.fromKg(unit.toKg(value));
      return presets.reduce(
        (a, b) => (a - converted).abs() <= (b - converted).abs() ? a : b,
      );
    }

    return ProgressionSettings(
      method: method,
      unit: target,
      step: nearest(step, stepPresets(target)).toDouble(),
      legStep: legStep == null
          ? null
          : nearest(legStep!, legStepPresets(target)).toDouble(),
      percent: percent,
      rirThreshold: rirThreshold,
      sessionsToIncrease: sessionsToIncrease,
      deload: deload,
    );
  }

  /// `+2,5 kg`, `+2,5 %`, `+5 lb`.
  String get stepLabel => method == ProgressionMethod.percent
      ? '+${formatStepNumber(percent)} %'
      : '+${formatStepNumber(step)} ${unit.label}';

  /// Krótko do wiersza ustawień i ustawień planu: „Stały krok · +2,5 kg”.
  String get summary => isOff ? method.label : '${method.label} · $stepLabel';

  /// Jedna linijka pod nazwą metody na liście.
  String get description => switch (method) {
    ProgressionMethod.none => 'Bez podpowiedzi zwyżki, sam decydujesz',
    ProgressionMethod.fixed => '$stepLabel, gdy zrobisz wszystkie powtórzenia',
    ProgressionMethod.percent =>
      '$stepLabel ciężaru, zaokrąglone do '
          '${formatStepNumber(step)} ${unit.label}',
    ProgressionMethod.doubleProgression =>
      'Najpierw powtórzenia do góry zakresu, potem $stepLabel',
    ProgressionMethod.rir =>
      '$stepLabel, gdy zostało ≥ $rirThreshold powt. zapasu',
  };

  ProgressionSettings copyWith({
    ProgressionMethod? method,
    WeightUnit? unit,
    double? step,
    double? legStep,
    bool clearLegStep = false,
    double? percent,
    int? rirThreshold,
    int? sessionsToIncrease,
    bool? deload,
  }) => ProgressionSettings(
    method: method ?? this.method,
    unit: unit ?? this.unit,
    step: step ?? this.step,
    legStep: clearLegStep ? null : (legStep ?? this.legStep),
    percent: percent ?? this.percent,
    rirThreshold: rirThreshold ?? this.rirThreshold,
    sessionsToIncrease: sessionsToIncrease ?? this.sessionsToIncrease,
    deload: deload ?? this.deload,
  );

  Map<String, Object?> toJson() => {
    'method': method.apiName,
    'unit': unit.name,
    'step': step,
    'legStep': legStep,
    'percent': percent,
    'rirThreshold': rirThreshold,
    'sessionsToIncrease': sessionsToIncrease,
    'deload': deload,
  };

  /// `null` dla czegoś, co nie jest mapą (brak ustawień). Brakujące albo
  /// błędne pola dostają wartości domyślne.
  static ProgressionSettings? fromJson(Object? json) {
    if (json is! Map) return null;
    double? positive(Object? value) =>
        value is num && value > 0 && value <= 50 ? value.toDouble() : null;
    final unitName = json['unit'];
    final sessions = json['sessionsToIncrease'];
    final rir = json['rirThreshold'];
    return ProgressionSettings(
      method: ProgressionMethod.fromApi(json['method'] as String?),
      unit: unitName == 'lb' ? WeightUnit.lb : WeightUnit.kg,
      step: positive(json['step']) ?? 2.5,
      legStep: positive(json['legStep']),
      percent: positive(json['percent']) ?? 2.5,
      rirThreshold: rir is num ? rir.toInt().clamp(1, 5) : 2,
      sessionsToIncrease: sessions is num ? sessions.toInt().clamp(1, 3) : 1,
      deload: json['deload'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ProgressionSettings &&
      other.method == method &&
      other.unit == unit &&
      other.step == step &&
      other.legStep == legStep &&
      other.percent == percent &&
      other.rirThreshold == rirThreshold &&
      other.sessionsToIncrease == sessionsToIncrease &&
      other.deload == deload;

  @override
  int get hashCode => Object.hash(
    method,
    unit,
    step,
    legStep,
    percent,
    rirThreshold,
    sessionsToIncrease,
    deload,
  );

  @override
  String toString() => 'ProgressionSettings(${toJson()})';
}
