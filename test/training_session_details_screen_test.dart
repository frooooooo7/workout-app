import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/training/domain/models/custom_training_plan.dart';
import 'package:gym/features/training/domain/models/training_history_models.dart';
import 'package:gym/features/training/domain/models/training_session.dart';
import 'package:gym/features/training/domain/repositories/training_history_repository.dart';
import 'package:gym/features/training/domain/repositories/training_session_repository.dart';
import 'package:gym/features/training/presentation/screens/training_session_details_screen.dart';

void main() {
  const sessionId = 'session-1';

  Widget buildScreen({
    required _FakeHistoryRepository history,
    required _FakeSessionRepository sessions,
  }) {
    return MaterialApp(
      home: TrainingSessionDetailsScreen(
        sessionId: sessionId,
        repository: history,
        sessionRepository: sessions,
      ),
    );
  }

  testWidgets('share button publishes session to profile', (tester) async {
    final history = _FakeHistoryRepository(_detail());
    final sessions = _FakeSessionRepository(
      TrainingSession(
        id: sessionId,
        planName: 'Push A',
        status: TrainingSessionStatus.completed,
        exercises: const [],
      ),
    );

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
    final sessions = _FakeSessionRepository(
      TrainingSession(
        id: sessionId,
        planName: 'Push A',
        status: TrainingSessionStatus.completed,
        sharedToProfile: true,
        exercises: const [],
      ),
    );

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
    final sessions = _FakeSessionRepository(
      TrainingSession(
        id: sessionId,
        planName: 'Push A',
        status: TrainingSessionStatus.completed,
        sharedToProfile: true,
        exercises: const [],
      ),
    );

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
    final sessions = _FakeSessionRepository(
      TrainingSession(
        id: sessionId,
        planName: 'Push A',
        status: TrainingSessionStatus.completed,
        exercises: const [],
      ),
      failShare: true,
    );

    await tester.pumpWidget(buildScreen(history: history, sessions: sessions));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('session-details-share-button')));
    await tester.pumpAndSettle();

    expect(find.text('Nie udało się zapisać zmiany. Spróbuj ponownie.'), findsOneWidget);
    expect(find.byIcon(Icons.ios_share_rounded), findsOneWidget);
    expect(sessions.session.sharedToProfile, isFalse);
  });
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

  @override
  Future<TrainingSessionDetail> getSessionDetail(String sessionId) async =>
      detail;

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
  _FakeSessionRepository(this.session, {this.failShare = false});

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
}
