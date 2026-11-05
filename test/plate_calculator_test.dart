import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/units/weight_unit.dart';
import 'package:gym/features/training/data/plate_settings_store.dart';
import 'package:gym/features/training/domain/models/plate_equipment.dart';
import 'package:gym/features/training/domain/services/plate_calculator.dart';
import 'package:gym/features/training/presentation/widgets/plates/plate_visuals.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const kgPlates = <double>[25.0, 20, 15, 10, 5, 2.5, 1.25];

  group('PlateCalculator', () {
    test('loads 100 kg with the fewest plates, heaviest first', () {
      final result = PlateCalculator.calculate(
        target: 100,
        barWeight: 20,
        plates: kgPlates,
      );

      expect(result.isExact, isTrue);
      expect(result.exact!.perSide, [25, 15]);
      expect(result.exact!.total, 100);
      expect(result.exact!.counts, {25: 1, 15: 1});
    });

    test('uses small change plates for 102,5 kg', () {
      final result = PlateCalculator.calculate(
        target: 102.5,
        barWeight: 20,
        plates: kgPlates,
      );

      expect(result.exact!.perSide, [25, 15, 1.25]);
    });

    test('offers the nearest lighter and heavier loads when inexact', () {
      final result = PlateCalculator.calculate(
        target: 101,
        barWeight: 20,
        plates: kgPlates,
      );

      expect(result.isExact, isFalse);
      expect(result.lower!.total, 100);
      expect(result.upper!.total, 102.5);
      // Rysunek pokazuje niższy, możliwy układ.
      expect(result.shown!.total, 100);
    });

    test('is not fooled by plates where greedy fails', () {
      final result = PlateCalculator.calculate(
        target: 60,
        barWeight: 20,
        plates: [15, 10],
      );

      expect(result.exact!.perSide, [10, 10]);
    });

    test('recognises a weight below the bar', () {
      final result = PlateCalculator.calculate(
        target: 15,
        barWeight: 20,
        plates: kgPlates,
      );

      expect(result.belowBar, isTrue);
      expect(result.shown, isNull);
    });

    test('bar alone is an exact load without plates', () {
      final result = PlateCalculator.calculate(
        target: 20,
        barWeight: 20,
        plates: kgPlates,
      );

      expect(result.exact!.perSide, isEmpty);
    });

    test('without plates only the bar is possible', () {
      final result = PlateCalculator.calculate(
        target: 40,
        barWeight: 20,
        plates: const [],
      );

      expect(result.lower!.total, 20);
      expect(result.upper, isNull);
    });

    test('works in pounds and without a bar', () {
      final lb = PlateCalculator.calculate(
        target: 225,
        barWeight: 45,
        plates: PlateEquipment.defaults(WeightUnit.lb).enabledPlates,
      );
      expect(lb.exact!.perSide, [45, 45]);

      final machine = PlateCalculator.calculate(
        target: 90,
        barWeight: 0,
        plates: kgPlates,
      );
      expect(machine.exact!.perSide, [25, 20]);
    });
  });

  group('PlateEquipment', () {
    test('defaults per unit and the weight step', () {
      final kg = PlateEquipment.defaults(WeightUnit.kg);
      expect(kg.barWeight, 20);
      expect(kg.enabledPlates, kgPlates);
      expect(kg.weightStep(), 2.5);

      final noSmallPlates = kg.togglePlate(1.25);
      expect(noSmallPlates.enabledPlates, isNot(contains(1.25)));
      expect(noSmallPlates.weightStep(), 5);

      expect(PlateEquipment.defaults(WeightUnit.lb).barWeight, 45);
    });

    test('adds and removes custom plates, keeping order', () {
      final kg = PlateEquipment.defaults(WeightUnit.kg).addPlate(0.5);
      expect(kg.plates.last.weight, 0.5);
      expect(kg.plates.last.custom, isTrue);
      expect(kg.weightStep(), 1);

      // Standardowego talerza nie da się usunąć, własny — tak.
      expect(kg.removePlate(25).plates.first.weight, 25);
      expect(kg.removePlate(0.5).plates.map((p) => p.weight), kgPlates);
    });

    test('survives a JSON round trip and falls back on bad data', () {
      final custom = PlateEquipment.defaults(
        WeightUnit.kg,
      ).copyWith(barWeight: 15).togglePlate(25).addPlate(0.5);
      final restored = PlateEquipment.fromJson(
        jsonDecode(jsonEncode(custom.toJson())),
        WeightUnit.kg,
      );
      expect(restored, custom);

      expect(
        PlateEquipment.fromJson({'bar': 'x'}, WeightUnit.kg),
        PlateEquipment.defaults(WeightUnit.kg),
      );
    });
  });

  group('PlateSettingsStore', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('persists equipment, the rest strip and barbell exercises', () async {
      await PlateSettingsStore.load();
      await PlateSettingsStore.updateEquipment(
        WeightUnit.kg,
        PlateEquipment.defaults(WeightUnit.kg).copyWith(barWeight: 0),
      );
      await PlateSettingsStore.markBarbell('name:bench press');
      await PlateSettingsStore.save(
        PlateSettingsStore.current.copyWith(showInRest: false),
      );

      PlateSettingsStore.notifier.value = PlateSettings.defaults();
      await PlateSettingsStore.load();

      final settings = PlateSettingsStore.current;
      expect(settings.kg.barWeight, 0);
      expect(settings.lb.barWeight, 45);
      expect(settings.showInRest, isFalse);
      expect(settings.barbellExercises, {'name:bench press'});
    });

    test('broken saved data loads the defaults', () async {
      SharedPreferences.setMockInitialValues({
        PlateSettingsStore.prefsKey: '{not json',
      });
      await PlateSettingsStore.load();
      expect(
        PlateSettingsStore.current.kg,
        PlateEquipment.defaults(WeightUnit.kg),
      );
    });
  });

  test('formatPlateNumber keeps quarter kilos', () {
    expect(formatPlateNumber(100), '100');
    expect(formatPlateNumber(102.5), '102,5');
    expect(formatPlateNumber(101.25), '101,25');
    expect(formatPlateNumber(41.2), '41,2');
  });
}
