import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/navigation/app_router.dart';
import 'package:gym/core/services/service_locator.dart';
import 'package:gym/features/auth/domain/models/auth_models.dart';
import 'package:gym/features/training/domain/models/custom_training_plan.dart';
import 'package:gym/features/training/domain/models/training_history_models.dart';
import 'package:gym/features/training/domain/models/training_session.dart';
import 'package:gym/features/training/domain/repositories/training_history_repository.dart';
import 'package:gym/features/training/domain/repositories/training_plan_repository.dart';
import 'package:gym/features/training/domain/repositories/training_session_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> setDesktopViewport(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    tester.view.devicePixelRatio = 1;
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      tester.view.resetDevicePixelRatio();
    });
  }

  setUp(() {
    ServiceLocator.debugSetUserScopedRepositories(
      trainingPlanRepository: _FakeTrainingPlanRepository(),
      trainingHistoryRepository: _FakeTrainingHistoryRepository(),
      trainingSessionRepository: _FakeTrainingSessionRepository(),
    );
  });

  tearDown(() {
    ServiceLocator.debugSetUserScopedRepositories();
    ServiceLocator.currentUser.value = null;
  });

  testWidgets('redirects protected deep links when no session is restored',
      (tester) async {
    await setDesktopViewport(tester);

    var resolveCalls = 0;
    final router = buildRouter(
      initialLocation: '/app/training',
      resolveUser: () async {
        resolveCalls += 1;
        return null;
      },
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(resolveCalls, 1);
    expect(router.routeInformationProvider.value.uri.path, '/login');
  });

  testWidgets('keeps protected deep links after restoring a session',
      (tester) async {
    await setDesktopViewport(tester);

    final user = AuthUser(
      id: 'user-1',
      email: 'test@example.com',
      firstName: 'Test',
      lastName: 'User',
    );

    var resolveCalls = 0;
    final router = buildRouter(
      initialLocation: '/app/activity',
      resolveUser: () async {
        resolveCalls += 1;
        return user;
      },
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(resolveCalls, 1);
    expect(ServiceLocator.currentUser.value, user);
    expect(router.routeInformationProvider.value.uri.path, '/app/activity');
  });

  testWidgets('redirects legacy /app/training/plans to /app/plans', (
    tester,
  ) async {
    await setDesktopViewport(tester);

    final user = AuthUser(
      id: 'user-1',
      email: 'test@example.com',
      firstName: 'Test',
      lastName: 'User',
    );
    ServiceLocator.currentUser.value = user;

    final router = buildRouter(
      initialLocation: '/app/training/plans',
      resolveUser: () async => user,
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(router.routeInformationProvider.value.uri.path, '/app/plans');
    expect(find.text('Plany treningowe'), findsOneWidget);
  });

  testWidgets('shows bottom nav destinations and navigates on tap', (
    tester,
  ) async {
    await setDesktopViewport(tester);

    final user = AuthUser(
      id: 'user-1',
      email: 'test@example.com',
      firstName: 'Test',
      lastName: 'User',
    );
    ServiceLocator.currentUser.value = user;

    final router = buildRouter(
      initialLocation: '/app/training',
      resolveUser: () async => user,
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Historia'), findsOneWidget);
    expect(find.text('Plany'), findsWidgets);
    expect(find.text('Aktywność'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);

    await tester.tap(find.text('Historia'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(router.routeInformationProvider.value.uri.path, '/app/history');

    await tester.tap(find.text('Plany').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(router.routeInformationProvider.value.uri.path, '/app/plans');
  });

  testWidgets('center tap without active session switches to training branch',
      (tester) async {
    await setDesktopViewport(tester);

    final user = AuthUser(
      id: 'user-1',
      email: 'test@example.com',
      firstName: 'Test',
      lastName: 'User',
    );
    ServiceLocator.currentUser.value = user;

    final router = buildRouter(
      initialLocation: '/app/history',
      resolveUser: () async => user,
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const Key('app-bottom-nav-center')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(router.routeInformationProvider.value.uri.path, '/app/training');
  });

  testWidgets('center tap with active session opens ongoing workout', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await setDesktopViewport(tester);

    final user = AuthUser(
      id: 'user-1',
      email: 'test@example.com',
      firstName: 'Test',
      lastName: 'User',
    );
    ServiceLocator.currentUser.value = user;
    ServiceLocator.debugSetUserScopedRepositories(
      trainingPlanRepository: _FakeTrainingPlanRepository(),
      trainingHistoryRepository: _FakeTrainingHistoryRepository(),
      trainingSessionRepository: _FakeTrainingSessionRepository(
        active: TrainingSession(
          planName: 'Push',
          startedAt: DateTime.now().toUtc(),
          exercises: const [],
        ),
      ),
    );

    final router = buildRouter(
      initialLocation: '/app/history',
      resolveUser: () async => user,
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('app-bottom-nav-active-dot')), findsOneWidget);

    await tester.tap(find.byKey(const Key('app-bottom-nav-center')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Dodaj pierwsze ćwiczenie'), findsOneWidget);
  });
}

class _FakeTrainingPlanRepository implements TrainingPlanRepository {
  @override
  Future<List<CustomTrainingPlan>> getAll() async => const [];

  @override
  Future<CustomTrainingPlan?> getById(String id) async => null;

  @override
  Future<CustomTrainingPlan> create(CustomTrainingPlan plan) async => plan;

  @override
  Future<CustomTrainingPlan> update(CustomTrainingPlan plan) async => plan;

  @override
  Future<void> delete(String id) async {}
}

class _FakeTrainingHistoryRepository implements TrainingHistoryRepository {
  @override
  Future<TrainingSessionPage> getSessions({
    String? cursor,
    int limit = 20,
    TrainingSessionStatus? status,
    String? planId,
    String? query,
    DateTime? from,
    DateTime? to,
  }) async {
    return const TrainingSessionPage(
      items: [],
      nextCursor: null,
      hasMore: false,
      isFromCache: false,
    );
  }

  @override
  Future<TrainingSessionDetail> getSessionDetail(String sessionId) {
    throw UnimplementedError();
  }
}

class _FakeTrainingSessionRepository implements TrainingSessionRepository {
  _FakeTrainingSessionRepository({this.active});

  TrainingSession? active;

  @override
  Future<TrainingSession?> getActive() async => active;

  @override
  Future<TrainingSession> startFromPlan(CustomTrainingPlan plan) async {
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
  Future<TrainingSession> finish(String sessionId) {
    throw UnimplementedError();
  }

  @override
  Future<TrainingSession> cancel(String sessionId) {
    throw UnimplementedError();
  }
}
