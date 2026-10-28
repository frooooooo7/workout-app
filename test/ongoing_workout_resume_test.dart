import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gym/features/training/domain/models/custom_training_plan.dart';
import 'package:gym/features/training/domain/models/post_draft.dart';
import 'package:gym/features/training/domain/models/training_session.dart';
import 'package:gym/features/training/domain/repositories/training_session_repository.dart';
import 'package:gym/features/training/domain/services/rest_timer_scheduler.dart';
import 'package:gym/features/training/presentation/bloc/training_session_cubit.dart';
import 'package:gym/features/training/presentation/screens/ongoing_workout_screen.dart';
import 'package:gym/features/training/presentation/utils/workout_resume_store.dart';
import 'package:gym/features/training/presentation/widgets/ongoing_workout/rest_timer_controller.dart';
import 'package:gym/features/training/presentation/widgets/ongoing_workout/rest_timer_pill.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    WorkoutResumeStore.resetForTest();
  });

  testWidgets('leaving and coming back keeps the rest timer and the exercise', (
    tester,
  ) async {
    final repository = _FakeRepository(_session());
    final cubit = TrainingSessionCubit(repository, autoRefresh: false);
    final scheduler = _FakeScheduler();
    final router = _router(repository, cubit, scheduler, tester);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await _open(tester);

    // Druga strona, seria odhaczona → przerwa 1:30.
    await tester.drag(find.text('Bench press'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('Ćwiczenie 2 z 3'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('session-set-check-1-0')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));
    expect(_restLabel('1:20'), findsOneWidget);

    // Zwinięcie ekranu nie odwołuje powiadomienia o końcu przerwy.
    await tester.tap(find.byKey(const Key('collapse-workout-button')));
    await tester.pumpAndSettle();
    expect(find.byType(OngoingWorkoutScreen), findsNothing);
    expect(scheduler.cancelCount, 0);

    await tester.pump(const Duration(seconds: 20));
    await _open(tester);

    expect(find.text('Ćwiczenie 2 z 3'), findsOneWidget);
    expect(find.text('Shoulder press'), findsOneWidget);
    expect(_restDock(tester).visible, isTrue);
    // ~1:00 (przejścia ekranów też zajmują chwilę) — nie od nowa 1:30.
    final label = tester.widget<Text>(
      find.byKey(const ValueKey('rest-timer-remaining-label')),
    );
    expect(label.data, matches(RegExp(r'^(0:5\d|1:00)$')));

    // Po końcu przerwy poza ekranem panel wraca z „0:00”.
    await tester.tap(find.byKey(const Key('collapse-workout-button')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(minutes: 2));
    await _open(tester);
    expect(_restLabel('0:00'), findsOneWidget);
    expect(_restDock(tester).visible, isTrue);

    await cubit.close();
  });

  testWidgets('without a saved position it opens on the last worked exercise', (
    tester,
  ) async {
    final base = _session();
    final session = base.copyWith(
      exercises: [
        for (final (i, exercise) in base.exercises.indexed)
          i == 0
              ? exercise.copyWith(
                  sets: [
                    for (final set in exercise.sets)
                      set.copyWith(completed: true),
                  ],
                )
              : exercise,
      ],
    );
    final repository = _FakeRepository(session);
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
    await tester.pumpAndSettle();

    // Pierwsze skończone — start od następnego.
    expect(find.text('Ćwiczenie 2 z 3'), findsOneWidget);
    expect(find.text('Shoulder press'), findsOneWidget);

    await cubit.close();
  });

  testWidgets('after an app restart the position comes from storage', (
    tester,
  ) async {
    final session = _session();
    SharedPreferences.setMockInitialValues({
      'ongoing_workout_resume':
          '{"sessionId":"${session.id}","exerciseId":"${session.exercises[2].id}"}',
    });
    final cubit = TrainingSessionCubit(
      _FakeRepository(session),
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
    await tester.pumpAndSettle();

    expect(find.text('Ćwiczenie 3 z 3'), findsOneWidget);
    expect(find.text('Squat'), findsOneWidget);

    await cubit.close();
  });

  testWidgets('long press on an exercise moves it and reorders the session', (
    tester,
  ) async {
    final repository = _FakeRepository(_session());
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
    await tester.pumpAndSettle();

    await tester.longPress(
      find.byKey(const ValueKey('session-exercise-header-0')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Przesuń później'), findsOneWidget);
    await tester.tap(find.text('Przesuń później'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));

    // Ten sam ekran ćwiczenia, tylko pod numerem 2.
    expect(find.text('Ćwiczenie 2 z 3'), findsOneWidget);
    expect(find.text('Bench press'), findsOneWidget);
    expect(repository.session.exercises.map((e) => e.exerciseName), [
      'Shoulder press',
      'Bench press',
      'Squat',
    ]);

    // Pełna lista: przytrzymanie segmentu → „Zmień kolejność ćwiczeń”.
    await tester.longPress(find.byKey(const ValueKey('progress-segment-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zmień kolejność ćwiczeń'));
    await tester.pumpAndSettle();
    expect(find.text('Kolejność ćwiczeń'), findsOneWidget);

    final handle = find.descendant(
      of: find.byKey(const ValueKey('order-block-2')),
      matching: find.byIcon(Icons.drag_handle_rounded),
    );
    final top = tester.getCenter(find.byKey(const ValueKey('order-block-0')));
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveTo(Offset(tester.getCenter(handle).dx, top.dy - 120));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('exercise-order-save')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));

    expect(repository.session.exercises.map((e) => e.exerciseName), [
      'Squat',
      'Shoulder press',
      'Bench press',
    ]);
    expect(find.text('Ćwiczenie 3 z 3'), findsOneWidget);

    await cubit.close();
  });

  test('restore keeps counting from the saved end time', () {
    var now = DateTime(2026, 10, 28, 12);
    final controller = RestTimerController(clock: () => now);
    controller.restore(
      endsAt: now.add(const Duration(seconds: 45)),
      total: const Duration(seconds: 90),
    );
    expect(controller.isActive, isTrue);
    expect(controller.remaining.value, const Duration(seconds: 45));
    expect(controller.total, const Duration(seconds: 90));

    // Przerwa, która minęła dawno, nie wraca.
    now = now.add(const Duration(hours: 1));
    controller.restore(
      endsAt: now.subtract(const Duration(minutes: 30)),
      total: const Duration(seconds: 90),
    );
    expect(controller.isVisible, isFalse);
    controller.dispose();
  });
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('Wróć do treningu'));
  await tester.pumpAndSettle();
}

GoRouter _router(
  _FakeRepository repository,
  TrainingSessionCubit cubit,
  RestTimerScheduler scheduler,
  WidgetTester tester,
) {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => context.push(
                '/workout',
                extra: OngoingWorkoutArgs(
                  initialSession: repository.session,
                  sessionCubit: cubit,
                  restTimerScheduler: scheduler,
                  restTimerClock: () => tester.binding.clock.now(),
                ),
              ),
              child: const Text('Wróć do treningu'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/workout',
        builder: (_, state) =>
            OngoingWorkoutScreen(args: state.extra as OngoingWorkoutArgs?),
      ),
    ],
  );
}

TrainingSession _session() {
  TrainingSessionExercise exercise(String id, String name) =>
      TrainingSessionExercise(
        exerciseId: id,
        exerciseName: name,
        exerciseMuscles: const ['chest'],
        exerciseCategory: 'compound',
        sets: [
          TrainingSessionSet(plannedWeight: '60', plannedReps: '8'),
          TrainingSessionSet(plannedWeight: '60', plannedReps: '8'),
        ],
      );
  return TrainingSession(
    planName: 'Push',
    startedAt: DateTime.now().toUtc(),
    exercises: [
      exercise('bench', 'Bench press'),
      exercise('press', 'Shoulder press'),
      exercise('squat', 'Squat'),
    ],
  );
}

class _FakeRepository implements TrainingSessionRepository {
  _FakeRepository(this.session);

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
  Future<TrainingSession> finish(String sessionId) async =>
      session.copyWith(status: TrainingSessionStatus.completed);

  @override
  Future<TrainingSession> cancel(String sessionId) async =>
      session.copyWith(status: TrainingSessionStatus.cancelled);

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
  Future<TrainingSession> sharePost(String sessionId, PostDraft draft) =>
      throw UnimplementedError();

  @override
  Future<PostPhotoChange> pendingPostPhoto(String sessionId) async =>
      const KeepPostPhoto();
}

class _FakeScheduler implements RestTimerScheduler {
  int cancelCount = 0;

  @override
  Future<void> scheduleRestFinished({required Duration duration}) async {}

  @override
  Future<void> cancelRestFinished() async => cancelCount += 1;

  @override
  Future<void> warmUp() async {}
}

RestTimerDock _restDock(WidgetTester tester) =>
    tester.widget<RestTimerDock>(find.byType(RestTimerDock));

Finder _restLabel(String text) => find.byWidgetPredicate(
  (widget) =>
      widget is Text &&
      widget.key == const ValueKey('rest-timer-remaining-label') &&
      widget.data == text,
);
