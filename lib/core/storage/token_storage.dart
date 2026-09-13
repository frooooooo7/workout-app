import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/auth/domain/models/auth_models.dart';

class TokenStorage {
  TokenStorage();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';

  String? _tokenCache;
  bool _tokenLoaded = false;
  AuthUser? _userCache;
  bool _userLoaded = false;

  /// Rosną przy każdym zapisie/usunięciu — odczyt z magazynu, który skończył
  /// się już po takiej zmianie (np. wylogowanie w trakcie pierwszego
  /// odczytu), nie nadpisuje nowszej wartości w pamięci.
  int _tokenGeneration = 0;
  int _userGeneration = 0;

  // ---- Token ----

  Future<void> saveToken(String token) async {
    _tokenGeneration++;
    _tokenCache = token;
    _tokenLoaded = true;
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> readToken() async {
    if (_tokenLoaded) return _tokenCache;
    final generation = _tokenGeneration;
    final token = await _storage.read(key: _tokenKey);
    if (generation != _tokenGeneration) return _tokenCache;
    _tokenCache = token;
    _tokenLoaded = true;
    return token;
  }

  Future<void> deleteToken() async {
    _tokenGeneration++;
    _tokenCache = null;
    _tokenLoaded = true;
    await _storage.delete(key: _tokenKey);
  }

  // ---- User cache (offline-first startup) ----

  Future<void> saveUser(AuthUser user) async {
    _userGeneration++;
    _userCache = user;
    _userLoaded = true;
    await _storage.write(
      key: _userKey,
      value: jsonEncode({
        'id': user.id,
        'email': user.email,
        'firstName': user.firstName,
        'lastName': user.lastName,
      }),
    );
  }

  Future<AuthUser?> readUser() async {
    if (_userLoaded) return _userCache;
    final generation = _userGeneration;
    final raw = await _storage.read(key: _userKey);
    if (generation != _userGeneration) return _userCache;
    AuthUser? user;
    if (raw != null) {
      try {
        user = AuthUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        user = null;
      }
    }
    _userCache = user;
    _userLoaded = true;
    return user;
  }

  Future<void> deleteUser() async {
    _userGeneration++;
    _userCache = null;
    _userLoaded = true;
    await _storage.delete(key: _userKey);
  }

  // ---- Full clear (logout) ----

  Future<void> clear() async {
    _tokenGeneration++;
    _userGeneration++;
    _tokenCache = null;
    _tokenLoaded = true;
    _userCache = null;
    _userLoaded = true;
    await Future.wait([
      _storage.delete(key: _tokenKey),
      _storage.delete(key: _userKey),
    ]);
  }
}
