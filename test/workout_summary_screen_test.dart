import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/auth/domain/models/auth_models.dart';
import 'package:gym/features/training/domain/models/custom_training_plan.dart';
import 'package:gym/features/training/domain/models/training_session.dart';
import 'package:gym/features/training/domain/repositories/training_session_repository.dart';
import 'package:gym/features/training/presentation/screens/workout_summary_screen.dart';
import 'package:gym/features/training/presentation/widgets/workout_summary/workout_share_card.dart';

void main() {
  const user = AuthUser(
    id: 'u1',
    email: 'jan@gym.com',
    firstName: 'Jan',
    lastName: 'Kowalski',
  );

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  Widget buildScreen(_FakeTrainingSessionRepository repository) {
    return MaterialApp(
      home: WorkoutSummaryScreen(
        args: WorkoutSummaryArgs(
          session: repository.session,
          repository: repository,
          user: user,
        ),
      ),
    );
  }

  testWidgets('shows completion hero and session metrics', (tester) async {
    final repository = _FakeTrainingSessionRepository(_completedSession());

    await tester.pumpWidget(buildScreen(repository));
    await tester.pumpAndSettle();

    expect(find.text('Trening ukończony!'), findsOneWidget);
    expect(find.textContaining('Push'), findsOneWidget);
    // 45 minut treningu.
    expect(find.text('45:00'), findsOneWidget);
    // 60×8 + 62,5×8 = 980 kg (nieukończona seria nie liczy się) — w karcie
    // statystyk i w wyróżnieniu największej objętości.
    expect(find.text('980 kg'), findsNWidgets(2));
    expect(find.text('Ukończone serie'), findsOneWidget);
    expect(find.text('2'), findsWidgets);
    expect(find.text('Ukończono 2 z 3 serii'), findsOneWidget);
    expect(find.text('67%'), findsOneWidget);
  });

  testWidgets('highlights the heaviest set and top-volume exercise', (
    tester,
  ) async {
    final repository = _FakeTrainingSessionRepository(_completedSession());

    await tester.pumpWidget(buildScreen(repository));
    await tester.pumpAndSettle();

    final heaviest = find.byKey(const ValueKey('summary-highlight-heaviest'));
    expect(
      find.descendant(of: heaviest, matching: find.text('62,5 kg × 8')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: heaviest, matching: find.text('Bench press')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('summary-highlight-volume')),
      findsOneWidget,
    );
  });

  testWidgets('share button persists flag and switches card to shared state', (
    tester,
  ) async {
    final repository = _FakeTrainingSessionRepository(_completedSession());

    await tester.pumpWidget(buildScreen(repository));
    await tester.pumpAndSettle();

    final shareButton = find.byKey(const ValueKey('workout-share-button'));
    await scrollTo(tester, shareButton);
    expect(find.text('Udostępnij na profilu'), findsOneWidget);

    await tester.tap(shareButton);
    await tester.pumpAndSettle();

    expect(repository.sharedCalls, [(repository.session.id, true)]);
    expect(repository.session.sharedToProfile, isTrue);
    expect(find.text('Udostępniono na profilu'), findsOneWidget);
    expect(find.text('Widoczny na profilu'), findsOneWidget);
    expect(find.byKey(const ValueKey('workout-share-button')), findsNothing);

    await tester.tap(find.text('Cofnij'));
    await tester.pumpAndSettle();

    expect(repository.sharedCalls.last, (repository.session.id, false));
    expect(repository.session.sharedToProfile, isFalse);
    expect(find.byKey(const ValueKey('workout-share-button')), findsOneWidget);
  });

  testWidgets('starts in shared state when session is already shared', (
    tester,
  ) async {
    final repository = _FakeTrainingSessionRepository(
      _completedSession().copyWith(sharedToProfile: true),
    );

    await tester.pumpWidget(buildScreen(repository));
    await tester.pumpAndSettle();

    await scrollTo(tester, find.byType(WorkoutShareCard));

    expect(find.text('Udostępniono na profilu'), findsOneWidget);
    expect(find.byKey(const ValueKey('workout-share-button')), findsNothing);
  });

  testWidgets('reverts card state and shows snackbar when saving fails', (
    tester,
  ) async {
    final repository = _FakeTrainingSessionRepository(
      _completedSession(),
      failShare: true,
    );

    await tester.pumpWidget(buildScreen(repository));
    await tester.pumpAndSettle();

    final shareButton = find.byKey(const ValueKey('workout-share-button'));
    await scrollTo(tester, shareButton);
    await tester.tap(shareButton);
    await tester.pumpAndSettle();

    expect(
      find.text('Nie udało się zapisać zmiany. Spróbuj ponownie.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('workout-share-button')), findsOneWidget);
    expect(repository.session.sharedToProfile, isFalse);
  });

  testWidgets('done button leaves the summary', (tester) async {
    final repository = _FakeTrainingSessionRepository(_completedSession());

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => WorkoutSummaryScreen(
                      args: WorkoutSummaryArgs(
                        session: repository.session,
                        repository: repository,
                        user: user,
                      ),
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(WorkoutSummaryScreen), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('workout-summary-done-button')));
    await tester.pumpAndSettle();

    expect(find.byType(WorkoutSummaryScreen), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });
}

TrainingSession _completedSession() {
  final startedAt = DateTime.utc(2026, 9, 13, 15, 0);
  return TrainingSession(
    planName: 'Push',
    status: TrainingSessionStatus.completed,
    startedAt: startedAt,
    finishedAt: startedAt.add(const Duration(minutes: 45)),
    exercises: [
      TrainingSessionExercise(
        exerciseId: 'bench',
        exerciseName: 'Bench press',
        exerciseMuscles: const ['chest', 'triceps'],
        exerciseCategory: 'compound',
        sets: [
          TrainingSessionSet(
            plannedWeight: '60',
            plannedReps: '8',
            actualWeight: '60',
            actualReps: '8',
            completed: true,
            completedAt: startedAt.add(const Duration(minutes: 5)),
          ),
          TrainingSessionSet(
            plannedWeight: '60',
            plannedReps: '8',
            actualWeight: '62,5',
            actualReps: '8',
            completed: true,
            completedAt: startedAt.add(const Duration(minutes: 9)),
          ),
          TrainingSessionSet(
            plannedWeight: '60',
            plannedReps: '8',
            actualWeight: '65',
            actualReps: '6',
          ),
        ],
      ),
    ],
  );
}

class _FakeTrainingSessionRepository implements TrainingSessionRepository {
  _FakeTrainingSessionRepository(this.session, {this.failShare = false});

  TrainingSession session;
  final bool failShare;
  final List<(String, bool)> sharedCalls = [];

  @override
  Future<TrainingSession?> getActive() async => null;

  @override
  Future<TrainingSession?> getById(String sessionId) async =>
      session.id == sessionId || session.serverId == sessionId ? session : null;

  @override
  Future<TrainingSession> startFromPlan(CustomTrainingPlan plan) {
    throw UnimplementedError();
  }

  @override
  Future<TrainingSession> startCustom({
    String planName = TrainingSession.defaultCustomName,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<TrainingSession> save(TrainingSession session) async => session;

  @override
  Future<TrainingSession> finish(String sessionId) async => session;

  @override
  Future<TrainingSession> cancel(String sessionId) async => session;

  @override
  Future<TrainingSession> setSharedToProfile(
    String sessionId,
    bool shared,
  ) async {
    sharedCalls.add((sessionId, shared));
    if (failShare) throw StateError('offline');
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
}
