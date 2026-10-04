import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/units/weight_unit.dart';
import 'package:gym/core/units/weight_unit_scope.dart';
import 'package:gym/features/auth/domain/models/auth_models.dart';
import 'package:gym/features/profile/domain/models/body_measurement_entry.dart';
import 'package:gym/features/profile/presentation/screens/profile_settings_screen.dart';
import 'package:gym/features/profile/presentation/utils/body_measurement_format.dart';
import 'package:gym/features/profile/presentation/utils/profile_details_labels.dart';
import 'package:gym/features/profile/presentation/widgets/body_weight_chart.dart';
import 'package:gym/features/training/domain/models/training_history_models.dart';
import 'package:gym/features/training/domain/models/training_session.dart';
import 'package:gym/features/training/domain/models/training_stats.dart';
import 'package:gym/features/training/domain/repositories/previous_performance_repository.dart';
import 'package:gym/features/training/presentation/widgets/personal_record_format.dart';
import 'package:gym/features/training/presentation/widgets/session_details/session_details_formatters.dart';
import 'package:gym/features/training/presentation/widgets/stats/stats_format.dart';
import 'package:gym/features/training/presentation/widgets/table_cell_input.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'change_password_test.dart' show FakeAccountRepository;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => WeightUnits.notifier.value = WeightUnit.kg);

  group('conversion', () {
    test('kg is the identity, lb uses the international pound', () {
      expect(WeightUnit.kg.fromKg(80), 80);
      expect(WeightUnit.lb.fromKg(100), closeTo(220.462, 0.001));
      expect(WeightUnit.lb.toKg(225), closeTo(102.058, 0.001));
    });

    test('lb typed into a set field survives the round trip through kg', () {
      for (final typed in ['225', '227,5', '45', '2.5', '135']) {
        final stored = weightTextFromInput(typed, unit: WeightUnit.lb);
        expect(
          weightTextForInput(stored, unit: WeightUnit.lb),
          typed.replaceAll('.', ','),
          reason: 'typed $typed, stored $stored',
        );
      }
      expect(weightTextFromInput('225', unit: WeightUnit.lb), '102.06');
    });

    test('kg text passes through untouched', () {
      expect(weightTextFromInput('82,5', unit: WeightUnit.kg), '82,5');
      expect(weightTextForInput(' 60 ', unit: WeightUnit.kg), ' 60 ');
      expect(weightTextForInput(null, unit: WeightUnit.lb), '');
    });
  });

  group('preference', () {
    test('defaults to kg and persists the choice', () async {
      await WeightUnits.load();
      expect(WeightUnits.current, WeightUnit.kg);

      await WeightUnits.set(WeightUnit.lb);
      WeightUnits.notifier.value = WeightUnit.kg;
      await WeightUnits.load();

      expect(WeightUnits.current, WeightUnit.lb);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(WeightUnits.prefsKey), 'lb');
    });
  });

  group('formatters in lb', () {
    setUp(() => WeightUnits.notifier.value = WeightUnit.lb);

    test('sets, volume and records', () {
      expect(
        formatSetMetrics(const TrainingSetMetrics(weightKg: 100, reps: 5)),
        '220,5 lb × 5',
      );
      expect(_plain(formatVolumeKg(1000)), '2 205 lb');
      expect(_plain(formatVolumeKg(50000)), '110 tys. lb');
      final volume = formatStatsVolume(1000);
      expect((_plain(volume.value), volume.unit), ('2 205', 'lb'));
      expect(formatStatsWeight(100), '220,5 lb');
      expect(formatStatsWeight(100, digits: 0), '220 lb');
    });

    test('body weight shows whole pounds, changes keep a decimal', () {
      // 180 lb zapisane z dokładnością do 0,1 kg (81,6 kg) wraca jako 180.
      expect(formatWeightKg(81.6), '180 lb');
      expect(formatWeightChange(0.2), '+0,4 lb');
      expect(formatWeightChange(0), '0 lb');
      expect(formatWeightRange(), '70–660 lb');
    });

    test('new records in the summary and the feed', () {
      final record = PersonalRecord(
        exerciseKey: 'bench',
        exerciseName: 'Wyciskanie',
        exerciseId: 'bench',
        sessionId: 's1',
        date: DateTime(2026, 10, 4),
        kinds: const {PersonalRecordKind.weight},
        weightKg: 100,
        reps: 3,
        improvement: 2.5,
      );
      expect(personalRecordValue(record), '220,5 lb × 3');
      expect(personalRecordImprovement(record), '+5,5 lb');
    });

    test('body measurements stay in centimetres', () {
      expect(formatMeasurement(BodyMeasurementField.waist, 84.5), '84,5 cm');
      expect(formatMeasurementValue(80), '80');
    });

    test('previous set column converts the stored kg text', () {
      expect(
        formatPreviousSet(
          TrainingSessionSet(actualWeight: '100', actualReps: '5'),
        ),
        '220,5×5',
      );
    });
  });

  test('kg formatting is unchanged', () {
    expect(
      formatSetMetrics(const TrainingSetMetrics(weightKg: 82.5, reps: 8)),
      '82,5 kg × 8',
    );
    expect(formatVolumeKg(8450), '8,45 t');
    expect(formatWeightKg(82.5), '82,5 kg');
    expect(
      formatPreviousSet(
        TrainingSessionSet(actualWeight: '82,5', actualReps: '8'),
      ),
      '82,5×8',
    );
  });

  testWidgets('scope rebuilds weights already on screen after a switch', (
    tester,
  ) async {
    await tester.pumpWidget(
      WeightUnitScope(
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(builder: (_) => Text(formatWeightWithUnit(100))),
        ),
      ),
    );
    expect(find.text('100 kg'), findsOneWidget);

    await WeightUnits.set(WeightUnit.lb);
    await tester.pump();

    expect(find.text('220,5 lb'), findsOneWidget);
  });

  testWidgets('settings switch changes the unit', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileSettingsScreen(
          user: const AuthUser(
            id: 'user-1',
            email: 'jan@example.com',
            firstName: 'Jan',
            lastName: 'Kowalski',
          ),
          accountRepository: FakeAccountRepository(),
        ),
      ),
    );
    expect(find.text('Jednostka ciężaru'), findsOneWidget);

    await tester.tap(find.byKey(settingsWeightUnitOptionKey(WeightUnit.lb)));
    await tester.pump();

    expect(WeightUnits.current, WeightUnit.lb);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(WeightUnits.prefsKey), 'lb');
  });

  testWidgets('lb set field keeps half-typed input and reports kg', (
    tester,
  ) async {
    WeightUnits.notifier.value = WeightUnit.lb;
    String? stored = '100';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => WeightCellInput(
              valueKg: stored,
              onChanged: (kg) => setState(() => stored = kg),
            ),
          ),
        ),
      ),
    );
    expect(find.text('220,5'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '22.');
    await tester.pump();
    expect(find.text('22.'), findsOneWidget);
    expect(stored, '9.98');

    await tester.enterText(find.byType(TextField), '22.5');
    await tester.pump();
    expect(find.text('22.5'), findsOneWidget);
    expect(stored, '10.21');
  });
}

/// Separator tysięcy to twarda spacja.
String _plain(String text) => text.replaceAll('\u00a0', ' ');
