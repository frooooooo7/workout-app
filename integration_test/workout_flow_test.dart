// Integracyjny test UI: prawdziwe drzewo aplikacji (go_router, ekrany,
// cubity, repozytoria offline-first na sqflite) bez backendu — logowanie
// przez podmieniony HTTP, reszta działa jak offline.
//
//   flutter test integration_test -d windows        # desktop (Visual Studio)
//   flutter test integration_test -d flutter-tester # bez urządzenia (CI)
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/constants/api_constants.dart';
import 'package:gym/core/navigation/app_router.dart';
import 'package:gym/core/network/api_client.dart';
import 'package:gym/core/services/service_locator.dart';
import 'package:gym/core/storage/token_storage.dart';
import 'package:gym/core/theme/app_theme.dart';
import 'package:gym/features/auth/data/auth_repository.dart';
import 'package:gym/features/auth/domain/models/auth_models.dart';
import 'package:gym/features/feed/domain/models/cursor_page.dart';
import 'package:gym/features/feed/domain/repositories/feed_repository.dart';
import 'package:gym/features/library/data/exercise_database.dart';
import 'package:gym/features/library/data/exercise_remote_data_source.dart';
import 'package:gym/features/library/data/offline_first_exercise_repository.dart';
import 'package:gym/features/library/data/sync/exercise_sync_engine.dart';
import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:gym/features/profile/domain/models/following_user.dart';
import 'package:gym/features/profile/domain/repositories/profile_repository.dart';
import 'package:gym/features/training/data/local_training_stats_repository.dart';
import 'package:gym/features/training/data/offline_first_training_history_repository.dart';
import 'package:gym/features/training/data/offline_first_training_plan_repository.dart';
import 'package:gym/features/training/data/offline_first_training_session_repository.dart';
import 'package:gym/features/training/data/sync/training_plan_sync_engine.dart';
import 'package:gym/features/training/data/sync/training_session_sync_engine.dart';
import 'package:gym/features/training/data/training_history_local_cache.dart';
import 'package:gym/features/training/data/training_history_remote_data_source.dart';
import 'package:gym/features/training/data/training_plan_remote_data_source.dart';
import 'package:gym/features/training/data/training_session_local_history.dart';
import 'package:gym/features/training/data/training_session_remote_data_source.dart';
import 'package:gym/features/training/domain/models/custom_training_plan.dart';
import 'package:gym/features/training/domain/services/rest_timer_scheduler.dart';
import 'package:gym/features/training/presentation/screens/training_session_details_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _user = AuthUser(
  id: 'it-user',
  email: 'jan@example.com',
  firstName: 'Jan',
  lastName: 'Kowalski',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late ExerciseDatabase db;
  final loginRequests = <http.Request>[];

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});

    // Serwer: logowanie działa, wszystko inne jest „bez sieci”.
    final api = http.runWithClient(
      () => ApiClient(
        baseUrl: apiBaseUrlFor('http://gym.test'),
        getToken: () async => 'token',
      ),
      () => MockClient((request) async {
        if (request.url.path == '/api/v1/auth/login') {
          loginRequests.add(request);
          return http.Response(
            jsonEncode({
              'token': 'token',
              'user': {
                'id': _user.id,
                'email': _user.email,
                'firstName': _user.firstName,
                'lastName': _user.lastName,
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        throw const SocketException('offline');
      }),
    );

    ServiceLocator.tokenStorage = _MemoryTokenStorage();
    ServiceLocator.authRepository = AuthRepository(api);
    ServiceLocator.restTimerScheduler = _NoopRestTimerScheduler();
    ServiceLocator.profileRepository = _EmptyProfileRepository();
    ServiceLocator.debugSetFeed(
      repository: _EmptyFeedRepository(),
      cache: _NoFeedCache(),
    );

    dir = await Directory.systemTemp.createTemp('gym_integration');
    db = ExerciseDatabase('it.db', directoryOverride: dir.path);
    final sessionRemote = TrainingSessionRemoteDataSource(api);
    final localSessions = TrainingSessionLocalHistory(db);
    final exercises = OfflineFirstExerciseRepository(
      localDb: db,
      syncEngine: ExerciseSyncEngine(
        remote: ExerciseRemoteDataSource(api),
        localDb: db,
      )..stop(),
    );
    final plans = OfflineFirstTrainingPlanRepository(
      localDb: db,
      syncEngine: TrainingPlanSyncEngine(
        remote: TrainingPlanRemoteDataSource(api),
        localDb: db,
      )..stop(),
    );
    ServiceLocator.debugSetUserScopedRepositories(
      exerciseRepository: exercises,
      trainingPlanRepository: plans,
      trainingSessionRepository: OfflineFirstTrainingSessionRepository(
        localDb: db,
        syncEngine: TrainingSessionSyncEngine(
          remote: sessionRemote,
          localDb: db,
        )..stop(),
        remote: sessionRemote,
      ),
      trainingHistoryRepository: OfflineFirstTrainingHistoryRepository(
        remote: TrainingHistoryRemoteDataSource(api),
        localCache: TrainingHistoryLocalCache(db),
        localSessions: localSessions,
      ),
      trainingStatsRepository: LocalTrainingStatsRepository(localSessions),
    );

    // Plan na dziś — karta „Dzisiejszy trening” pozwala go wystartować.
    final squat = await exercises.create(
      name: 'Przysiad ze sztangą',
      muscles: const [MuscleGroup.legs, MuscleGroup.glutes],
      category: ExerciseCategory.compound,
      description: '',
    );
    await plans.create(
      CustomTrainingPlan(
        name: 'Nogi integracja',
        selectedDays: [DateTime.now().weekday],
        exercises: [
          PlanExercise(
            exercise: squat,
            sets: [
              ExerciseSet(weight: '100', reps: '5'),
              ExerciseSet(weight: '100', reps: '5'),
            ],
          ),
        ],
      ),
    );
  });

  tearDownAll(() async {
    ServiceLocator.debugSetUserScopedRepositories();
    ServiceLocator.debugSetFeed();
    ServiceLocator.currentUser.value = null;
    await db.close();
    await dir.delete(recursive: true);
  });

  testWidgets(
    'login → start workout → complete a set → finish → history → details menu',
    (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final router = buildRouter(resolveUser: () async => null);
      await tester.pumpWidget(
        MaterialApp.router(
          title: 'Stronger',
          theme: AppTheme.dark,
          routerConfig: router,
        ),
      );

      // ── Logowanie ────────────────────────────────────────────────────────
      await _pumpUntilFound(tester, find.text('Utwórz konto'));
      await tester.tap(find.text('Zaloguj się'));
      await _pumpUntilFound(tester, find.text('Witaj z powrotem'));

      await tester.enterText(
        find.widgetWithText(TextFormField, 'E-mail'),
        _user.email,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Hasło'),
        'Tajne1haslo',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Zaloguj się').last);

      await _pumpUntilFound(
        tester,
        find.byKey(const ValueKey('start-workout-button')),
      );
      expect(loginRequests, hasLength(1));
      expect(ServiceLocator.currentUser.value?.id, _user.id);
      expect(router.routeInformationProvider.value.uri.path, '/app/training');
      expect(find.text('Nogi integracja'), findsWidgets);

      // ── Trening ──────────────────────────────────────────────────────────
      await tester.tap(find.byKey(const ValueKey('start-workout-button')));
      await _pumpUntilFound(
        tester,
        find.byKey(const Key('finish-workout-button')),
      );
      expect(find.text('Przysiad ze sztangą'), findsWidgets);

      await tester.tap(find.byType(Checkbox).first);
      await _pumpFrames(tester);
      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox).first);
      expect(checkbox.value, isTrue);

      await tester.tap(find.byKey(const Key('finish-workout-button')));
      await _pumpUntilFound(tester, find.text('Zakończyć trening?'));
      await tester.tap(find.widgetWithText(TextButton, 'Zakończ'));

      await _pumpUntilFound(tester, find.text('Trening ukończony!'));
      await tester.tap(
        find.byKey(const ValueKey('workout-summary-done-button')),
      );
      await _pumpUntilGone(tester, find.text('Trening ukończony!'));

      final saved = await tester.runAsync(
        () => TrainingSessionLocalHistory(
          db,
        ).finishedSessions(includeSynced: true),
      );
      expect(saved, hasLength(1));
      expect(saved!.single.planName, 'Nogi integracja');
      expect(
        saved.single.exercises.single.sets.where((s) => s.completed),
        hasLength(1),
      );

      // ── Historia ─────────────────────────────────────────────────────────
      router.go('/app/history');
      await _pumpUntilFound(tester, find.text('Nogi integracja'));
      await tester.tap(find.text('Nogi integracja').first);

      await _pumpUntilFound(
        tester,
        find.byKey(const ValueKey('session-details-more-button')),
      );
      expect(find.byType(TrainingSessionDetailsScreen), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('session-details-more-button')),
      );
      await _pumpUntilFound(
        tester,
        find.byKey(const ValueKey('session-menu-edit')),
      );
      expect(find.byKey(const ValueKey('session-menu-repeat')), findsOneWidget);
      expect(find.byKey(const ValueKey('session-menu-delete')), findsOneWidget);
    },
  );
}

/// Ekrany mają trwające animacje (zegar treningu), więc `pumpAndSettle`
/// by nie skończył — pompujemy klatki, aż element się pojawi.
Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for $finder');
}

Future<void> _pumpUntilGone(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isEmpty) return;
  }
  throw TestFailure('Timed out waiting for $finder to disappear');
}

Future<void> _pumpFrames(WidgetTester tester, {int count = 5}) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

class _MemoryTokenStorage extends Fake implements TokenStorage {
  String? token;
  AuthUser? user;

  @override
  Future<String?> readToken() async => token;

  @override
  Future<void> saveToken(String value) async => token = value;

  @override
  Future<AuthUser?> readUser() async => user;

  @override
  Future<void> saveUser(AuthUser value) async => user = value;

  @override
  Future<void> clear() async {
    token = null;
    user = null;
  }
}

class _NoopRestTimerScheduler implements RestTimerScheduler {
  @override
  Future<void> cancelRestFinished() async {}

  @override
  Future<void> scheduleRestFinished({required Duration duration}) async {}

  @override
  Future<void> warmUp() async {}
}

class _EmptyProfileRepository extends Fake implements ProfileRepository {}

class _NoFeedCache implements FeedCache {
  @override
  Future<FeedPage?> read(String userId) async => null;

  @override
  Future<void> write(String userId, FeedPage page) async {}
}

class _EmptyFeedRepository extends Fake implements FeedRepository {
  @override
  Future<FeedPage> getFeed({String? cursor, int limit = 20}) async =>
      const FeedPage(items: []);

  @override
  Future<List<FollowingUser>> getSuggestedUsers({int limit = 10}) async =>
      const [];
}
