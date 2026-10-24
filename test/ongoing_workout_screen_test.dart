import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:gym/features/training/domain/models/custom_training_plan.dart';
import 'package:gym/features/training/domain/models/post_draft.dart';
import 'package:gym/features/training/domain/models/training_session.dart';
import 'package:gym/features/training/domain/repositories/previous_performance_repository.dart';
import 'package:gym/features/training/domain/repositories/training_stats_repository.dart';
import 'package:gym/features/training/domain/repositories/training_session_repository.dart';
import 'package:gym/features/training/domain/services/rest_timer_scheduler.dart';
import 'package:gym/features/training/presentation/bloc/training_session_cubit.dart';
import 'package:gym/features/training/presentation/screens/ongoing_workout_screen.dart';
import 'package:gym/features/training/presentation/screens/workout_summary_screen.dart';
import 'package:gym/features/training/presentation/widgets/ongoing_workout/rest_timer_pill.dart';
import 'package:gym/features/training/presentation/widgets/ongoing_workout/set_check_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows one exercise at a time with quick exercise navigation', (
    tester,
  ) async {
    final session = _session();
    final cubit = TrainingSessionCubit(
      _FakeTrainingSessionRepository(session),
      autoRefresh: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: OngoingWorkoutScreen(
          args: OngoingWorkoutArgs(
            initialSession: session,
            sessionCubit: cubit,
          ),
        ),
      ),
    );

    expect(find.text('Bench press'), findsOneWidget);
    expect(find.text('Ćwiczenie 1 z 2'), findsOneWidget);
    // Karta „Następne” zapowiada kolejne ćwiczenie.
    expect(
      find.descendant(
        of: find.byKey(const Key('next-exercise-card')),
        matching: find.text('Shoulder press'),
      ),
      findsOneWidget,
    );
    expect(find.text('1 × 10'), findsOneWidget);

    await tester.drag(find.text('Bench press'), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(find.text('Bench press'), findsNothing);
    expect(find.text('Shoulder press'), findsOneWidget);
    expect(find.text('Ćwiczenie 2 z 2'), findsOneWidget);
    expect(find.byKey(const Key('next-exercise-card')), findsNothing);

    // Segment paska postępu przenosi do swojego ćwiczenia.
    await tester.tap(find.byKey(const ValueKey('progress-segment-0')));
    await tester.pumpAndSettle();

    expect(find.text('Ćwiczenie 1 z 2'), findsOneWidget);

    await tester.tap(find.byKey(const Key('next-exercise-card')));
    await tester.pumpAndSettle();

    expect(find.text('Ćwiczenie 2 z 2'), findsOneWidget);

    await tester.tap(find.byKey(const Key('exercise-list-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Bench press'));
    await tester.pumpAndSettle();

    expect(find.text('Ćwiczenie 1 z 2'), findsOneWidget);
    expect(find.text('Bench press'), findsOneWidget);

    await cubit.close();
  });

  testWidgets('adds a set and removes it with a swipe to the left', (
    tester,
  ) async {
    final repository = _FakeTrainingSessionRepository(_session());
    final cubit = TrainingSessionCubit(repository, autoRefresh: false);

    await tester.pumpWidget(
      MaterialApp(
        home: OngoingWorkoutScreen(
          args: OngoingWorkoutArgs(
            initialSession: repository.session,
            sessionCubit: cubit,
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('session-set-type-0-1')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('add-session-set-button')));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byKey(const ValueKey('session-set-type-0-1')), findsOneWidget);
    expect(repository.session.exercises.first.sets, hasLength(2));

    await tester.drag(
      find.byKey(const ValueKey('session-set-type-0-1')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byKey(const ValueKey('session-set-type-0-1')), findsNothing);
    expect(repository.session.exercises.first.sets, hasLength(1));
    // Ostatniej serii nie da się usunąć — wiersz się nie przesuwa.
    await tester.drag(
      find.byKey(const ValueKey('session-set-type-0-0')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();
    expect(repository.session.exercises.first.sets, hasLength(1));

    await cubit.close();
  });

  testWidgets('checking a set counts working sets only and turns it green', (
    tester,
  ) async {
    final session = _session(
      firstSet: TrainingSessionSet(
        setType: SetType.warmup,
        actualWeight: '40',
        actualReps: '10',
      ),
    );
    final repository = _FakeTrainingSessionRepository(
      session.copyWith(
        exercises: [
          session.exercises.first.copyWith(
            sets: [
              ...session.exercises.first.sets,
              TrainingSessionSet(plannedReps: '8', actualWeight: '60'),
            ],
          ),
          session.exercises.last,
        ],
      ),
    );
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

    expect(find.byKey(const Key('workout-sets-counter')), findsOneWidget);
    expect(find.text('0 z 2 serii'), findsOneWidget);

    // Rozgrzewka nie liczy się do postępu.
    await tester.tap(find.byKey(const ValueKey('session-set-check-0-0')));
    await tester.pump();
    expect(find.text('0 z 2 serii'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('session-set-check-0-1')));
    await tester.pump();
    expect(find.text('1 z 2 serii'), findsOneWidget);
    expect(
      tester
          .widget<SetCheckButton>(
            find.byKey(const ValueKey('session-set-check-0-1')),
          )
          .completed,
      isTrue,
    );

    await tester.pump(const Duration(seconds: 1));
    final sets = repository.session.exercises.first.sets;
    expect(sets.every((set) => set.completed), isTrue);
    expect(sets.last.completedAt, isNotNull);

    await cubit.close();
  });

  testWidgets('rir and tempo columns are toggled from the ⋯ menu', (
    tester,
  ) async {
    final repository = _FakeTrainingSessionRepository(_session());
    final cubit = TrainingSessionCubit(repository, autoRefresh: false);

    await tester.pumpWidget(
      MaterialApp(
        home: OngoingWorkoutScreen(
          args: OngoingWorkoutArgs(
            initialSession: repository.session,
            sessionCubit: cubit,
          ),
        ),
      ),
    );

    expect(find.text('RIR'), findsNothing);
    expect(find.text('TEMPO'), findsNothing);

    await _chooseFromMenu(tester, 'Pokaż kolumnę RIR');

    expect(find.text('RIR'), findsOneWidget);
    expect(find.text('TEMPO'), findsNothing);

    await _chooseFromMenu(tester, 'Pokaż kolumnę tempo');

    expect(find.text('RIR'), findsOneWidget);
    expect(find.text('TEMPO'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('session-set-tempo-0-0')),
      '2-0-2',
    );
    await tester.pump(const Duration(seconds: 1));

    expect(repository.session.exercises.first.sets.first.actualTempo, '2-0-2');

    await _chooseFromMenu(tester, 'Ukryj kolumnę RIR');

    expect(find.text('RIR'), findsNothing);
    expect(find.text('TEMPO'), findsOneWidget);

    await _chooseFromMenu(tester, 'Ukryj kolumnę tempo');

    expect(find.text('RIR'), findsNothing);
    expect(find.text('TEMPO'), findsNothing);
    expect(repository.session.exercises.first.sets.first.actualTempo, '2-0-2');

    await cubit.close();
  });

  testWidgets('shows optional rir and tempo columns when plan includes them', (
    tester,
  ) async {
    final session = _session(
      firstSet: TrainingSessionSet(
        plannedWeight: '60',
        plannedReps: '8',
        plannedRir: '2',
        plannedTempo: '3-1-1',
        actualTempo: '3-1-1',
      ),
    );
    final cubit = TrainingSessionCubit(
      _FakeTrainingSessionRepository(session),
      autoRefresh: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: OngoingWorkoutScreen(
          args: OngoingWorkoutArgs(
            initialSession: session,
            sessionCubit: cubit,
          ),
        ),
      ),
    );

    expect(find.text('RIR'), findsOneWidget);
    expect(find.text('TEMPO'), findsOneWidget);
    expect(find.byKey(const ValueKey('session-set-tempo-0-0')), findsOneWidget);

    await cubit.close();
  });

  testWidgets('adds a picked exercise to the active workout session', (
    tester,
  ) async {
    final repository = _FakeTrainingSessionRepository(_session());
    final cubit = TrainingSessionCubit(repository, autoRefresh: false);

    await tester.pumpWidget(
      MaterialApp(
        home: OngoingWorkoutScreen(
          args: OngoingWorkoutArgs(
            initialSession: repository.session,
            sessionCubit: cubit,
            pickExercise: (_) async => const Exercise(
              id: 'row',
              name: 'Barbell row',
              muscles: [MuscleGroup.back],
              category: ExerciseCategory.compound,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('add-exercise-button-0')));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(repository.session.exercises, hasLength(3));
    expect(repository.session.exercises.last.exerciseName, 'Barbell row');
    expect(repository.session.exercises.last.sets, hasLength(1));
    expect(find.text('Ćwiczenie 3 z 3'), findsOneWidget);
    expect(find.text('Barbell row'), findsOneWidget);

    await tester.tap(find.byKey(const Key('exercise-list-button')));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ListTile, 'Barbell row'), findsOneWidget);

    await cubit.close();
  });

  testWidgets('rest starts by itself after a set is checked', (tester) async {
    final session = _session();
    final scheduler = _FakeRestTimerScheduler();
    final cubit = TrainingSessionCubit(
      _FakeTrainingSessionRepository(session),
      autoRefresh: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: OngoingWorkoutScreen(
          args: OngoingWorkoutArgs(
            initialSession: session,
            sessionCubit: cubit,
            restTimerScheduler: scheduler,
            restTimerClock: () => tester.binding.clock.now(),
          ),
        ),
      ),
    );

    expect(_restDock(tester).visible, isFalse);

    await tester.tap(find.byKey(const ValueKey('session-set-check-0-0')));
    await tester.pump();

    expect(_restDock(tester).visible, isTrue);
    expect(scheduler.scheduledDurations, [const Duration(seconds: 90)]);
    expect(_restLabel('1:30'), findsOneWidget);
    // Następna jest seria drugiego ćwiczenia.
    expect(find.text('Teraz: Shoulder press'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(_restLabel('1:29'), findsOneWidget);

    await tester.tap(find.byKey(const Key('rest-timer-extend')));
    await tester.pump();

    expect(_restLabel('1:44'), findsOneWidget);
    expect(scheduler.scheduledDurations, [
      const Duration(seconds: 90),
      const Duration(seconds: 104),
    ]);

    await tester.tap(find.byKey(const Key('rest-timer-skip')));
    await tester.pump();

    expect(scheduler.cancelCount, 1);
    expect(_restDock(tester).visible, isFalse);

    await cubit.close();
  });

  testWidgets('a superset goes A1 → A2 without rest, then the plan rest', (
    tester,
  ) async {
    TrainingSessionExercise member(String id, String name, int rest) =>
        TrainingSessionExercise(
          exerciseId: id,
          exerciseName: name,
          exerciseMuscles: const ['shoulders'],
          exerciseCategory: 'compound',
          supersetGroup: 'A',
          restSeconds: rest,
          sets: [
            TrainingSessionSet(plannedWeight: '24', plannedReps: '10'),
            TrainingSessionSet(plannedWeight: '24', plannedReps: '10'),
          ],
        );
    final session = TrainingSession(
      planName: 'Góra A',
      startedAt: DateTime.now().toUtc(),
      exercises: [
        member('press', 'Wyciskanie hantli', 999),
        member('raise', 'Wznosy bokiem', 75),
      ],
    );
    final scheduler = _FakeRestTimerScheduler();
    final cubit = TrainingSessionCubit(
      _FakeTrainingSessionRepository(session),
      autoRefresh: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: OngoingWorkoutScreen(
          args: OngoingWorkoutArgs(
            initialSession: session,
            sessionCubit: cubit,
            restTimerScheduler: scheduler,
            restTimerClock: () => tester.binding.clock.now(),
          ),
        ),
      ),
    );

    // Obie części superserii na jednej stronie.
    expect(find.text('SUPERSERIA A'), findsOneWidget);
    expect(find.text('Wznosy bokiem'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('session-set-check-0-0')));
    await tester.pump();

    expect(find.byKey(const Key('superset-next-pill')), findsOneWidget);
    expect(find.textContaining('Teraz: A2 · Wznosy bokiem'), findsOneWidget);
    expect(scheduler.scheduledDurations, isEmpty);

    await tester.ensureVisible(
      find.byKey(const ValueKey('session-set-check-1-0')),
    );
    await tester.tap(find.byKey(const ValueKey('session-set-check-1-0')));
    await tester.pump();

    expect(find.byKey(const Key('superset-next-pill')), findsNothing);
    expect(find.text('Przerwa po rundzie 1'), findsOneWidget);
    expect(scheduler.scheduledDurations, [const Duration(seconds: 75)]);

    await cubit.close();
  });

  testWidgets('rest uses the exercise rest from the plan', (tester) async {
    final base = _session();
    final session = base.copyWith(
      exercises: [
        base.exercises[0].copyWith(restSeconds: 45),
        base.exercises[1],
      ],
    );
    final scheduler = _FakeRestTimerScheduler();
    final cubit = TrainingSessionCubit(
      _FakeTrainingSessionRepository(session),
      autoRefresh: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: OngoingWorkoutScreen(
          args: OngoingWorkoutArgs(
            initialSession: session,
            sessionCubit: cubit,
            restTimerScheduler: scheduler,
            restTimerClock: () => tester.binding.clock.now(),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('session-set-check-0-0')));
    await tester.pump();

    expect(scheduler.scheduledDurations, [const Duration(seconds: 45)]);
    expect(_restLabel('0:45'), findsOneWidget);

    await tester.tap(find.byKey(const Key('rest-timer-skip')));
    await tester.pump();
    await cubit.close();
  });

  testWidgets('picks the rest length by hand from the ⋯ menu', (tester) async {
    final session = _session();
    final scheduler = _FakeRestTimerScheduler();
    final cubit = TrainingSessionCubit(
      _FakeTrainingSessionRepository(session),
      autoRefresh: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: OngoingWorkoutScreen(
          args: OngoingWorkoutArgs(
            initialSession: session,
            sessionCubit: cubit,
            restTimerScheduler: scheduler,
            restTimerClock: () => tester.binding.clock.now(),
          ),
        ),
      ),
    );

    await _chooseFromMenu(tester, 'Odpoczynek');

    expect(find.text('30s'), findsNothing);
    expect(find.text('1:30'), findsOneWidget);
    expect(find.text('2:00'), findsOneWidget);
    expect(find.text('3:00'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('rest-duration-option-60')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(scheduler.scheduledDurations, [const Duration(seconds: 60)]);
    expect(_restLabel('1:00'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(_restLabel('0:59'), findsOneWidget);

    await _chooseFromMenu(tester, 'Zatrzymaj odpoczynek');

    expect(scheduler.cancelCount, 1);
    expect(_restDock(tester).visible, isFalse);

    // Wybrana długość obowiązuje też dla przerwy po odhaczeniu serii.
    await tester.tap(find.byKey(const ValueKey('session-set-check-0-0')));
    await tester.pump();
    expect(scheduler.scheduledDurations.last, const Duration(seconds: 60));

    await cubit.close();
  });

  testWidgets('starts the rest timer with the custom digital picker', (
    tester,
  ) async {
    final session = _session();
    final scheduler = _FakeRestTimerScheduler();
    final cubit = TrainingSessionCubit(
      _FakeTrainingSessionRepository(session),
      autoRefresh: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: OngoingWorkoutScreen(
          args: OngoingWorkoutArgs(
            initialSession: session,
            sessionCubit: cubit,
            restTimerScheduler: scheduler,
            restTimerClock: () => tester.binding.clock.now(),
          ),
        ),
      ),
    );

    await _chooseFromMenu(tester, 'Odpoczynek');

    await tester.tap(find.byKey(const ValueKey('rest-duration-custom-option')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('custom-rest-time-display')),
        matching: find.text('01:30'),
      ),
      findsOneWidget,
    );

    await tester.drag(
      find.byKey(const ValueKey('custom-rest-minutes-dial')),
      const Offset(0, -80),
    );
    await tester.pump();
    await tester.drag(
      find.byKey(const ValueKey('custom-rest-seconds-dial')),
      const Offset(0, 80),
    );
    await tester.pump();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('custom-rest-time-display')),
        matching: find.text('02:29'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('custom-rest-start-button')));
    await tester.pumpAndSettle();

    expect(scheduler.scheduledDurations, [const Duration(seconds: 149)]);
    expect(_restLabel('2:29'), findsOneWidget);

    await tester.tap(find.byKey(const Key('rest-timer-skip')));
    await tester.pump();

    // Dotknięcie panelu też otwiera wybór — tu panel jest schowany, więc
    // przez menu.
    await _chooseFromMenu(tester, 'Odpoczynek');

    expect(find.text('Ostatni własny'), findsOneWidget);
    expect(find.text('2:29'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('rest-duration-last-custom')));
    await tester.pumpAndSettle();

    expect(scheduler.scheduledDurations, [
      const Duration(seconds: 149),
      const Duration(seconds: 149),
    ]);

    await cubit.close();
  });

  testWidgets('empty session shows encouragement before first exercise', (
    tester,
  ) async {
    final session = TrainingSession.custom();
    final repository = _FakeTrainingSessionRepository(session);
    final cubit = TrainingSessionCubit(repository, autoRefresh: false);

    await tester.pumpWidget(
      MaterialApp(
        home: OngoingWorkoutScreen(
          args: OngoingWorkoutArgs(
            initialSession: session,
            sessionCubit: cubit,
          ),
        ),
      ),
    );

    expect(find.text('Dodaj pierwsze ćwiczenie'), findsOneWidget);
    expect(find.byKey(const Key('workout-sets-counter')), findsNothing);

    await cubit.close();
  });

  testWidgets('add from empty session shows first exercise carousel', (
    tester,
  ) async {
    final session = TrainingSession.custom();
    final repository = _FakeTrainingSessionRepository(session);
    final cubit = TrainingSessionCubit(repository, autoRefresh: false);

    await tester.pumpWidget(
      MaterialApp(
        home: OngoingWorkoutScreen(
          args: OngoingWorkoutArgs(
            initialSession: session,
            sessionCubit: cubit,
            pickExercise: (ctx) async => Exercise(
              id: 'row1',
              name: 'Cable row',
              muscles: const [MuscleGroup.back],
              category: ExerciseCategory.compound,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('add-first-exercise-button')));
    await tester.pumpAndSettle();

    expect(find.text('Cable row'), findsOneWidget);
    expect(find.text('Ćwiczenie 1 z 1'), findsOneWidget);
    expect(repository.session.exercises, hasLength(1));

    await cubit.close();
  });

  testWidgets('hides the rest panel while the keyboard is open', (
    tester,
  ) async {
    final session = _session();
    final cubit = TrainingSessionCubit(
      _FakeTrainingSessionRepository(session),
      autoRefresh: false,
    );

    Widget buildApp({required double keyboardBottom}) {
      return MaterialApp(
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(viewInsets: EdgeInsets.only(bottom: keyboardBottom)),
            child: child!,
          );
        },
        home: OngoingWorkoutScreen(
          args: OngoingWorkoutArgs(
            initialSession: session,
            sessionCubit: cubit,
            restTimerScheduler: _FakeRestTimerScheduler(),
          ),
        ),
      );
    }

    await tester.pumpWidget(buildApp(keyboardBottom: 0));
    await tester.tap(find.byKey(const ValueKey('session-set-check-0-0')));
    await tester.pump();

    expect(_restDock(tester).visible, isTrue);

    await tester.pumpWidget(buildApp(keyboardBottom: 320));
    await tester.pump();

    expect(_restDock(tester).visible, isFalse);

    await tester.pumpWidget(buildApp(keyboardBottom: 0));
    await tester.pump();

    expect(_restDock(tester).visible, isTrue);

    await cubit.close();
  });

  testWidgets('a checked set that beats the record shows a gold burst', (
    tester,
  ) async {
    final session = _session(
      firstSet: TrainingSessionSet(
        plannedReps: '8',
        actualWeight: '62,5',
        actualReps: '8',
      ),
    );
    final cubit = TrainingSessionCubit(
      _FakeTrainingSessionRepository(session),
      autoRefresh: false,
    );
    final history = TrainingSession(
      planName: 'Push',
      status: TrainingSessionStatus.completed,
      startedAt: DateTime.utc(2026, 9, 1),
      finishedAt: DateTime.utc(2026, 9, 1, 1),
      exercises: [
        TrainingSessionExercise(
          exerciseId: 'bench',
          exerciseName: 'Bench press',
          exerciseMuscles: const ['chest'],
          exerciseCategory: 'compound',
          sets: [
            TrainingSessionSet(
              actualWeight: '60',
              actualReps: '8',
              completed: true,
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: OngoingWorkoutScreen(
          args: OngoingWorkoutArgs(
            initialSession: session,
            sessionCubit: cubit,
            restTimerScheduler: _FakeRestTimerScheduler(),
            statsRepository: _FakeStatsRepository([history]),
            previousPerformance: _FakePreviousPerformance({
              'bench': history.exercises.first.sets,
            }),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.descendant(
        of: find.byKey(const Key('exercise-record-chip')),
        matching: find.text('Rekord 60 × 8'),
      ),
      findsOneWidget,
    );
    expect(find.text('Ostatnio 60 × 8'), findsOneWidget);
    // Podpowiedź progresji nad polem ciężaru: poprzednio 60 × 8 przy planie 8.
    expect(find.byKey(const Key('progression-hint-tag')), findsOneWidget);
    expect(find.text('+2,5'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('session-set-check-0-0')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Nowy rekord!'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('session-set-record-0-0')),
      findsOneWidget,
    );
    expect(find.textContaining('+2,5 kg'), findsOneWidget);

    // Karta sama znika; znaczek na serii zostaje.
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Nowy rekord!'), findsNothing);
    expect(
      find.byKey(const ValueKey('session-set-record-0-0')),
      findsOneWidget,
    );

    await cubit.close();
  });

  testWidgets('the progression hint is a placeholder, not a typed value', (
    tester,
  ) async {
    final session = _session(firstSet: TrainingSessionSet(plannedReps: '6-8'));
    final repository = _FakeTrainingSessionRepository(session);
    final cubit = TrainingSessionCubit(repository, autoRefresh: false);

    await tester.pumpWidget(
      MaterialApp(
        home: OngoingWorkoutScreen(
          args: OngoingWorkoutArgs(
            initialSession: session,
            sessionCubit: cubit,
            previousPerformance: _FakePreviousPerformance({
              'bench': [
                TrainingSessionSet(
                  actualWeight: '92.5',
                  actualReps: '8',
                  completed: true,
                ),
              ],
            }),
          ),
        ),
      ),
    );
    await tester.pump();

    final weightField = find.descendant(
      of: find.byKey(const ValueKey('session-set-weight-0-0')),
      matching: find.byType(TextField),
    );
    final field = tester.widget<TextField>(weightField);
    expect(field.decoration?.hintText, '95');
    expect(field.controller?.text, isEmpty);
    expect(find.text('+2,5'), findsOneWidget);
    // Poprzedni wynik z przecinkiem dziesiętnym.
    expect(find.text('92,5 × 8'), findsOneWidget);
    expect(repository.session.exercises.first.sets.first.actualWeight, isNull);

    await cubit.close();
  });

  testWidgets('finish asks for confirmation before completing session', (
    tester,
  ) async {
    final repository = _FakeTrainingSessionRepository(_session());
    final cubit = TrainingSessionCubit(repository, autoRefresh: false);

    await tester.pumpWidget(
      MaterialApp(
        home: OngoingWorkoutScreen(
          args: OngoingWorkoutArgs(
            initialSession: repository.session,
            sessionCubit: cubit,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('finish-workout-button')));
    await tester.pumpAndSettle();

    expect(find.text('Zakończyć trening?'), findsOneWidget);
    expect(
      find.text(
        'Czy na pewno chcesz zakończyć ten trening? Sesja zostanie zapisana w historii.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Anuluj'));
    await tester.pumpAndSettle();

    expect(repository.session.status, TrainingSessionStatus.active);
    expect(find.text('Zakończyć trening?'), findsNothing);

    await cubit.close();
  });

  testWidgets('finish opens the workout summary instead of leaving', (
    tester,
  ) async {
    final repository = _FakeTrainingSessionRepository(_session());
    final cubit = TrainingSessionCubit(repository, autoRefresh: false);

    await tester.pumpWidget(
      MaterialApp(
        home: OngoingWorkoutScreen(
          args: OngoingWorkoutArgs(
            initialSession: repository.session,
            sessionCubit: cubit,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('finish-workout-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Zakończ'));
    await tester.pumpAndSettle();

    expect(repository.session.status, TrainingSessionStatus.completed);
    expect(cubit.state.activeSession, isNull);
    expect(find.byType(WorkoutSummaryScreen), findsOneWidget);
    expect(find.text('Trening ukończony!'), findsOneWidget);
    expect(find.byType(OngoingWorkoutScreen), findsNothing);

    await cubit.close();
  });

  testWidgets('edit made while a draft save is in flight is still saved', (
    tester,
  ) async {
    final repository = _GatedTrainingSessionRepository(_session());
    final cubit = TrainingSessionCubit(repository, autoRefresh: false);

    await tester.pumpWidget(
      MaterialApp(
        home: OngoingWorkoutScreen(
          args: OngoingWorkoutArgs(
            initialSession: repository.session,
            sessionCubit: cubit,
          ),
        ),
      ),
    );

    // Pierwsza zmiana — debounce startuje zapis, który jeszcze trwa.
    repository.gate = Completer<void>();
    await tester.enterText(find.byType(TextField).at(0), '100');
    await tester.pump(const Duration(milliseconds: 950));
    expect(repository.saveCalls, 1);

    // Druga zmiana w trakcie tego zapisu.
    await tester.enterText(find.byType(TextField).at(1), '5');
    await tester.pump();

    repository.gate!.complete();
    repository.gate = null;
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final set = repository.session.exercises.first.sets.first;
    expect(set.actualWeight, '100');
    expect(set.actualReps, '5');

    await cubit.close();
  });
}

class _GatedTrainingSessionRepository extends _FakeTrainingSessionRepository {
  _GatedTrainingSessionRepository(super.session);

  Completer<void>? gate;
  int saveCalls = 0;

  @override
  Future<TrainingSession> save(TrainingSession session) async {
    saveCalls++;
    final pending = gate;
    if (pending != null) await pending.future;
    return super.save(session);
  }
}

TrainingSession _session({TrainingSessionSet? firstSet}) {
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
          firstSet ?? TrainingSessionSet(plannedWeight: '60', plannedReps: '8'),
        ],
      ),
      TrainingSessionExercise(
        exerciseId: 'press',
        exerciseName: 'Shoulder press',
        exerciseMuscles: const ['shoulders'],
        exerciseCategory: 'compound',
        sets: [TrainingSessionSet(plannedWeight: '35', plannedReps: '10')],
      ),
    ],
  );
}

class _FakeTrainingSessionRepository implements TrainingSessionRepository {
  _FakeTrainingSessionRepository(this.session);

  TrainingSession session;

  @override
  Future<TrainingSession?> getActive() async => session;

  @override
  Future<TrainingSession?> getById(String sessionId) async =>
      session.id == sessionId ? session : null;

  @override
  Future<TrainingSession> startFromPlan(CustomTrainingPlan plan) async =>
      session;

  @override
  Future<TrainingSession> startCustom({
    String planName = TrainingSession.defaultCustomName,
  }) async {
    session = TrainingSession.custom(planName: planName);
    return session;
  }

  @override
  Future<TrainingSession> save(TrainingSession session) async {
    this.session = session;
    return session;
  }

  @override
  Future<TrainingSession> finish(String sessionId) async {
    session = session.copyWith(
      status: TrainingSessionStatus.completed,
      finishedAt: DateTime.now().toUtc(),
    );
    return session;
  }

  @override
  Future<TrainingSession> cancel(String sessionId) async =>
      session.copyWith(status: TrainingSessionStatus.cancelled);

  @override
  Future<TrainingSession> setSharedToProfile(
    String sessionId,
    bool shared,
  ) async {
    session = session.copyWith(sharedToProfile: shared);
    return session;
  }

  @override
  Future<TrainingSession> startFromSession(TrainingSession source) {
    throw UnimplementedError();
  }

  @override
  Future<TrainingSession?> loadForEdit(String sessionId) async => null;

  @override
  Future<void> delete(String sessionId) async {}

  @override
  Future<TrainingSession> sharePost(String sessionId, PostDraft draft) {
    throw UnimplementedError();
  }

  @override
  Future<PostPhotoChange> pendingPostPhoto(String sessionId) async =>
      const KeepPostPhoto();
}

class _FakeRestTimerScheduler implements RestTimerScheduler {
  final List<Duration> scheduledDurations = [];
  int cancelCount = 0;

  @override
  Future<void> scheduleRestFinished({required Duration duration}) async {
    scheduledDurations.add(duration);
  }

  @override
  Future<void> cancelRestFinished() async {
    cancelCount += 1;
  }

  @override
  Future<void> warmUp() async {}
}

class _FakePreviousPerformance implements PreviousPerformanceRepository {
  _FakePreviousPerformance(this.byExerciseId);

  final Map<String, List<TrainingSessionSet>> byExerciseId;

  @override
  Future<List<TrainingSessionSet>?> lastCompletedSets({
    required String exerciseId,
    required String exerciseName,
  }) async => byExerciseId[exerciseId];
}

class _FakeStatsRepository implements TrainingStatsRepository {
  _FakeStatsRepository(this.sessions);

  final List<TrainingSession> sessions;

  @override
  Future<List<TrainingSession>> allCompletedSessions() async => sessions;

  @override
  Future<List<TrainingSession>> completedSessionsSince(DateTime from) async =>
      sessions;
}

RestTimerDock _restDock(WidgetTester tester) =>
    tester.widget<RestTimerDock>(find.byType(RestTimerDock));

Finder _restLabel(String text) => find.byWidgetPredicate(
  (widget) =>
      widget is Text &&
      widget.key == const ValueKey('rest-timer-remaining-label') &&
      widget.data == text,
);

Future<void> _chooseFromMenu(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const Key('workout-more-button')));
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(of: find.byType(BottomSheet), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}
