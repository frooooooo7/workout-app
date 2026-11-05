import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/training/domain/models/custom_training_plan.dart';
import 'package:gym/features/training/domain/models/post_draft.dart';
import 'package:gym/features/training/domain/models/training_session.dart';
import 'package:gym/features/training/domain/repositories/previous_performance_repository.dart';
import 'package:gym/features/training/domain/repositories/training_session_repository.dart';
import 'package:gym/features/training/presentation/bloc/training_session_cubit.dart';
import 'package:gym/features/training/presentation/screens/ongoing_workout_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

TrainingSession _session() => TrainingSession(
  planName: 'Kardio',
  startedAt: DateTime.now().toUtc(),
  exercises: [
    TrainingSessionExercise(
      exerciseId: 'treadmill',
      exerciseName: 'Bieżnia',
      exerciseMuscles: const ['legs'],
      exerciseCategory: 'cardio',
      tracking: ExerciseTracking.durationDistance,
      sets: [
        TrainingSessionSet(plannedDurationSeconds: 900, plannedDistanceM: 2500),
        TrainingSessionSet(plannedDurationSeconds: 600),
      ],
    ),
  ],
);

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
  Future<TrainingSession> setSharedToProfile(String sessionId, bool shared) =>
      throw UnimplementedError();

  @override
  Future<TrainingSession> startFromSession(TrainingSession source) =>
      throw UnimplementedError();

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

Future<_FakeTrainingSessionRepository> _pump(
  WidgetTester tester, {
  TrainingSession? session,
  PreviousPerformanceRepository? previous,
}) async {
  tester.view.physicalSize = const Size(430, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repository = _FakeTrainingSessionRepository(session ?? _session());
  final cubit = TrainingSessionCubit(repository, autoRefresh: false);
  addTearDown(cubit.close);
  await tester.pumpWidget(
    MaterialApp(
      home: OngoingWorkoutScreen(
        args: OngoingWorkoutArgs(
          initialSession: repository.session,
          sessionCubit: cubit,
          previousPerformance: previous,
        ),
      ),
    ),
  );
  await tester.pump();
  return repository;
}

/// Zapis szkicu jest odroczony o ~0,9 s.
Future<void> _flushDraftSave(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 1));

TextField _field(WidgetTester tester, String key) => tester.widget<TextField>(
  find.descendant(
    of: find.byKey(ValueKey(key)),
    matching: find.byType(TextField),
  ),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('cardio card shows time, distance and pace columns', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('CZAS'), findsOneWidget);
    expect(find.text('+ Dodaj odcinek'), findsOneWidget);
    expect(_field(tester, 'cardio-time-0-0').decoration?.hintText, '15:00');

    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('cardio-time-0-0')),
        matching: find.byType(TextField),
      ),
      '15:00',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('cardio-distance-0-0')),
        matching: find.byType(TextField),
      ),
      '2,5',
    );
    await tester.pump();

    expect(find.text('6:00'), findsOneWidget);
    expect(find.byKey(const Key('cardio-totals')), findsOneWidget);
    expect(find.text('2,5 km · 15:00 · 6:00 /km'), findsOneWidget);
  });

  testWidgets('stopwatch docks a pill and saves the time into the segment', (
    tester,
  ) async {
    final repository = await _pump(tester);

    await tester.tap(find.byKey(const Key('cardio-stopwatch-start')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const Key('cardio-stopwatch-pill')), findsOneWidget);
    expect(find.byKey(const Key('cardio-live-time')), findsOneWidget);

    await tester.tap(find.byKey(const Key('cardio-stopwatch-pause')));
    await tester.pump();
    expect(find.text('Stoper · pauza'), findsOneWidget);

    await tester.tap(find.byKey(const Key('cardio-stopwatch-save')));
    await tester.pump(const Duration(milliseconds: 600));
    await _flushDraftSave(tester);

    expect(find.byKey(const Key('cardio-stopwatch-pill')), findsNothing);
    final set = repository.session.exercises.single.sets.first;
    expect(set.actualDurationSeconds, isNotNull);
  });

  testWidgets('stopwatch time is kept when an exercise before it is removed', (
    tester,
  ) async {
    final base = _session();
    final session = base.copyWith(
      exercises: [
        TrainingSessionExercise(
          exerciseId: 'bench',
          exerciseName: 'Bench press',
          exerciseMuscles: const ['chest'],
          exerciseCategory: 'compound',
          sets: [TrainingSessionSet(plannedWeight: '60', plannedReps: '8')],
        ),
        ...base.exercises,
      ],
    );
    final repository = await _pump(tester, session: session);

    // Stoper chodzi na bieżni (drugie ćwiczenie)…
    await tester.tap(find.byKey(const Key('next-exercise-card')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cardio-stopwatch-start')));
    await tester.pump(const Duration(milliseconds: 600));

    // …a usuwamy ćwiczenie stojące przed nią.
    await tester.tap(find.byKey(const ValueKey('progress-segment-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('workout-more-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Usuń ćwiczenie z treningu'));
    await tester.pumpAndSettle();
    expect(repository.session.exercises.single.exerciseName, 'Bieżnia');

    await tester.tap(find.byKey(const Key('cardio-stopwatch-save')));
    await tester.pump(const Duration(milliseconds: 600));
    await _flushDraftSave(tester);

    expect(find.byKey(const Key('cardio-stopwatch-pill')), findsNothing);
    expect(
      repository.session.exercises.single.sets.first.actualDurationSeconds,
      isNotNull,
    );
  });

  testWidgets('stopwatch time shows up in a card rebuilt after a removal', (
    tester,
  ) async {
    final base = _session();
    // Superseria: pierwsze ćwiczenie usuwamy, więc strona (i karta bieżni)
    // buduje się od nowa.
    final session = base.copyWith(
      exercises: [
        TrainingSessionExercise(
          exerciseId: 'bench',
          exerciseName: 'Bench press',
          exerciseMuscles: const ['chest'],
          exerciseCategory: 'compound',
          supersetGroup: 'A',
          sets: [TrainingSessionSet(plannedWeight: '60', plannedReps: '8')],
        ),
        base.exercises.single.copyWith(supersetGroup: 'A'),
      ],
    );
    final repository = await _pump(tester, session: session);

    // Po serii na ćwiczeniu A1 kolej na bieżnię (A2) — jej stoper jest aktywny.
    await tester.tap(find.byKey(const ValueKey('session-set-check-0-0')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('cardio-stopwatch-start')));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1500)),
    );
    await tester.pump(const Duration(milliseconds: 600));

    await tester.longPress(find.byKey(const ValueKey('progress-segment-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Usuń „Bench press”'));
    await tester.pumpAndSettle();
    // Bench ma odhaczoną serię — pytanie o potwierdzenie.
    await tester.tap(find.text('Usuń'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('cardio-stopwatch-save')));
    await tester.pump(const Duration(milliseconds: 600));
    await _flushDraftSave(tester);
    expect(repository.session.exercises.single.exerciseName, 'Bieżnia');

    final saved = repository.session.exercises.single.sets.first;
    expect(saved.actualDurationSeconds, greaterThanOrEqualTo(1));
    // Pole czasu pokazuje zapisany czas, więc nic go potem nie nadpisze.
    final field = _field(tester, 'cardio-time-0-0');
    expect(field.controller?.text, isNotEmpty);
  });
}
