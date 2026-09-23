import 'dart:async';

import 'package:flutter/foundation.dart';

import '../constants/api_constants.dart';
import '../network/api_client.dart';
import '../session/session_manager.dart';
import '../storage/token_storage.dart';
import '../sync/network_availability.dart';
import '../sync/sync_coordinator.dart';
import '../sync/sync_status.dart';
import '../../features/account/data/account_remote_data_source.dart';
import '../../features/account/data/api_account_repository.dart';
import '../../features/account/data/local_account_data_cleaner.dart';
import '../../features/account/domain/repositories/account_repository.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/domain/models/auth_models.dart';
import '../../features/library/data/exercise_database.dart';
import '../../features/library/data/exercise_remote_data_source.dart';
import '../../features/library/data/offline_first_exercise_repository.dart';
import '../../features/library/data/sync/exercise_sync_engine.dart';
import '../../features/library/domain/repositories/exercise_repository.dart';
import '../../features/feed/data/api_feed_repository.dart';
import '../../features/feed/data/shared_preferences_feed_cache.dart';
import '../../features/feed/domain/repositories/feed_repository.dart';
import '../../features/feed/domain/services/feed_post_events.dart';
import '../../features/training/data/local_training_stats_repository.dart';
import '../../features/training/data/offline_first_training_plan_repository.dart';
import '../../features/training/data/offline_first_training_history_repository.dart';
import '../../features/training/data/offline_first_training_session_repository.dart';
import '../../features/training/data/rest_timer_notification_scheduler.dart';
import '../../features/training/data/settings_aware_rest_timer_scheduler.dart';
import '../../features/training/data/shared_preferences_rest_timer_notification_settings.dart';
import '../../features/training/data/sync/training_plan_sync_engine.dart';
import '../../features/training/data/sync/training_session_sync_engine.dart';
import '../../features/training/data/training_history_local_cache.dart';
import '../../features/training/data/training_history_remote_data_source.dart';
import '../../features/training/data/training_plan_remote_data_source.dart';
import '../../features/training/data/training_session_local_history.dart';
import '../../features/training/data/training_session_remote_data_source.dart';
import '../../features/training/domain/repositories/training_history_repository.dart';
import '../../features/training/domain/repositories/training_plan_repository.dart';
import '../../features/training/domain/repositories/training_session_repository.dart';
import '../../features/training/domain/repositories/training_stats_repository.dart';
import '../../features/training/domain/services/rest_timer_notification_settings.dart';
import '../../features/training/domain/services/rest_timer_scheduler.dart';
import '../../features/profile/data/api_profile_repository.dart';
import '../../features/profile/domain/repositories/profile_repository.dart';

class ServiceLocator {
  ServiceLocator._();

  static late final TokenStorage tokenStorage;
  static late final ApiClient apiClient;
  static late final AuthRepository authRepository;
  static late final ExerciseRemoteDataSource _remoteDataSource;
  static late final TrainingPlanRemoteDataSource _trainingPlanRemoteDataSource;
  static late final TrainingHistoryRemoteDataSource
  _trainingHistoryRemoteDataSource;
  static late final TrainingSessionRemoteDataSource
  _trainingSessionRemoteDataSource;
  static late final RestTimerScheduler restTimerScheduler;
  static late final RestTimerNotificationSettings restTimerNotificationSettings;

  /// Wymuszone wylogowanie (unieważniony token), odświeżenie tokenu,
  /// sprzątanie po usunięciu konta.
  static late final SessionManager sessionManager;

  /// Komunikat na ekranie logowania (wylogowanie wymuszone, usunięte konto).
  static final loginNotice = ValueNotifier<String?>(null);
  static late final AccountRepository accountRepository;

  // User-scoped repository: recreated on login/logout via [currentUser] listener.
  static ExerciseRepository? _exerciseRepository;
  static ExerciseDatabase? _exerciseDatabase;
  static ExerciseSyncEngine? _exerciseSyncEngine;
  static TrainingPlanRepository? _trainingPlanRepository;
  static TrainingHistoryRepository? _trainingHistoryRepository;
  static TrainingPlanSyncEngine? _trainingPlanSyncEngine;
  static TrainingSessionRepository? _trainingSessionRepository;
  static TrainingSessionSyncEngine? _trainingSessionSyncEngine;
  static SyncCoordinator? _syncCoordinator;
  static TrainingStatsRepository? _trainingStatsRepository;
  static TrainingSessionLocalHistory? _localSessionHistory;

  // Feed społecznościowy — oparty o API, nie zależy od bazy per-user.
  static FeedRepository? _feedRepository;
  static FeedCache _feedCache = const SharedPreferencesFeedCache();

  /// Zmiany postów (kudosy, liczba komentarzy) przenoszone między ekranami.
  static final feedPostEvents = FeedPostEvents();
  static final _feedRefreshTick = ValueNotifier<int>(0);
  static late final ProfileRepository profileRepository;
  static ApiProfileRepository? _apiProfileRepository;
  static final profileRefreshTick = ValueNotifier(0);

  /// Serialized dispose/setup so DB close never races a new user open.
  static Future<void>? _exerciseScopeFuture;

  /// Konto, dla którego istnieje (albo właśnie powstaje) scope bazy.
  static String? _scopeUserId;

  static final _syncStatus = ValueNotifier<SyncStatus>(const SyncStatus());
  static final _exerciseDataChanges = ValueNotifier<int>(0);
  static final _trainingPlanDataChanges = ValueNotifier<int>(0);
  static final _trainingSessionDataChanges = ValueNotifier<int>(0);

  /// Stan synchronizacji dla wskaźnika w nagłówkach. Przeżywa zmianę konta.
  static ValueListenable<SyncStatus> get syncStatus => _syncStatus;

  /// Sygnały „synchronizacja zmieniła dane lokalne” — ekrany odświeżają się
  /// z bazy, zamiast czekać na ponowne wejście.
  static Listenable get exerciseDataChanges => _exerciseDataChanges;
  static Listenable get trainingPlanDataChanges => _trainingPlanDataChanges;

  /// Tylko zakończone lub anulowane sesje — zapis w trakcie treningu nie
  /// odświeża historii co serię.
  static Listenable get trainingSessionDataChanges =>
      _trainingSessionDataChanges;

  static ExerciseRepository get exerciseRepository {
    assert(
      _exerciseRepository != null,
      'exerciseRepository is not initialized. '
      'It is set automatically when currentUser changes to a non-null value. '
      'Ensure the user is logged in before accessing the library.',
    );
    return _exerciseRepository!;
  }

  static TrainingPlanRepository get trainingPlanRepository {
    assert(
      _trainingPlanRepository != null,
      'trainingPlanRepository is not initialized. Ensure the user is logged in.',
    );
    return _trainingPlanRepository!;
  }

  static TrainingHistoryRepository get trainingHistoryRepository {
    assert(
      _trainingHistoryRepository != null,
      'trainingHistoryRepository is not initialized. Ensure the user is logged in.',
    );
    return _trainingHistoryRepository!;
  }

  static TrainingStatsRepository get trainingStatsRepository {
    assert(
      _trainingStatsRepository != null,
      'trainingStatsRepository is not initialized. Ensure the user is logged in.',
    );
    return _trainingStatsRepository!;
  }

  static FeedRepository get feedRepository {
    assert(
      _feedRepository != null,
      'feedRepository is not initialized. Call ServiceLocator.init() first.',
    );
    return _feedRepository!;
  }

  static FeedCache get feedCache => _feedCache;

  /// Prośba o odświeżenie feedu: udostępniony trening, zmiana obserwowania.
  static Listenable get feedRefreshSignal => _feedRefreshTick;

  static TrainingSessionRepository get trainingSessionRepository {
    assert(
      _trainingSessionRepository != null,
      'trainingSessionRepository is not initialized. Ensure the user is logged in.',
    );
    return _trainingSessionRepository!;
  }

  /// Holds the currently authenticated user. Survives tab switches.
  static final currentUser = ValueNotifier<AuthUser?>(null);

  static void init() {
    tokenStorage = TokenStorage();
    apiClient = ApiClient(
      baseUrl: kApiBaseUrl,
      getToken: tokenStorage.readToken,
      onUnauthorized: (error, tokenUsed) => unawaited(
        sessionManager.handleUnauthorized(error, tokenUsed: tokenUsed),
      ),
    );
    sessionManager = SessionManager(
      tokenStorage: tokenStorage,
      currentUser: currentUser,
      closeUserScope: _closeUserScope,
      wipeUserData: LocalAccountDataCleaner(
        ownImageUrls: (userId) =>
            _apiProfileRepository?.ownAvatarUrlsFor(userId) ?? const {},
      ).wipe,
      loginNotice: loginNotice,
    );
    accountRepository = ApiAccountRepository(
      remote: AccountRemoteDataSource(apiClient),
      session: sessionManager,
    );
    authRepository = AuthRepository(apiClient);
    _remoteDataSource = ExerciseRemoteDataSource(apiClient);
    _trainingPlanRemoteDataSource = TrainingPlanRemoteDataSource(apiClient);
    _trainingHistoryRemoteDataSource = TrainingHistoryRemoteDataSource(
      apiClient,
    );
    _trainingSessionRemoteDataSource = TrainingSessionRemoteDataSource(
      apiClient,
    );
    final apiProfileRepository = ApiProfileRepository(apiClient);
    _apiProfileRepository = apiProfileRepository;
    profileRepository = apiProfileRepository;
    _feedRepository = ApiFeedRepository(apiClient);
    restTimerNotificationSettings =
        const SharedPreferencesRestTimerNotificationSettings();
    restTimerScheduler = SettingsAwareRestTimerScheduler(
      inner: RestTimerNotificationScheduler(),
      settings: restTimerNotificationSettings,
    );

    currentUser.addListener(_onUserChanged);
  }

  /// Test seam: podmienia user-scoped repozytoria bez otwierania bazy.
  @visibleForTesting
  static void debugSetUserScopedRepositories({
    ExerciseRepository? exerciseRepository,
    TrainingPlanRepository? trainingPlanRepository,
    TrainingHistoryRepository? trainingHistoryRepository,
    TrainingSessionRepository? trainingSessionRepository,
    TrainingStatsRepository? trainingStatsRepository,
  }) {
    _exerciseRepository = exerciseRepository;
    _trainingPlanRepository = trainingPlanRepository;
    _trainingHistoryRepository = trainingHistoryRepository;
    _trainingSessionRepository = trainingSessionRepository;
    _trainingStatsRepository = trainingStatsRepository;
  }

  /// Test seam: repozytorium feedu (i cache) bez `init()`.
  @visibleForTesting
  static void debugSetFeed({FeedRepository? repository, FeedCache? cache}) {
    _feedRepository = repository;
    _feedCache = cache ?? const SharedPreferencesFeedCache();
  }

  static void _onUserChanged() {
    final requestedUserId = currentUser.value?.id;
    // Odświeżone dane tego samego konta (np. `/auth/me` w tle zwraca nową
    // instancję AuthUser) nie mogą zamykać bazy: ekrany trzymają już
    // repozytoria z bieżącego scope'u, a ich synchronizacja by stanęła.
    if (requestedUserId == _scopeUserId) return;
    _scopeUserId = requestedUserId;

    _exerciseScopeFuture = (_exerciseScopeFuture ?? Future<void>.value()).then((
      _,
    ) async {
      // W międzyczasie konto zmieniło się jeszcze raz — obsłuży to nowsze
      // wywołanie.
      if (requestedUserId != _scopeUserId) return;
      await _disposeExerciseScoped();
      if (requestedUserId != null) {
        _setupExerciseScoped(requestedUserId);
      }
    });
  }

  /// Wylogowanie z czekaniem, aż baza konta zostanie zamknięta (np. przed
  /// usunięciem pliku bazy).
  static Future<void> _closeUserScope() async {
    currentUser.value = null;
    await (_exerciseScopeFuture ?? Future<void>.value());
  }

  static Future<void> _disposeExerciseScoped() async {
    _syncCoordinator?.stop();
    _syncCoordinator = null;
    _exerciseSyncEngine?.stop();
    _trainingPlanSyncEngine?.stop();
    _trainingSessionSyncEngine?.stop();
    _trainingSessionSyncEngine = null;
    _trainingSessionRepository = null;
    _trainingPlanSyncEngine = null;
    _trainingPlanRepository = null;
    _trainingHistoryRepository = null;
    _trainingStatsRepository = null;
    _localSessionHistory = null;
    _exerciseSyncEngine = null;
    _exerciseRepository = null;
    await _exerciseDatabase?.close();
    _exerciseDatabase = null;
    _syncStatus.value = const SyncStatus();
  }

  static void _setupExerciseScoped(String userId) {
    final database = ExerciseDatabase(
      LocalAccountDataCleaner.databaseFileName(userId),
    );
    _exerciseDatabase = database;

    final exerciseSync = ExerciseSyncEngine(
      remote: _remoteDataSource,
      localDb: database,
      onDataChanged: () => _exerciseDataChanges.value++,
    );
    final planSync = TrainingPlanSyncEngine(
      remote: _trainingPlanRemoteDataSource,
      localDb: database,
      onDataChanged: () => _trainingPlanDataChanges.value++,
    );
    final sessionSync = TrainingSessionSyncEngine(
      remote: _trainingSessionRemoteDataSource,
      localDb: database,
      onDataChanged: () => _trainingSessionDataChanges.value++,
    );
    _exerciseSyncEngine = exerciseSync;
    _trainingPlanSyncEngine = planSync;
    _trainingSessionSyncEngine = sessionSync;

    _exerciseRepository = OfflineFirstExerciseRepository(
      localDb: database,
      syncEngine: exerciseSync,
    );
    _trainingPlanRepository = OfflineFirstTrainingPlanRepository(
      localDb: database,
      syncEngine: planSync,
    );
    final localSessions = TrainingSessionLocalHistory(database);
    _localSessionHistory = localSessions;
    _trainingStatsRepository = LocalTrainingStatsRepository(
      localSessions,
      // Statystyki liczą się z lokalnej bazy — dociągamy treningi z innych
      // urządzeń najwyżej raz na 30 s; wynik przychodzi sygnałem zmiany.
      onRead: () {
        if (sessionSync.isStopped) return;
        unawaited(sessionSync.pullIfDue().catchError((Object _) {}));
      },
    );
    _trainingHistoryRepository = OfflineFirstTrainingHistoryRepository(
      remote: _trainingHistoryRemoteDataSource,
      localCache: TrainingHistoryLocalCache(database),
      localSessions: localSessions,
      // Świeże dane pobrane w tle (inne niż cache) — ekrany historii
      // czytają listę jeszcze raz.
      onFreshData: () => _trainingSessionDataChanges.value++,
    );
    _trainingSessionRepository = OfflineFirstTrainingSessionRepository(
      localDb: database,
      syncEngine: sessionSync,
      remote: _trainingSessionRemoteDataSource,
    );

    // Zastępuje osobne „bootstrapy” silników: pełny cykl w kolejności
    // ćwiczenia → plany → sesje, sync po powrocie sieci i aplikacji,
    // a ponawianie jako zabezpieczenie.
    _syncCoordinator = SyncCoordinator(
      localDb: database,
      exercises: exerciseSync,
      plans: planSync,
      sessions: sessionSync,
      status: _syncStatus,
      networkAvailability: networkAvailabilityChanges(),
    )..start();

    unawaited(restTimerScheduler.warmUp());
  }

  /// Sesje zmienione z ekranu (usunięcie, edycja) — historia, statystyki
  /// i szczegóły czytają dane jeszcze raz, bez czekania na synchronizację.
  static void notifyTrainingSessionsChanged() {
    _trainingSessionDataChanges.value++;
  }

  /// Id (lokalne i serwerowe) treningów usuniętych na tym urządzeniu, których
  /// usunięcie nie dotarło jeszcze na serwer. Feed i aktywności profilu je
  /// ukrywają (id posta = id sesji na serwerze).
  static Future<Set<String>> pendingDeletedSessionIds() async {
    final history = _localSessionHistory;
    if (history == null) return const {};
    try {
      return await history.pendingDeletionIds();
    } catch (_) {
      return const {};
    }
  }

  static void requestProfileRefresh() {
    profileRefreshTick.value++;
  }

  static void requestFeedRefresh() {
    _feedRefreshTick.value++;
  }

  /// Nowe imię/nazwisko zalogowanego konta (po edycji profilu): zapis
  /// w pamięci sesji i w secure storage, bez ponownego logowania. Id się nie
  /// zmienia, więc [_onUserChanged] nie zamyka ani nie otwiera bazy.
  static Future<void> updateCurrentUserNames({
    required String userId,
    required String firstName,
    required String lastName,
  }) async {
    final current = currentUser.value;
    if (current == null || current.id != userId) return;
    if (current.firstName == firstName && current.lastName == lastName) {
      return;
    }
    final updated = current.copyWith(firstName: firstName, lastName: lastName);
    currentUser.value = updated;
    await tokenStorage.saveUser(updated);
  }

  /// Konto, które w tej sesji aplikacji odłożyło onboarding na później
  /// (np. brak sieci) — router nie kieruje go już na `/onboarding`.
  static String? _onboardingDeferredForUserId;

  static bool isOnboardingDeferred(String userId) =>
      _onboardingDeferredForUserId == userId;

  static void deferOnboarding(String userId) {
    _onboardingDeferredForUserId = userId;
  }

  /// Onboarding zakończony na serwerze — zapis flagi w sesji i w cache.
  static Future<void> markOnboardingCompleted(String userId) async {
    final current = currentUser.value;
    if (current == null || current.id != userId) return;
    if (current.onboardingCompleted) return;
    final updated = current.copyWith(onboardingCompleted: true);
    currentUser.value = updated;
    await tokenStorage.saveUser(updated);
  }

  /// Pełna synchronizacja od razu (np. „Synchronizuj teraz” we wskaźniku).
  /// [retryRejected] ponawia także zmiany wcześniej odrzucone przez serwer.
  static Future<void> requestSync({bool retryRejected = false}) async {
    await _syncCoordinator?.syncNow(
      retryRejected: retryRejected,
      resetBackoff: true,
    );
  }

  /// Niewysłane i odrzucone zmiany bieżącego konta.
  static Future<int> countUnsyncedChanges() async {
    final coordinator = _syncCoordinator;
    if (coordinator == null) return 0;
    return coordinator.countUnsyncedChanges();
  }

  static Future<void> flushTrainingSessionSync() async {
    final engine = _trainingSessionSyncEngine;
    if (engine == null || engine.isStopped) return;
    try {
      await engine.flush();
    } catch (_) {
      /* sync is best-effort; profile refresh still runs afterward */
    }
  }
}
