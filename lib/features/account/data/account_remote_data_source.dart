import '../../../core/network/api_client.dart';
import '../../auth/domain/models/auth_models.dart';

class AccountRemoteDataSource {
  const AccountRemoteDataSource(this._client);

  final ApiClient _client;

  /// `POST /auth/change-password` → `{ token, user }`.
  Future<AuthResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final data = await _client.post('/auth/change-password', {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    }, auth: true);
    return AuthResult.fromJson(data as Map<String, dynamic>);
  }

  /// `POST /auth/logout-all` → `{ token, user }`.
  Future<AuthResult> logoutAll() async {
    final data = await _client.post('/auth/logout-all', const {}, auth: true);
    return AuthResult.fromJson(data as Map<String, dynamic>);
  }

  /// `POST /auth/delete-account` z `{ password }` → `204`. Alias
  /// `DELETE /auth/me` — POST, bo treść DELETE bywa gubiona przez proxy.
  Future<void> deleteAccount({required String password}) async {
    await _client.post('/auth/delete-account', {
      'password': password,
    }, auth: true);
  }
}
