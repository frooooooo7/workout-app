import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/training/domain/models/custom_training_plan.dart';
import 'package:gym/features/training/domain/models/training_session.dart';
import 'package:gym/features/training/domain/repositories/training_session_repository.dart';
import 'package:gym/features/training/presentation/bloc/training_session_cubit.dart';
import 'package:gym/features/training/presentation/screens/ongoing_workout_screen.dart';

void main() {
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
