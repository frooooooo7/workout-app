import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/units/weight_unit.dart';
import 'package:gym/features/training/data/plate_settings_store.dart';
import 'package:gym/features/training/domain/models/custom_training_plan.dart';
import 'package:gym/features/training/domain/models/training_session.dart';
import 'package:gym/features/training/domain/repositories/training_session_repository.dart';
import 'package:gym/features/training/domain/services/rest_timer_scheduler.dart';
import 'package:gym/features/training/presentation/bloc/training_session_cubit.dart';
import 'package:gym/features/training/presentation/screens/ongoing_workout_screen.dart';
import 'package:gym/features/training/presentation/screens/plate_equipment_screen.dart';
import 'package:gym/features/training/presentation/widgets/plates/plate_calculator_sheet.dart';
import 'package:gym/features/training/presentation/widgets/plates/rest_plate_strip.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PlateSettingsStore.notifier.value = PlateSettings.defaults();
    WeightUnits.notifier.value = WeightUnit.kg;
  });

  /// Telefon 390 × 844 — arkusz mieści się bez przewijania.
  void usePhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Future<(_FakeRepository, TrainingSessionCubit)> pumpWorkout(
    WidgetTester tester, {
    required String plannedWeight,
    int sets = 1,
  }) async {
    usePhoneSize(tester);
    final repository = _FakeRepository(_session(plannedWeight, sets: sets));
    final cubit = TrainingSessionCubit(repository, autoRefresh: false);
    await tester.pumpWidget(
      MaterialApp(
        home: OngoingWorkoutScreen(
          args: OngoingWorkoutArgs(
            initialSession: repository.session,
            sessionCubit: cubit,
            restTimerScheduler: _FakeRestTimerScheduler(),
          ),
        ),
      ),
    );
    await tester.pump();
    return (repository, cubit);
  }

  Future<void> openFromTile(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('session-exercise-plates-0')));
    await tester.pumpAndSettle();
  }

  testWidgets('tile opens the calculator with the next set and fills it in', (
    tester,
  ) async {
    final (repository, cubit) = await pumpWorkout(tester, plannedWeight: '100');

    await openFromTile(tester);

    expect(find.byType(PlateCalculatorSheet), findsOneWidget);
    expect(find.text('Bench press · seria 1'), findsOneWidget);
    expect(find.text('NA KAŻDĄ STRONĘ'), findsOneWidget);
    // 100 kg = gryf 20 + na stronę 25 i 15.
    expect(find.byKey(const ValueKey('plate-legend-25')), findsOneWidget);
    expect(find.byKey(const ValueKey('plate-legend-15')), findsOneWidget);
    expect(find.text('× 1'), findsNothing);
    expect(find.text('RAZEM'), findsOneWidget);

    await tester.tap(find.byKey(plateSheetApplyKey));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(PlateCalculatorSheet), findsNothing);
    expect(repository.session.exercises.first.sets.first.actualWeight, '100');
    expect(
      PlateSettingsStore.current.barbellExercises,
      contains('name:bench press'),
    );

    await cubit.close();
  });

  testWidgets('weight that cannot be loaded offers the nearest options', (
    tester,
  ) async {
    final (repository, cubit) = await pumpWorkout(tester, plannedWeight: '101');

    await openFromTile(tester);

    expect(find.text('Z Twoich talerzy nie złożysz 101 kg'), findsOneWidget);
    expect(find.text('RAZEM'), findsNothing);

    await tester.tap(find.byKey(plateSheetUpperKey));
    await tester.pumpAndSettle();

    expect(find.text('RAZEM'), findsOneWidget);
    expect(find.text('Wpisz 102,5 kg do serii 1'), findsOneWidget);

    await tester.tap(find.byKey(plateSheetApplyKey));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));

    expect(repository.session.exercises.first.sets.first.actualWeight, '102.5');

    await cubit.close();
  });

  testWidgets('rest panel shows the plates after the calculator was used', (
    tester,
  ) async {
    final (_, cubit) = await pumpWorkout(tester, plannedWeight: '100', sets: 2);

    // Bez użycia kalkulatora ćwiczenie nie jest „ze sztangą”.
    await tester.tap(find.byKey(const ValueKey('session-set-check-0-0')));
    await tester.pump();
    expect(find.byKey(restPlateStripKey), findsNothing);
    await tester.tap(find.byKey(const Key('rest-timer-skip')));
    await tester.pump();

    await openFromTile(tester);
    await tester.tap(find.byKey(plateSheetApplyKey));
    await tester.pumpAndSettle();

    expect(find.byKey(restPlateStripKey), findsOneWidget);
    expect(find.text('25 + 15'), findsOneWidget);

    // Wyłączony pasek znika.
    await PlateSettingsStore.save(
      PlateSettingsStore.current.copyWith(showInRest: false),
    );
    await tester.pump();
    expect(find.byKey(restPlateStripKey), findsNothing);

    await tester.tap(find.byKey(const Key('rest-timer-skip')));
    await tester.pump(const Duration(seconds: 1));
    await cubit.close();
  });

  testWidgets('equipment changes update the open calculator', (tester) async {
    final (_, cubit) = await pumpWorkout(tester, plannedWeight: '100');

    await openFromTile(tester);
    await tester.tap(find.byKey(plateSheetSettingsKey));
    await tester.pumpAndSettle();

    expect(find.byType(PlateEquipmentScreen), findsOneWidget);

    // Bez 25 kg: 100 kg = 20 + 20 na stronę.
    await tester.tap(find.byKey(plateEquipmentPlateKey(25)));
    await tester.pump();
    expect(PlateSettingsStore.current.kg.enabledPlates, isNot(contains(25)));

    await tester.tap(find.byKey(plateEquipmentBarKey('none')));
    await tester.pump();
    expect(PlateSettingsStore.current.kg.barWeight, 0);

    await tester.tap(find.byKey(plateEquipmentBarKey('20')));
    await tester.pump();

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('plate-legend-20')),
        matching: find.text('× 2'),
      ),
      findsOneWidget,
    );

    await cubit.close();
  });

  testWidgets('calculator is a tile in the ⋯ menu', (tester) async {
    final (_, cubit) = await pumpWorkout(tester, plannedWeight: '60');

    await tester.tap(find.byKey(const Key('workout-more-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('options-plates')));
    await tester.pumpAndSettle();

    expect(find.byType(PlateCalculatorSheet), findsOneWidget);
    expect(find.text('Wpisz 60 kg do serii 1'), findsOneWidget);

    await cubit.close();
  });
}

TrainingSession _session(String plannedWeight, {int sets = 1}) {
  return TrainingSession(
    planName: 'Push',
    startedAt: DateTime.now().toUtc(),
    exercises: [
      TrainingSessionExercise(
        exerciseId: 'bench',
        exerciseName: 'Bench press',
        exerciseMuscles: const ['chest'],
        exerciseCategory: 'compound',
        sets: [
          for (var i = 0; i < sets; i++)
            TrainingSessionSet(plannedWeight: plannedWeight, plannedReps: '5'),
        ],
      ),
    ],
  );
}

class _FakeRepository implements TrainingSessionRepository {
  _FakeRepository(this.session);

  TrainingSession session;

  @override
  Future<TrainingSession?> getActive() async => session;

  @override
  Future<TrainingSession?> getById(String sessionId) async => session;

  @override
  Future<TrainingSession> startFromPlan(CustomTrainingPlan plan) async =>
      session;

  @override
  Future<TrainingSession> startCustom({
    String planName = TrainingSession.defaultCustomName,
  }) async => session;

  @override
  Future<TrainingSession> save(TrainingSession session) async {
    this.session = session;
    return session;
  }

  @override
  Future<TrainingSession> finish(String sessionId) async => session;

  @override
  Future<TrainingSession> cancel(String sessionId) async => session;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRestTimerScheduler implements RestTimerScheduler {
  @override
  Future<void> scheduleRestFinished({required Duration duration}) async {}

  @override
  Future<void> cancelRestFinished() async {}

  @override
  Future<void> warmUp() async {}
}
