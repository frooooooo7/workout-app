import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/training/domain/models/custom_training_plan.dart';
import 'package:gym/features/training/domain/models/training_session.dart';
import 'package:gym/features/training/domain/repositories/training_session_repository.dart';
import 'package:gym/features/training/presentation/screens/edit_workout_screen.dart';

void main() {
  Future<void> useTallViewport(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    tester.view.devicePixelRatio = 1;
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      tester.view.resetDevicePixelRatio();
    });
  }

  Future<List<Object?>> pumpEditor(
    WidgetTester tester,
    _FakeRepository repository, {
    VoidCallback? onSaved,
  }) async {
    final results = <Object?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                results.add(
                  await Navigator.of(context).push<Object?>(
                    MaterialPageRoute(
                      builder: (_) => EditWorkoutScreen(
                        sessionId: 'session-1',
                        repository: repository,
                        clock: () => DateTime.utc(2026, 9, 15, 12),
                        onSaved: onSaved ?? () {},
                      ),
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return results;
  }

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('edit-workout-save')));
    await tester.pumpAndSettle();
  }

  testWidgets('validates the form and saves an edited workout', (
    tester,
  ) async {
    await useTallViewport(tester);
    final repository = _FakeRepository(_session());
    var savedCalls = 0;
    final results = await pumpEditor(
      tester,
      repository,
      onSaved: () => savedCalls++,
    );

    expect(find.text('Edytuj trening'), findsOneWidget);
    expect(find.text('Bench'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('edit-workout-duration')),
      'abc',
    );
    await tapSave(tester);
    expect(
      find.text('Czas trwania musi być liczbą minut (0 lub więcej).'),
      findsOneWidget,
    );
    expect(repository.saved, isEmpty);

    await tester.enterText(
      find.byKey(const ValueKey('edit-workout-duration')),
      '90',
    );
    await tester.enterText(
      find.byKey(const ValueKey('edit-set-0-0-weight')),
      '8x',
    );
    await tapSave(tester);
    expect(find.text('Nieprawidłowy ciężar: „Bench”, seria 1.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('edit-set-0-0-weight')),
      '82,5',
    );
    await tester.enterText(
      find.byKey(const ValueKey('edit-workout-name')),
      'Push B',
    );
    await tester.tap(find.byKey(const ValueKey('edit-set-0-1-completed')));
    await tester.tap(find.byKey(const ValueKey('edit-exercise-add-set-0')));
    await tester.pumpAndSettle();
    await tapSave(tester);

    final saved = repository.saved.single;
    expect(saved.id, 'session-1');
    expect(saved.planName, 'Push B');
    expect(saved.finishedAt, saved.startedAt.add(const Duration(minutes: 90)));
    final sets = saved.exercises.single.sets;
    expect(sets, hasLength(3));
    expect(sets[0].actualWeight, '82.5');
    expect(sets[1].completed, isTrue);
    expect(sets[2].completed, isFalse);
    expect(savedCalls, 1);
    expect(results, [true]);
  });

  testWidgets('removing the only exercise is rejected on save', (
    tester,
  ) async {
    await useTallViewport(tester);
    final repository = _FakeRepository(_session());
    await pumpEditor(tester, repository);

    await tester.tap(find.byKey(const ValueKey('edit-exercise-remove-0')));
    await tester.pumpAndSettle();
    await tapSave(tester);

    expect(
      find.text('Trening musi mieć co najmniej jedno ćwiczenie.'),
      findsOneWidget,
    );
    expect(repository.saved, isEmpty);
  });

  testWidgets('shows an error when the workout cannot be loaded', (
    tester,
  ) async {
    await useTallViewport(tester);
    await pumpEditor(tester, _FakeRepository(null));

    expect(
      find.text(
        'Nie udało się wczytać treningu. Sprawdź połączenie i spróbuj ponownie.',
      ),
      findsOneWidget,
    );
    expect(find.text('Spróbuj ponownie'), findsOneWidget);
  });

  testWidgets('a workout deleted meanwhile cannot be saved', (tester) async {
    await useTallViewport(tester);
    final repository = _FakeRepository(_session(), deleted: true);
    await pumpEditor(tester, repository);

    await tapSave(tester);

    expect(
      find.text('Ten trening został usunięty — nie można go zapisać.'),
      findsOneWidget,
    );
  });
}

TrainingSession _session() => TrainingSession(
  id: 'session-1',
  serverId: 'srv-1',
  planName: 'Push A',
  status: TrainingSessionStatus.completed,
  startedAt: DateTime.utc(2026, 9, 10, 10),
  finishedAt: DateTime.utc(2026, 9, 10, 11),
  exercises: [
    TrainingSessionExercise(
      exerciseId: 'bench',
      exerciseName: 'Bench',
      exerciseMuscles: const ['chest'],
      exerciseCategory: 'compound',
      sets: [
        TrainingSessionSet(actualWeight: '80', actualReps: '5', completed: true),
        TrainingSessionSet(actualWeight: '80', actualReps: '5'),
      ],
    ),
  ],
);

class _FakeRepository implements TrainingSessionRepository {
  _FakeRepository(this.session, {this.deleted = false});

  final TrainingSession? session;
  final bool deleted;
  final List<TrainingSession> saved = [];

  @override
  Future<TrainingSession?> loadForEdit(String sessionId) async => session;

  @override
  Future<TrainingSession> save(TrainingSession session) async {
    if (deleted) throw TrainingSessionDeletedException(session.id);
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
