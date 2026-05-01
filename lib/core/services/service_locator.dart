import '../constants/api_constants.dart';
import '../network/api_client.dart';
import '../storage/token_storage.dart';
import '../../features/auth/data/auth_repository.dart';

class ServiceLocator {
  ServiceLocator._();

  static late final TokenStorage tokenStorage;
  static late final ApiClient apiClient;
  static late final AuthRepository authRepository;

  static void init() {
    tokenStorage = const TokenStorage();
    apiClient = ApiClient(
      baseUrl: kApiBaseUrl,
      getToken: tokenStorage.readToken,
    );
    authRepository = AuthRepository(apiClient);
  }
}
