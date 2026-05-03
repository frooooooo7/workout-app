import 'package:flutter/foundation.dart';

import '../constants/api_constants.dart';
import '../network/api_client.dart';
import '../storage/token_storage.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/domain/models/auth_models.dart';
import '../../features/library/data/cached_exercise_repository.dart';
import '../../features/library/data/exercise_database.dart';
import '../../features/library/data/exercise_remote_data_source.dart';
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

    // Automatically create/destroy the per-user exercise repository whenever
    // the authenticated user changes (login, logout, token refresh).
    currentUser.addListener(_onUserChanged);
  }

  static void _onUserChanged() {
    final user = currentUser.value;
    if (user != null) {
      _initExerciseRepository(user.id);
    } else {
      _clearExerciseRepository();
    }
  }

  /// Creates a new user-scoped [ExerciseRepository] backed by a SQLite DB file
  /// named after [userId]. Closes the previous DB connection if it exists.
  static void _initExerciseRepository(String userId) {
    // Close the previous connection (fire-and-forget; sqflite handles it).
    _exerciseDatabase?.close().ignore();

    _exerciseDatabase = ExerciseDatabase('gym_library_$userId.db');
    _exerciseRepository = CachedExerciseRepository(
      remote: _remoteDataSource,
      localDb: _exerciseDatabase!,
    );
  }

  static void _clearExerciseRepository() {
    _exerciseDatabase?.close().ignore();
    _exerciseDatabase = null;
    _exerciseRepository = null;
  }
}
