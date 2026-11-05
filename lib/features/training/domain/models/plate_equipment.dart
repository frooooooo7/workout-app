import '../../../../core/units/weight_unit.dart';

/// Talerz w zestawie użytkownika. [weight] jest w jednostce zestawu
/// ([PlateEquipment] dla kg albo dla lb), nie zawsze w kilogramach.
class PlateOption {
  const PlateOption({
    required this.weight,
    this.enabled = true,
    this.custom = false,
  });

  final double weight;

  /// Wyłączonego talerza kalkulator nie używa (np. siłownia go nie ma).
  final bool enabled;

  /// Talerz dodany przez użytkownika — można go usunąć z zestawu.
  final bool custom;

  PlateOption copyWith({bool? enabled}) => PlateOption(
    weight: weight,
    enabled: enabled ?? this.enabled,
    custom: custom,
  );

  Map<String, Object> toJson() => {
    'w': weight,
    if (!enabled) 'off': true,
    if (custom) 'custom': true,
  };

  static PlateOption? fromJson(Object? json) {
    if (json is! Map) return null;
    final raw = json['w'];
    final weight = raw is num ? raw.toDouble() : null;
    if (weight == null || weight <= 0) return null;
    return PlateOption(
      weight: weight,
      enabled: json['off'] != true,
      custom: json['custom'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PlateOption &&
      other.weight == weight &&
      other.enabled == enabled &&
      other.custom == custom;

  @override
  int get hashCode => Object.hash(weight, enabled, custom);
}

/// Gryf i talerze na siłowni użytkownika — w jednej jednostce. Osobny zestaw
/// dla kilogramów i funtów, bo funtowe talerze mają inne nominały.
class PlateEquipment {
  const PlateEquipment({required this.barWeight, required this.plates});

  /// Waga gryfu; 0 — maszyna ładowana talerzami, bez gryfu.
  final double barWeight;

  /// Od najcięższego.
  final List<PlateOption> plates;

  static const _kgStandardPlates = <double>[25.0, 20, 15, 10, 5, 2.5, 1.25];
  static const _lbStandardPlates = <double>[45.0, 35, 25, 10, 5, 2.5];

  /// Gotowe wagi gryfu w przełączniku (plus „Brak” i „Inny”).
  static List<double> standardBars(WeightUnit unit) =>
      unit == WeightUnit.kg ? const [20, 15, 10] : const [45, 35, 25];

  /// Największy standardowy talerz — odniesienie dla rozmiaru rysunku.
  static double heaviestStandardPlate(WeightUnit unit) =>
      unit == WeightUnit.kg ? 25 : 45;

  static PlateEquipment defaults(WeightUnit unit) => PlateEquipment(
    barWeight: standardBars(unit).first,
    plates: [
      for (final w
          in unit == WeightUnit.kg ? _kgStandardPlates : _lbStandardPlates)
        PlateOption(weight: w),
    ],
  );

  /// Wagi włączonych talerzy, od najcięższego.
  List<double> get enabledPlates => [
    for (final plate in plates)
      if (plate.enabled) plate.weight,
  ];

  /// Najmniejszy sensowny skok ciężaru: para najmniejszych włączonych
  /// talerzy (2,5 kg przy talerzach 1,25 kg). Bez talerzy — [fallback].
  double weightStep({double fallback = 2.5}) {
    final enabled = enabledPlates;
    if (enabled.isEmpty) return fallback;
    final smallest = enabled.reduce((a, b) => a < b ? a : b);
    return smallest * 2;
  }

  PlateEquipment copyWith({double? barWeight, List<PlateOption>? plates}) {
    final next = List<PlateOption>.of(plates ?? this.plates)
      ..sort((a, b) => b.weight.compareTo(a.weight));
    return PlateEquipment(barWeight: barWeight ?? this.barWeight, plates: next);
  }

  PlateEquipment togglePlate(double weight) => copyWith(
    plates: [
      for (final plate in plates)
        plate.weight == weight
            ? plate.copyWith(enabled: !plate.enabled)
            : plate,
    ],
  );

  /// Dodaje własny talerz; istniejący nominał tylko się włącza.
  PlateEquipment addPlate(double weight) {
    if (plates.any((p) => p.weight == weight)) {
      return copyWith(
        plates: [
          for (final plate in plates)
            plate.weight == weight ? plate.copyWith(enabled: true) : plate,
        ],
      );
    }
    return copyWith(
      plates: [
        ...plates,
        PlateOption(weight: weight, custom: true),
      ],
    );
  }

  PlateEquipment removePlate(double weight) => copyWith(
    plates: [
      for (final plate in plates)
        if (plate.weight != weight || !plate.custom) plate,
    ],
  );

  Map<String, Object> toJson() => {
    'bar': barWeight,
    'plates': [for (final plate in plates) plate.toJson()],
  };

  /// Uszkodzone dane to zestaw domyślny — kalkulator ma zawsze działać.
  static PlateEquipment fromJson(Object? json, WeightUnit unit) {
    if (json is! Map) return defaults(unit);
    final rawBar = json['bar'];
    final bar = rawBar is num ? rawBar.toDouble() : null;
    final rawPlates = json['plates'];
    if (bar == null || bar < 0 || rawPlates is! List) return defaults(unit);
    final plates = [for (final raw in rawPlates) ?PlateOption.fromJson(raw)];
    return PlateEquipment(
      barWeight: bar,
      plates: const [],
    ).copyWith(plates: plates);
  }

  @override
  bool operator ==(Object other) {
    if (other is! PlateEquipment || other.barWeight != barWeight) return false;
    if (other.plates.length != plates.length) return false;
    for (var i = 0; i < plates.length; i++) {
      if (other.plates[i] != plates[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(barWeight, Object.hashAll(plates));
}
