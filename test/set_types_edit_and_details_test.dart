import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/training/domain/models/custom_training_plan.dart';
import 'package:gym/features/training/domain/models/training_history_models.dart';
import 'package:gym/features/training/domain/models/training_session.dart';
import 'package:gym/features/training/domain/repositories/training_session_repository.dart';
import 'package:gym/features/training/presentation/screens/edit_workout_screen.dart';
import 'package:gym/features/training/presentation/widgets/session_details/session_exercise_card.dart';

TrainingSession _session() => TrainingSession(
  id: 'session-1',
  planName: 'Push',
  status: TrainingSessionStatus.completed,
  startedAt: DateTime.utc(2026, 9, 10, 10),
  finishedAt: DateTime.utc(2026, 9, 10, 11),
  exercises: [
    TrainingSessionExercise(
      id: 'ex-1',
      exerciseId: 'bench',
      exerciseName: 'Bench',
      exerciseMuscles: const ['chest'],
      exerciseCategory: 'compound',
      note: 'Ławka o 1 dziurkę niżej',
      sets: [
        TrainingSessionSet(
          id: 's1',
          setType: SetType.warmup,
          actualWeight: '60',
          actualReps: '10',
          completed: true,
        ),
        TrainingSessionSet(
          id: 's2',
          actualWeight: '100',
          actualReps: '5',
          completed: true,
        ),
      ],
    ),
  ],
);

void main() {
  group('edit finished workout', () {
    Future<void> useTallViewport(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 2400));
      tester.view.devicePixelRatio = 1;
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
        tester.view.resetDevicePixelRatio();
      });
    }

    Future<void> openEditor(
      WidgetTester tester,
      _FakeRepository repository,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push<Object?>(
                  MaterialPageRoute(
                    builder: (_) => EditWorkoutScreen(
                      sessionId: 'session-1',
                      repository: repository,
                      clock: () => DateTime.utc(2026, 9, 15, 12),
                      onSaved: () {},
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    Future<void> save(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('edit-workout-save')));
      await tester.pumpAndSettle();
    }

    testWidgets('shows the stored set types and note', (tester) async {
      await useTallViewport(tester);
      await openEditor(tester, _FakeRepository(_session()));

      expect(find.text('W'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('Ławka o 1 dziurkę niżej'), findsOneWidget);
    });

    testWidgets('saving without touching them keeps types and note', (
      tester,
    ) async {
      await useTallViewport(tester);
      final repository = _FakeRepository(_session());
      await openEditor(tester, repository);

      await save(tester);

      final exercise = repository.saved.single.exercises.single;
      expect(exercise.sets.map((s) => s.setType), [
        SetType.warmup,
        SetType.normal,
      ]);
      expect(exercise.note, 'Ławka o 1 dziurkę niżej');
    });

    testWidgets('changes a set type and edits the note', (tester) async {
      await useTallViewport(tester);
      final repository = _FakeRepository(_session());
      await openEditor(tester, repository);

      await tester.tap(find.byKey(const ValueKey('edit-set-0-1-type')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Do upadku'));
      await tester.pumpAndSettle();
      expect(find.text('F'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('edit-exercise-note-ex-1')),
        'z pauzą',
      );
      await save(tester);

      final exercise = repository.saved.single.exercises.single;
      expect(exercise.sets.map((s) => s.setType), [
        SetType.warmup,
        SetType.failure,
      ]);
      expect(exercise.note, 'z pauzą');
    });

    testWidgets('clearing the note removes it', (tester) async {
      await useTallViewport(tester);
      final repository = _FakeRepository(_session());
      await openEditor(tester, repository);

      await tester.enterText(
        find.byKey(const ValueKey('edit-exercise-note-ex-1')),
        '',
      );
      await save(tester);

      expect(repository.saved.single.exercises.single.note, isNull);
    });
  });

  group('session details card', () {
    Widget card(TrainingExerciseDetail exercise) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SessionExerciseCard(exercise: exercise, index: 0),
        ),
      ),
    );

    TrainingExerciseSetDetail set(
      int index,
      SetType type,
      double weight,
      int reps,
    ) => TrainingExerciseSetDetail(
      setIndex: index,
      setType: type,
      actual: TrainingSetMetrics(weightKg: weight, reps: reps),
      completed: true,
    );

    testWidgets('labels sets W/1/2/F, shows the note and counts working sets', (
      tester,
    ) async {
      await tester.pumpWidget(
        card(
          TrainingExerciseDetail(
            exerciseId: 'bench',
            exerciseName: 'Bench',
            note: 'Ławka o 1 dziurkę niżej',
            sets: [
              set(0, SetType.warmup, 60, 10),
              set(1, SetType.normal, 100, 5),
              set(2, SetType.normal, 100, 4),
              set(3, SetType.failure, 90, 8),
            ],
          ),
        ),
      );

      expect(find.text('W'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('F'), findsOneWidget);
      // Numeracja zaczyna się od 1, a nie od indeksu 0.
      expect(find.text('0'), findsNothing);
      expect(find.text('Ławka o 1 dziurkę niżej'), findsOneWidget);
      // 3 serie robocze ukończone z 3; rozgrzewka nie wlicza się do y w „x/y”.
      expect(find.textContaining('3/3 serii'), findsOneWidget);
    });

    testWidgets('a warm-up never becomes the heaviest set', (tester) async {
      await tester.pumpWidget(
        card(
          TrainingExerciseDetail(
            exerciseId: 'bench',
            exerciseName: 'Bench',
            sets: [
              set(0, SetType.warmup, 150, 1),
              set(1, SetType.normal, 100, 5),
            ],
          ),
        ),
      );

      expect(find.textContaining('Najcięższa seria: 100'), findsOneWidget);
    });

    testWidgets('no note row when the note is blank', (tester) async {
      await tester.pumpWidget(
        card(
          TrainingExerciseDetail(
            exerciseId: 'bench',
            exerciseName: 'Bench',
            note: '   ',
            sets: [set(0, SetType.normal, 100, 5)],
          ),
        ),
      );

      expect(find.byIcon(Icons.sticky_note_2_outlined), findsNothing);
    });
  });
}

class _FakeRepository implements TrainingSessionRepository {
  _FakeRepository(this.session);

  final TrainingSession session;
  final List<TrainingSession> saved = [];

  @override
  Future<TrainingSession?> loadForEdit(String sessionId) async => session;

  @override
  Future<TrainingSession> save(TrainingSession session) async {
    saved.add(session);
    return session;
  }

  @override
  Future<TrainingSession?> getActive() async => null;

  @override
  Future<TrainingSession?> getById(String sessionId) async => session;

  @override
  Future<TrainingSession> startFromPlan(CustomTrainingPlan plan) =>
      throw UnimplementedError();

  @override
  Future<TrainingSession> startCustom({
    String planName = TrainingSession.defaultCustomName,
  }) => throw UnimplementedError();

  @override
  Future<TrainingSession> startFromSession(TrainingSession source) =>
      throw UnimplementedError();

  @override
  Future<TrainingSession> finish(String sessionId) =>
      throw UnimplementedError();

  @override
  Future<TrainingSession> cancel(String sessionId) =>
      throw UnimplementedError();

  @override
  Future<TrainingSession> setSharedToProfile(String sessionId, bool shared) =>
      throw UnimplementedError();

  @override
  Future<void> delete(String sessionId) async {}
}
