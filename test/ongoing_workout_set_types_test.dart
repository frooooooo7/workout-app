import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/training/domain/models/custom_training_plan.dart';
import 'package:gym/features/training/domain/models/training_session.dart';
import 'package:gym/features/training/domain/repositories/previous_performance_repository.dart';
import 'package:gym/features/training/domain/repositories/training_session_repository.dart';
import 'package:gym/features/training/presentation/bloc/training_session_cubit.dart';
import 'package:gym/features/training/presentation/screens/ongoing_workout_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

TrainingSession _session({
  List<TrainingSessionSet>? benchSets,
  String? benchNote,
}) {
  return TrainingSession(
    planName: 'Push',
    startedAt: DateTime.now().toUtc(),
    exercises: [
      TrainingSessionExercise(
        exerciseId: 'bench',
        exerciseName: 'Bench press',
        exerciseMuscles: const ['chest'],
        exerciseCategory: 'compound',
        note: benchNote,
        sets:
            benchSets ??
            [TrainingSessionSet(plannedWeight: '60', plannedReps: '8')],
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

TrainingSessionSet _done(
  String weight,
  String reps, {
  SetType type = SetType.normal,
}) => TrainingSessionSet(
  setType: type,
  actualWeight: weight,
  actualReps: reps,
  completed: true,
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

class _ThrowingPreviousPerformance implements PreviousPerformanceRepository {
  @override
  Future<List<TrainingSessionSet>?> lastCompletedSets({
    required String exerciseId,
    required String exerciseName,
  }) async => throw StateError('db closed');
}

Future<_FakeTrainingSessionRepository> _pump(
  WidgetTester tester, {
  TrainingSession? session,
  PreviousPerformanceRepository? previous,
}) async {
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

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('set type', () {
    testWidgets('tapping the set number picks a type and relabels the row', (
      tester,
    ) async {
      final repository = await _pump(tester);

      expect(find.text('1'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('session-set-type-0-0')));
      await tester.pumpAndSettle();

      // Arkusz wyboru pokazuje wszystkie rodzaje serii.
      expect(find.text('Seria robocza'), findsOneWidget);
      expect(find.text('Rozgrzewka'), findsOneWidget);
      expect(find.text('Do upadku'), findsOneWidget);
      expect(find.text('Drop set'), findsOneWidget);

      await tester.tap(find.text('Rozgrzewka'));
      await tester.pumpAndSettle();
      await _flushDraftSave(tester);

      expect(find.text('W'), findsOneWidget);
      expect(find.text('1'), findsNothing);
      expect(
        repository.session.exercises.first.sets.single.setType,
        SetType.warmup,
      );
    });

    testWidgets('a warm-up does not shift the numbering of working sets', (
      tester,
    ) async {
      await _pump(
        tester,
        session: _session(
          benchSets: [
            TrainingSessionSet(setType: SetType.warmup, plannedReps: '10'),
            TrainingSessionSet(plannedWeight: '60', plannedReps: '8'),
            TrainingSessionSet(plannedWeight: '60', plannedReps: '8'),
            TrainingSessionSet(setType: SetType.drop, plannedReps: '12'),
          ],
        ),
      );

      expect(find.text('W'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('D'), findsOneWidget);
    });

    testWidgets('a set added after a warm-up is a normal working set', (
      tester,
    ) async {
      final repository = await _pump(
        tester,
        session: _session(
          benchSets: [TrainingSessionSet(setType: SetType.warmup)],
        ),
      );

      await tester.tap(find.byKey(const ValueKey('add-session-set-button')));
      await _flushDraftSave(tester);

      final sets = repository.session.exercises.first.sets;
      expect(sets.map((s) => s.setType), [SetType.warmup, SetType.normal]);
      expect(find.text('W'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('the exercise list counts only working sets', (tester) async {
      await _pump(
        tester,
        session: _session(
          benchSets: [
            _done('40', '10', type: SetType.warmup),
            TrainingSessionSet(plannedWeight: '60', plannedReps: '8'),
          ],
        ),
      );

      await tester.tap(find.byIcon(Icons.format_list_bulleted_rounded));
      await tester.pumpAndSettle();

      // Rozgrzewka jest ukończona, ale nie liczy się do „x / y serii”
      // (z rozgrzewką w liczniku byłoby „1 / 2 serii”).
      expect(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Bench press'),
          matching: find.text('0 / 1 serii'),
        ),
        findsOneWidget,
      );
    });
  });

  group('previous column', () {
    testWidgets('shows the previous result per set and fills it on tap', (
      tester,
    ) async {
      final repository = await _pump(
        tester,
        previous: _FakePreviousPerformance({
          'bench': [_done('80', '8')],
        }),
      );

      expect(find.text('POPRZ.'), findsOneWidget);
      expect(find.text('80×8'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('session-set-previous-0-0')));
      await tester.pump();
      await _flushDraftSave(tester);

      final set = repository.session.exercises.first.sets.single;
      expect(set.actualWeight, '80');
      expect(set.actualReps, '8');
      expect(set.completed, isFalse, reason: 'fill must not tick the set');
    });

    testWidgets(
      'matches warm-ups to warm-ups and working sets to working sets',
      (tester) async {
        await _pump(
          tester,
          session: _session(
            benchSets: [
              TrainingSessionSet(setType: SetType.warmup),
              TrainingSessionSet(),
            ],
          ),
          previous: _FakePreviousPerformance({
            'bench': [
              _done('60', '10', type: SetType.warmup),
              _done('100', '5'),
            ],
          }),
        );

        expect(
          find.descendant(
            of: find.byKey(const ValueKey('session-set-previous-0-0')),
            matching: find.text('60×10'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('session-set-previous-0-1')),
            matching: find.text('100×5'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'a set without a previous counterpart shows a dash and is inert',
      (tester) async {
        final repository = await _pump(
          tester,
          session: _session(
            benchSets: [TrainingSessionSet(), TrainingSessionSet()],
          ),
          previous: _FakePreviousPerformance({
            'bench': [_done('100', '5')],
          }),
        );

        final second = find.byKey(const ValueKey('session-set-previous-0-1'));
        expect(
          find.descendant(of: second, matching: find.text('—')),
          findsOneWidget,
        );
        await tester.tap(second);
        await tester.pump();
        await _flushDraftSave(tester);

        expect(
          repository.session.exercises.first.sets.last.actualWeight,
          isNull,
        );
      },
    );

    testWidgets('is absent for an exercise never done before', (tester) async {
      await _pump(
        tester,
        previous: _FakePreviousPerformance({
          'press': [_done('40', '8')],
        }),
      );

      expect(find.text('POPRZ.'), findsNothing);
    });

    testWidgets('a failing lookup just means no column, never an error', (
      tester,
    ) async {
      await _pump(tester, previous: _ThrowingPreviousPerformance());

      expect(tester.takeException(), isNull);
      expect(find.text('POPRZ.'), findsNothing);
      expect(find.text('KG'), findsOneWidget);
    });

    testWidgets('gives way to the input fields on a narrow phone with RIR and '
        'tempo shown', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(360, 800);
      addTearDown(tester.view.reset);

      // Stopka ekranu (przyciski „Odpoczynek” / „Dodaj ćwiczenie”) przepełnia
      // się w testach na 360 dp niezależnie od tej zmiany — czcionka testowa
      // jest szersza niż prawdziwa. Zbieramy błędy renderowania i sprawdzamy,
      // że żaden nie pochodzi z tabeli serii.
      final errors = <FlutterErrorDetails>[];
      final previousHandler = FlutterError.onError;
      FlutterError.onError = errors.add;
      addTearDown(() => FlutterError.onError = previousHandler);

      await _pump(
        tester,
        previous: _FakePreviousPerformance({
          'bench': [_done('80', '8')],
        }),
      );

      // 360 dp z dwoma polami: kolumna mieści się.
      expect(find.text('POPRZ.'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('show-rir-column-button-0')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('show-tempo-column-button-0')),
      );
      await tester.pumpAndSettle();

      // Z RIR i tempem pola dostałyby < 40 dp — kolumna znika.
      expect(find.text('RIR'), findsOneWidget);
      expect(find.text('TEMPO'), findsOneWidget);
      expect(find.text('POPRZ.'), findsNothing);
      expect(
        errors.where((e) => !e.toString().contains('ongoing_workout_footer')),
        isEmpty,
        reason: 'the set table must not overflow at 360 dp',
      );
    });
  });

  group('exercise note', () {
    testWidgets('is added, saved into the session and cleared again', (
      tester,
    ) async {
      final repository = await _pump(tester);

      expect(find.byKey(const ValueKey('exercise-note-field-0')), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('add-exercise-note-button-0')),
      );
      await tester.pump();

      final field = find.byKey(const ValueKey('exercise-note-field-0'));
      expect(field, findsOneWidget);

      await tester.enterText(field, 'Ławka o 1 dziurkę niżej');
      await _flushDraftSave(tester);
      expect(
        repository.session.exercises.first.note,
        'Ławka o 1 dziurkę niżej',
      );
      expect(repository.session.exercises.last.note, isNull);

      await tester.enterText(field, '   ');
      await _flushDraftSave(tester);
      expect(repository.session.exercises.first.note, isNull);
    });

    testWidgets('an existing note is shown straight away', (tester) async {
      await _pump(tester, session: _session(benchNote: 'z pauzą 2 s'));

      expect(find.text('z pauzą 2 s'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('add-exercise-note-button-0')),
        findsNothing,
      );
    });
  });
}
