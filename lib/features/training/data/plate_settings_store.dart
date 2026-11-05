import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/units/weight_unit.dart';
import '../domain/models/plate_equipment.dart';

/// Ustawienia kalkulatora talerzy — urządzenia, nie konta (jak jednostka).
class PlateSettings {
  const PlateSettings({
    required this.kg,
    required this.lb,
    this.showInRest = true,
    this.barbellExercises = const {},
  });

  factory PlateSettings.defaults() => PlateSettings(
    kg: PlateEquipment.defaults(WeightUnit.kg),
    lb: PlateEquipment.defaults(WeightUnit.lb),
  );

  final PlateEquipment kg;
  final PlateEquipment lb;

  /// Pasek „Na stronę” w panelu odpoczynku.
  final bool showInRest;

  /// Ćwiczenia ([statsExerciseKey]), przy których użyto kalkulatora — tylko
  /// przy nich pasek pojawia się w przerwie (model ćwiczenia nie wie, czy
  /// to sztanga).
  final Set<String> barbellExercises;

  PlateEquipment equipmentFor(WeightUnit unit) =>
      unit == WeightUnit.kg ? kg : lb;

  PlateSettings withEquipment(WeightUnit unit, PlateEquipment equipment) =>
      unit == WeightUnit.kg ? copyWith(kg: equipment) : copyWith(lb: equipment);

  PlateSettings copyWith({
    PlateEquipment? kg,
    PlateEquipment? lb,
    bool? showInRest,
    Set<String>? barbellExercises,
  }) => PlateSettings(
    kg: kg ?? this.kg,
    lb: lb ?? this.lb,
    showInRest: showInRest ?? this.showInRest,
    barbellExercises: barbellExercises ?? this.barbellExercises,
  );

  Map<String, Object> toJson() => {
    'kg': kg.toJson(),
    'lb': lb.toJson(),
    'showInRest': showInRest,
    'barbell': barbellExercises.toList(),
  };

  static PlateSettings fromJson(Object? json) {
    if (json is! Map) return PlateSettings.defaults();
    final barbell = json['barbell'];
    return PlateSettings(
      kg: PlateEquipment.fromJson(json['kg'], WeightUnit.kg),
      lb: PlateEquipment.fromJson(json['lb'], WeightUnit.lb),
      showInRest: json['showInRest'] != false,
      barbellExercises: barbell is List
          ? {
              for (final key in barbell)
                if (key is String) key,
            }
          : const {},
    );
  }
}

/// Aktualne ustawienia kalkulatora talerzy. Ekrany słuchają [notifier],
/// więc zmiana w „Twój sprzęt” od razu trafia do otwartego arkusza.
abstract final class PlateSettingsStore {
  static const prefsKey = 'plate_calculator_settings';

  static final ValueNotifier<PlateSettings> notifier = ValueNotifier(
    PlateSettings.defaults(),
  );

  static PlateSettings get current => notifier.value;

  /// Wczytuje zapisane ustawienia; błąd odczytu zostawia domyślne.
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(prefsKey);
      notifier.value = raw == null
          ? PlateSettings.defaults()
          : PlateSettings.fromJson(jsonDecode(raw));
    } catch (_) {
      notifier.value = PlateSettings.defaults();
    }
  }

  static Future<void> save(PlateSettings settings) async {
    notifier.value = settings;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsKey, jsonEncode(settings.toJson()));
    } catch (_) {
      /* ustawienie działa do końca sesji aplikacji */
    }
  }

  static Future<void> updateEquipment(
    WeightUnit unit,
    PlateEquipment equipment,
  ) => save(current.withEquipment(unit, equipment));

  /// Zapamiętuje ćwiczenie jako robione ze sztangą.
  static Future<void> markBarbell(String exerciseKey) async {
    if (current.barbellExercises.contains(exerciseKey)) return;
    await save(
      current.copyWith(
        barbellExercises: {...current.barbellExercises, exerciseKey},
      ),
    );
  }
}
