import 'package:flutter/foundation.dart';
import '../constants/api_constants.dart';
import '../network/api_client.dart';
import '../storage/token_storage.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/domain/models/auth_models.dart';
import '../../features/library/data/exercise_database.dart';
import '../../features/library/data/sqflite_exercise_repository.dart';
import '../../features/library/domain/models/exercise.dart';
import '../../features/library/domain/repositories/exercise_repository.dart';

class ServiceLocator {
  ServiceLocator._();

  static late final TokenStorage tokenStorage;
  static late final ApiClient apiClient;
  static late final AuthRepository authRepository;
  static late final ExerciseRepository exerciseRepository;

  /// Holds the currently authenticated user. Survives tab switches.
  static final currentUser = ValueNotifier<AuthUser?>(null);

  static void init() {
    tokenStorage = const TokenStorage();
    apiClient = ApiClient(
      baseUrl: kApiBaseUrl,
      getToken: tokenStorage.readToken,
    );
    authRepository = AuthRepository(apiClient);
    exerciseRepository =
        SqfliteExerciseRepository(ExerciseDatabase.instance);
  }

  /// Seeds built-in exercises into the local DB on first run.
  /// Call once after [init], before showing any library UI.
  static Future<void> seedLibrary() async {
    await exerciseRepository.seedIfEmpty(mockExercises);
  }
}
