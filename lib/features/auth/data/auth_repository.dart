import '../../../core/network/api_client.dart';
import '../domain/models/auth_models.dart';

class AuthRepository {
  const AuthRepository(this._client);

  final ApiClient _client;

  Future<AuthResult> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    final data = await _client.post('/auth/register', {
      'email': email,
      'password': password,
      'firstName': firstName,
      'lastName': lastName,
    });
    return AuthResult.fromJson(data as Map<String, dynamic>);
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final data = await _client.post('/auth/login', {
      'email': email,
      'password': password,
    });
    return AuthResult.fromJson(data as Map<String, dynamic>);
  }
}
