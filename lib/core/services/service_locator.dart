import 'dart:async';

import 'package:flutter/foundation.dart';

import '../constants/api_constants.dart';
import '../network/api_client.dart';
import '../storage/token_storage.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/domain/models/auth_models.dart';
import '../../features/library/data/exercise_database.dart';
import '../../features/library/data/exercise_remote_data_source.dart';
import '../../features/library/data/offline_first_exercise_repository.dart';
import '../../features/library/data/sync/exercise_sync_engine.dart';
import '../../features/library/domain/repositories/exercise_repository.dart';
import '../../features/training/data/offline_first_training_plan_repository.dart';
import '../../features/training/data/offline_first_training_history_repository.dart';
import '../../features/training/data/offline_first_training_session_repository.dart';
import '../../features/training/data/rest_timer_notification_scheduler.dart';
import '../../features/training/data/sync/training_plan_sync_engine.dart';
import '../../features/training/data/sync/training_session_sync_engine.dart';
import '../../features/training/data/training_history_local_cache.dart';
import '../../features/training/data/training_history_remote_data_source.dart';
import '../../features/training/data/training_plan_remote_data_source.dart';
import '../../features/training/data/training_session_remote_data_source.dart';
import '../../features/training/domain/repositories/training_history_repository.dart';
import '../../features/training/domain/repositories/training_plan_repository.dart';
import '../../features/training/domain/repositories/training_session_repository.dart';
import '../../features/training/domain/services/rest_timer_scheduler.dart';

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

  // User-scoped repository: recreated on login/logout via [currentUser] listener.
  static ExerciseRepository? _exerciseRepository;
  static ExerciseDatabase? _exerciseDatabase;
  static ExerciseSyncEngine? _exerciseSyncEngine;
  static TrainingPlanRepository? _trainingPlanRepository;
  static TrainingHistoryRepository? _trainingHistoryRepository;
  static TrainingPlanSyncEngine? _trainingPlanSyncEngine;
  static TrainingSessionRepository? _trainingSessionRepository;
  static TrainingSessionSyncEngine? _trainingSessionSyncEngine;

  /// Serialized dispose/setup so DB close never races a new user open.
  static Future<void>? _exerciseScopeFuture;

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
    tokenStorage = const TokenStorage();
    apiClient = ApiClient(
      baseUrl: kApiBaseUrl,
      getToken: tokenStorage.readToken,
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
    restTimerScheduler = RestTimerNotificationScheduler();

    currentUser.addListener(_onUserChanged);
  }

  static void _onUserChanged() {
    _exerciseScopeFuture = (_exerciseScopeFuture ?? Future<void>.value()).then((
      _,
    ) async {
      await _disposeExerciseScoped();
      final still = currentUser.value;
      if (still != null) {
        _setupExerciseScoped(still.id);
      }
    });
  }

  static Future<void> _disposeExerciseScoped() async {
    _exerciseSyncEngine?.stop();
    _trainingPlanSyncEngine?.stop();
    _trainingSessionSyncEngine?.stop();
    _trainingSessionSyncEngine = null;
    _trainingSessionRepository = null;
    _trainingPlanSyncEngine = null;
    _trainingPlanRepository = null;
    _trainingHistoryRepository = null;
    _exerciseSyncEngine = null;
    _exerciseRepository = null;
    await _exerciseDatabase?.close();
    _exerciseDatabase = null;
  }

  static void _setupExerciseScoped(String userId) {
    _exerciseDatabase = ExerciseDatabase('gym_library_$userId.db');
    _exerciseSyncEngine = ExerciseSyncEngine(
      remote: _remoteDataSource,
      localDb: _exerciseDatabase!,
    );
    _exerciseRepository = OfflineFirstExerciseRepository(
      localDb: _exerciseDatabase!,
      syncEngine: _exerciseSyncEngine!,
    );
    _trainingPlanSyncEngine = TrainingPlanSyncEngine(
      remote: _trainingPlanRemoteDataSource,
      localDb: _exerciseDatabase!,
    );
    _trainingPlanRepository = OfflineFirstTrainingPlanRepository(
      localDb: _exerciseDatabase!,
      syncEngine: _trainingPlanSyncEngine!,
    );
    _trainingHistoryRepository = OfflineFirstTrainingHistoryRepository(
      remote: _trainingHistoryRemoteDataSource,
      localCache: TrainingHistoryLocalCache(_exerciseDatabase!),
    );
    _trainingSessionSyncEngine = TrainingSessionSyncEngine(
      remote: _trainingSessionRemoteDataSource,
      localDb: _exerciseDatabase!,
    );
    _trainingSessionRepository = OfflineFirstTrainingSessionRepository(
      localDb: _exerciseDatabase!,
      syncEngine: _trainingSessionSyncEngine!,
    );
    _exerciseSyncEngine!.scheduleBootstrap();
    _trainingPlanSyncEngine!.scheduleBootstrap();
    _trainingSessionSyncEngine!.scheduleBootstrap();
  }
}
