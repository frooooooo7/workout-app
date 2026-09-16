import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/training/data/offline_first_training_session_repository.dart';
import 'package:gym/features/training/domain/models/custom_training_plan.dart';
import 'package:gym/features/training/domain/models/training_history_models.dart';
import 'package:gym/features/training/domain/models/training_session.dart';
import 'package:gym/features/training/domain/repositories/training_history_repository.dart';
import 'package:gym/features/training/domain/repositories/training_session_repository.dart';
import 'package:gym/features/training/presentation/screens/ongoing_workout_screen.dart';
import 'package:gym/features/training/presentation/screens/training_session_details_screen.dart';

void main() {
  const sessionId = 'session-1';

  Widget buildScreen({
    required _FakeHistoryRepository history,
    required _FakeSessionRepository sessions,
    SessionDetailsNavigate? navigate,
    VoidCallback? onSessionsChanged,
  }) {
    return MaterialApp(
      home: TrainingSessionDetailsScreen(
        sessionId: sessionId,
        repository: history,
        sessionRepository: sessions,
        navigate: navigate,
        onSessionsChanged: onSessionsChanged,
      ),
    );
  }

  /// Szczegóły otwarte „nad” ekranem startowym — żeby sprawdzić wynik pop.
  Future<List<Object?>> pumpPushed(
    WidgetTester tester, {
    required _FakeHistoryRepository history,
    required _FakeSessionRepository sessions,
    SessionDetailsNavigate? navigate,
    VoidCallback? onSessionsChanged,
  }) async {
    final results = <Object?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                final result = await Navigator.of(context).push<Object?>(
                  MaterialPageRoute(
                    builder: (_) => TrainingSessionDetailsScreen(
                      sessionId: sessionId,
                      repository: history,
                      sessionRepository: sessions,
                      navigate: navigate,
                      onSessionsChanged: onSessionsChanged,
                    ),
                  ),
                );
                results.add(result);
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

  Future<void> openMenuItem(WidgetTester tester, String label) async {
    await tester.tap(find.byKey(const ValueKey('session-details-more-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('share button publishes session to profile', (tester) async {
    final history = _FakeHistoryRepository(_detail());
    final sessions = _FakeSessionRepository(_completed());

    await tester.pumpWidget(buildScreen(history: history, sessions: sessions));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.ios_share_rounded), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('session-details-share-button')));
    await tester.pumpAndSettle();

    expect(sessions.sharedCalls, [(sessionId, true)]);
    expect(sessions.session.sharedToProfile, isTrue);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.text('Trening pojawił się na Twoim profilu'), findsOneWidget);
  });

  testWidgets('already shared session can be removed from profile', (
    tester,
  ) async {
    final history = _FakeHistoryRepository(_detail(sharedToProfile: true));
    final sessions = _FakeSessionRepository(_completed(sharedToProfile: true));

    await tester.pumpWidget(buildScreen(history: history, sessions: sessions));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_rounded), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('session-details-share-button')));
    await tester.pumpAndSettle();

    expect(sessions.sharedCalls, [(sessionId, false)]);
    expect(sessions.session.sharedToProfile, isFalse);
    expect(find.byIcon(Icons.ios_share_rounded), findsOneWidget);
    expect(find.text('Usunięto trening z profilu'), findsOneWidget);
  });

  testWidgets('prefers local shared flag over stale history detail', (
    tester,
  ) async {
    final history = _FakeHistoryRepository(_detail());
    final sessions = _FakeSessionRepository(_completed(sharedToProfile: true));

    await tester.pumpWidget(buildScreen(history: history, sessions: sessions));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.byIcon(Icons.ios_share_rounded), findsNothing);
  });

  testWidgets('uses history flag when session is not stored locally', (
    tester,
  ) async {
    final history = _FakeHistoryRepository(_detail(sharedToProfile: true));
    final sessions = _FakeSessionRepository(
      TrainingSession(
        id: 'other-session',
        planName: 'Push A',
        status: TrainingSessionStatus.completed,
        exercises: const [],
      ),
    );

    await tester.pumpWidget(buildScreen(history: history, sessions: sessions));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('keeps previous share state when persist fails', (tester) async {
    final history = _FakeHistoryRepository(_detail());
    final sessions = _FakeSessionRepository(_completed(), failShare: true);

    await tester.pumpWidget(buildScreen(history: history, sessions: sessions));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('session-details-share-button')));
    await tester.pumpAndSettle();

    expect(
      find.text('Nie udało się zapisać zmiany. Spróbuj ponownie.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.ios_share_rounded), findsOneWidget);
    expect(sessions.session.sharedToProfile, isFalse);
  });

  testWidgets('delete asks for confirmation, deletes and closes details', (
    tester,
  ) async {
    final history = _FakeHistoryRepository(_detail());
    final sessions = _FakeSessionRepository(_completed());
    var changes = 0;

    final results = await pumpPushed(
      tester,
      history: history,
      sessions: sessions,
      onSessionsChanged: () => changes++,
    );
    await openMenuItem(tester, 'Usuń trening');

    expect(find.text('Usunąć trening?'), findsOneWidget);
    expect(
      find.text(
        'Tej operacji nie można cofnąć. Znikną też kudosy i komentarze.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('session-delete-confirm')));
    await tester.pumpAndSettle();

    expect(sessions.deletedIds, [sessionId]);
    expect(changes, 1);
    expect(results, [true]);
    expect(find.byType(TrainingSessionDetailsScreen), findsNothing);
    expect(find.text('Trening został usunięty.'), findsOneWidget);
  });

  testWidgets('cancelled delete keeps the session', (tester) async {
    final history = _FakeHistoryRepository(_detail());
    final sessions = _FakeSessionRepository(_completed());

    await tester.pumpWidget(buildScreen(history: history, sessions: sessions));
    await tester.pumpAndSettle();
    await openMenuItem(tester, 'Usuń trening');
    await tester.tap(find.text('Anuluj'));
    await tester.pumpAndSettle();

    expect(sessions.deletedIds, isEmpty);
    expect(find.byType(TrainingSessionDetailsScreen), findsOneWidget);
  });

  testWidgets('share of a session deleted elsewhere closes details', (
    tester,
  ) async {
    final history = _FakeHistoryRepository(_detail());
    final sessions = _FakeSessionRepository(_completed(), shareDeleted: true);
    var changes = 0;

    final results = await pumpPushed(
      tester,
      history: history,
      sessions: sessions,
      onSessionsChanged: () => changes++,
    );
    await tester.tap(find.byKey(const ValueKey('session-details-share-button')));
    await tester.pumpAndSettle();

    expect(results, [true]);
    expect(changes, 1);
    expect(find.text('Ten trening został usunięty.'), findsOneWidget);
  });

  testWidgets('repeat starts a new session from this workout', (tester) async {
    final history = _FakeHistoryRepository(_detail());
    final sessions = _FakeSessionRepository(_completed(withExercises: true));
    final navigations = <(String, Object?)>[];

    await tester.pumpWidget(
      buildScreen(
        history: history,
        sessions: sessions,
        navigate: (context, location, {extra}) async {
          navigations.add((location, extra));
          return null;
        },
      ),
    );
    await tester.pumpAndSettle();
    await openMenuItem(tester, 'Powtórz trening');

    expect(sessions.repeatedFrom.single.id, sessionId);
    expect(navigations.single.$1, '/app/training/ongoing-workout');
    final args = navigations.single.$2 as OngoingWorkoutArgs;
    expect(args.sessionCubit, isNotNull);
    expect(args.initialSession?.status, TrainingSessionStatus.active);
    expect(args.initialSession?.exercises.single.exerciseName, 'Bench');
  });

  testWidgets('repeat with an active workout offers going back to it', (
    tester,
  ) async {
    final active = TrainingSession(planName: 'Legs', exercises: const []);
    final history = _FakeHistoryRepository(_detail());
    final sessions = _FakeSessionRepository(
      _completed(withExercises: true),
      active: active,
    );
    final navigations = <(String, Object?)>[];

    await tester.pumpWidget(
      buildScreen(
        history: history,
        sessions: sessions,
        navigate: (context, location, {extra}) async {
          navigations.add((location, extra));
          return null;
        },
      ),
    );
    await tester.pumpAndSettle();
    await openMenuItem(tester, 'Powtórz trening');

    expect(find.text('Trwa inny trening'), findsOneWidget);
    expect(sessions.repeatedFrom, isEmpty);

    await tester.tap(
      find.byKey(const ValueKey('session-repeat-resume-active')),
    );
    await tester.pumpAndSettle();

    expect(navigations.single.$1, '/app/training/ongoing-workout');
    expect(
      (navigations.single.$2 as OngoingWorkoutArgs).initialSession?.id,
      active.id,
    );
  });

  testWidgets('edit opens the edit route and reloads after saving', (
    tester,
  ) async {
    final history = _FakeHistoryRepository(_detail());
    final sessions = _FakeSessionRepository(_completed());
    final locations = <String>[];

    await tester.pumpWidget(
      buildScreen(
        history: history,
        sessions: sessions,
        navigate: (context, location, {extra}) async {
          locations.add(location);
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();
    final loadsBefore = history.detailCalls;

    await openMenuItem(tester, 'Edytuj trening');

    expect(locations, ['/app/training/history/$sessionId/edit']);
    expect(history.detailCalls, loadsBefore + 1);
    expect(find.text('Zapisano zmiany w treningu.'), findsOneWidget);
  });
}

TrainingSession _completed({
  bool sharedToProfile = false,
  bool withExercises = false,
}) {
  return TrainingSession(
    id: 'session-1',
    planName: 'Push A',
    status: TrainingSessionStatus.completed,
    sharedToProfile: sharedToProfile,
    exercises: withExercises
        ? [
            TrainingSessionExercise(
              exerciseId: 'bench',
              exerciseName: 'Bench',
              exerciseMuscles: const ['chest'],
              exerciseCategory: 'compound',
              sets: [
                TrainingSessionSet(
                  actualWeight: '80',
                  actualReps: '5',
                  completed: true,
                ),
              ],
            ),
          ]
        : const [],
  );
}

TrainingSessionDetail _detail({bool sharedToProfile = false}) {
  return TrainingSessionDetail(
    id: 'session-1',
    startedAt: DateTime.utc(2026, 9, 13, 17),
    endedAt: DateTime.utc(2026, 9, 13, 18),
    durationSec: 3600,
    status: TrainingSessionStatus.completed,
    plan: const TrainingPlanSummary(id: 'p1', name: 'Push A'),
    note: null,
    exercises: const [],
    updatedAt: DateTime.utc(2026, 9, 13, 18),
    sharedToProfile: sharedToProfile,
  );
}

class _FakeHistoryRepository implements TrainingHistoryRepository {
  _FakeHistoryRepository(this.detail);

  final TrainingSessionDetail detail;
  int detailCalls = 0;

  @override
  Future<TrainingSessionDetail> getSessionDetail(String sessionId) async {
    detailCalls++;
    return detail;
  }

  @override
  Future<TrainingSessionPage> getSessions({
    String? cursor,
    int limit = 20,
    TrainingSessionStatus? status,
    String? planId,
    String? query,
    DateTime? from,
    DateTime? to,
  }) {
    throw UnimplementedError();
  }
}

class _FakeSessionRepository implements TrainingSessionRepository {
  _FakeSessionRepository(
    this.session, {
    this.failShare = false,
    this.shareDeleted = false,
    this.active,
  });

  TrainingSession session;
  final bool failShare;
  final bool shareDeleted;
  TrainingSession? active;
  final List<(String, bool)> sharedCalls = [];
  final List<String> deletedIds = [];
  final List<TrainingSession> repeatedFrom = [];

  @override
  Future<TrainingSession?> getActive() async => active;

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
  Future<TrainingSession> startFromSession(TrainingSession source) async {
    if (active != null) throw ActiveTrainingSessionException(active!);
    repeatedFrom.add(source);
    final started = TrainingSession(
      planName: source.planName,
      exercises: source.exercises,
    );
    active = started;
    return started;
  }

  @override
  Future<TrainingSession?> loadForEdit(String sessionId) => getById(sessionId);

  @override
  Future<void> delete(String sessionId) async {
    deletedIds.add(sessionId);
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
    if (shareDeleted) throw TrainingSessionDeletedException(sessionId);
    if (failShare) throw StateError('offline');
    session = session.copyWith(sharedToProfile: shared);
    return session;
  }
}
