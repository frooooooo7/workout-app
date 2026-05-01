import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/auth/domain/models/auth_models.dart';

class TokenStorage {
  const TokenStorage();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';

  // ---- Token ----

  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<void> deleteToken() => _storage.delete(key: _tokenKey);

  // ---- User cache (offline-first startup) ----

  Future<void> saveUser(AuthUser user) => _storage.write(
        key: _userKey,
        value: jsonEncode({
          'id': user.id,
          'email': user.email,
          'firstName': user.firstName,
          'lastName': user.lastName,
        }),
      );

  Future<AuthUser?> readUser() async {
    final raw = await _storage.read(key: _userKey);
    if (raw == null) return null;
    try {
      return AuthUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteUser() => _storage.delete(key: _userKey);

  // ---- Full clear (logout) ----

  Future<void> clear() async {
    await Future.wait([deleteToken(), deleteUser()]);
  }
}
