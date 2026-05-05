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

class ServiceLocator {
  ServiceLocator._();

  static late final TokenStorage tokenStorage;
  static late final ApiClient apiClient;
  static late final AuthRepository authRepository;
  static late final ExerciseRemoteDataSource _remoteDataSource;

  // User-scoped repository: recreated on login/logout via [currentUser] listener.
  static ExerciseRepository? _exerciseRepository;
  static ExerciseDatabase? _exerciseDatabase;
  static ExerciseSyncEngine? _exerciseSyncEngine;

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

    currentUser.addListener(_onUserChanged);
  }

  static void _onUserChanged() {
    _exerciseScopeFuture =
        (_exerciseScopeFuture ?? Future<void>.value()).then((_) async {
      await _disposeExerciseScoped();
      final still = currentUser.value;
      if (still != null) {
        _setupExerciseScoped(still.id);
      }
    });
  }

  static Future<void> _disposeExerciseScoped() async {
    _exerciseSyncEngine?.stop();
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
    _exerciseSyncEngine!.scheduleBootstrap();
  }
}
