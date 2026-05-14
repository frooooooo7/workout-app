import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:gym/features/training/domain/models/custom_training_plan.dart';
import 'package:gym/features/training/domain/models/training_session.dart';
import 'package:gym/features/training/domain/repositories/training_session_repository.dart';
import 'package:gym/features/training/domain/services/rest_timer_scheduler.dart';
import 'package:gym/features/training/presentation/bloc/training_session_cubit.dart';
import 'package:gym/features/training/presentation/screens/ongoing_workout_screen.dart';
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

    expect(find.text('Bench press'), findsWidgets);
    expect(find.text('Shoulder press'), findsNothing);
    expect(find.text('1 / 2'), findsOneWidget);

    await tester.drag(find.text('Bench press').last, const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(find.text('Bench press'), findsNothing);
    expect(find.text('Shoulder press'), findsWidgets);
    expect(find.text('2 / 2'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Bench press'), findsWidgets);
    expect(find.text('Shoulder press'), findsNothing);
    expect(find.text('1 / 2'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Bench press'), findsNothing);
    expect(find.text('Shoulder press'), findsWidgets);
    expect(find.text('2 / 2'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.format_list_bulleted_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bench press').last);
    await tester.pumpAndSettle();

    expect(find.text('Bench press'), findsWidgets);
    expect(find.text('Shoulder press'), findsNothing);

    await cubit.close();
  });

  testWidgets('adds and removes sets in the current exercise', (tester) async {
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

    expect(find.text('2'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('add-session-set-button')));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('2'), findsOneWidget);
    expect(repository.session.exercises.first.sets, hasLength(2));

    await tester.tap(find.byIcon(Icons.delete_outline_rounded).last);
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('2'), findsNothing);
    expect(repository.session.exercises.first.sets, hasLength(1));

    await cubit.close();
  });

  testWidgets('hides optional rir and tempo columns until user enables them', (
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

    await tester.tap(find.byKey(const ValueKey('show-rir-column-button-0')));
    await tester.pumpAndSettle();

    expect(find.text('RIR'), findsOneWidget);
    expect(find.text('TEMPO'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('show-tempo-column-button-0')));
    await tester.pumpAndSettle();

    expect(find.text('RIR'), findsOneWidget);
    expect(find.text('TEMPO'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('session-set-tempo-0-0')),
      '2-0-2',
    );
    await tester.pump(const Duration(seconds: 1));

    expect(repository.session.exercises.first.sets.first.actualTempo, '2-0-2');

    await tester.tap(find.byKey(const ValueKey('hide-rir-column-button-0')));
    await tester.pumpAndSettle();

    expect(find.text('RIR'), findsNothing);
    expect(find.text('TEMPO'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('hide-tempo-column-button-0')));
    await tester.pumpAndSettle();

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

    await tester.tap(find.text('Dodaj ćwiczenie'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(repository.session.exercises, hasLength(3));
    expect(repository.session.exercises.last.exerciseName, 'Barbell row');
    expect(repository.session.exercises.last.sets, hasLength(1));
    expect(find.text('3 / 3'), findsOneWidget);
    expect(find.text('Barbell row'), findsWidgets);

    await tester.tap(find.byIcon(Icons.format_list_bulleted_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Barbell row'), findsWidgets);

    await cubit.close();
  });

  testWidgets('starts and stops the rest timer from the workout footer', (
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
          ),
        ),
      ),
    );

    await tester.tap(find.text('Odpoczynek'));
    await tester.pumpAndSettle();

    expect(find.text('30s'), findsNothing);
    expect(find.text('1:30'), findsOneWidget);
    expect(find.text('2:00'), findsOneWidget);
    expect(find.text('3:00'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('rest-duration-option-60')));
    await tester.pump();

    expect(scheduler.scheduledDurations, [const Duration(seconds: 60)]);
    expect(find.text('01:00'), findsOneWidget);
    expect(find.text('Zatrzymaj'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('00:59'), findsOneWidget);

    await tester.tap(find.text('Zatrzymaj'));
    await tester.pump();

    expect(scheduler.cancelCount, 1);
    expect(find.text('Odpoczynek'), findsOneWidget);
    expect(find.text('00:59'), findsNothing);

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
          ),
        ),
      ),
    );

    await tester.tap(find.text('Odpoczynek'));
    await tester.pumpAndSettle();

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
    await tester.pump();

    expect(scheduler.scheduledDurations, [const Duration(seconds: 149)]);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.key == const ValueKey('rest-timer-remaining-label') &&
            widget.data == '02:29',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Zatrzymaj'));
    await tester.pump();

    await tester.tap(find.text('Odpoczynek'));
    await tester.pumpAndSettle();

    expect(find.text('Ostatni własny'), findsOneWidget);
    expect(find.text('2:29'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('rest-duration-last-custom')));
    await tester.pump();

    expect(scheduler.scheduledDurations, [
      const Duration(seconds: 149),
      const Duration(seconds: 149),
    ]);

    await cubit.close();
  });
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
  Future<TrainingSession> startFromPlan(CustomTrainingPlan plan) async =>
      session;

  @override
  Future<TrainingSession> save(TrainingSession session) async {
    this.session = session;
    return session;
  }

  @override
  Future<TrainingSession> finish(String sessionId) async =>
      session.copyWith(status: TrainingSessionStatus.completed);

  @override
  Future<TrainingSession> cancel(String sessionId) async =>
      session.copyWith(status: TrainingSessionStatus.cancelled);
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
}
