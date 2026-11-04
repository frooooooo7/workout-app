import 'dart:convert';

/// Sprzęt ćwiczenia. Wartość w API i bazie: [apiName].
enum ExerciseEquipment {
  barbell('barbell', 'Sztanga'),
  dumbbell('dumbbell', 'Hantle'),
  kettlebell('kettlebell', 'Kettlebell'),
  cable('cable', 'Wyciąg'),
  machine('machine', 'Maszyna'),
  bodyweight('bodyweight', 'Masa ciała'),
  band('band', 'Guma'),
  other('other', 'Inne');

  const ExerciseEquipment(this.apiName, this.label);

  final String apiName;
  final String label;

  /// `null` dla braku lub nieznanej wartości (nowsza wersja API).
  static ExerciseEquipment? tryParse(String? value) {
    if (value == null) return null;
    for (final item in values) {
      if (item.apiName == value) return item;
    }
    return null;
  }
}

/// „Jak wykonać”: kroki i częste błędy.
class ExerciseInstructions {
  const ExerciseInstructions({this.steps = const [], this.mistakes = const []});

  final List<String> steps;
  final List<String> mistakes;

  bool get isEmpty => steps.isEmpty && mistakes.isEmpty;

  Map<String, dynamic> toJson() => {'steps': steps, 'mistakes': mistakes};

  String encode() => jsonEncode(toJson());

  /// Przyjmuje mapę z API albo tekst JSON z bazy; `null` dla pustego lub
  /// uszkodzonego wejścia.
  static ExerciseInstructions? tryParse(Object? raw) {
    try {
      final Object? decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is! Map) return null;
      List<String> list(Object? v) => v is List
          ? [
              for (final item in v)
                if (item is String && item.isNotEmpty) item,
            ]
          : const [];
      final result = ExerciseInstructions(
        steps: list(decoded['steps']),
        mistakes: list(decoded['mistakes']),
      );
      return result.isEmpty ? null : result;
    } catch (_) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is ExerciseInstructions &&
      _listEq(other.steps, steps) &&
      _listEq(other.mistakes, mistakes);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(steps), Object.hashAll(mistakes));

  static bool _listEq(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Dodatkowe pola własnego ćwiczenia z formularza: sprzęt, inne nazwy
/// i „Jak wykonać”. W `update` przekazane [ExerciseExtras] zastępują
/// zapisane wartości w całości (`null` w repozytorium — bez zmian).
class ExerciseExtras {
  const ExerciseExtras({
    this.equipment,
    this.aliases = const [],
    this.instructions,
  });

  final ExerciseEquipment? equipment;
  final List<String> aliases;
  final ExerciseInstructions? instructions;
}
