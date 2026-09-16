import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/constants/api_constants.dart';
import 'package:gym/core/network/api_client.dart';
import 'package:gym/core/storage/token_storage.dart';
import 'package:gym/features/auth/domain/models/auth_models.dart';

/// Origin backendu dla testów kontraktowych, np. `http://localhost:3102`.
///
/// `flutter test test/e2e --dart-define=E2E_BASE_URL=http://localhost:3102`
/// albo zmienna środowiskowa `E2E_BASE_URL`. Bez niej testy są pomijane.
String? get e2eOrigin {
  const defined = String.fromEnvironment('E2E_BASE_URL');
  if (defined.isNotEmpty) return defined;
  final fromEnv = Platform.environment['E2E_BASE_URL'];
  return fromEnv == null || fromEnv.isEmpty ? null : fromEnv;
}

/// Wartość `skip:` dla grup E2E.
Object get e2eSkip => e2eOrigin == null
    ? 'E2E_BASE_URL not set — run against a local gym_backend, see README'
    : false;

/// Token trzymany w pamięci — prawdziwy [ApiClient] czyta go przy każdym
/// żądaniu, tak jak z secure storage w aplikacji.
class MemoryTokenStorage extends Fake implements TokenStorage {
  MemoryTokenStorage({this.token, this.user});

  String? token;
  AuthUser? user;

  @override
  Future<String?> readToken() async => token;

  @override
  Future<void> saveToken(String value) async => token = value;

  @override
  Future<AuthUser?> readUser() async => user;

  @override
  Future<void> saveUser(AuthUser value) async => user = value;

  @override
  Future<void> clear() async {
    token = null;
    user = null;
  }
}

/// Prawdziwy [ApiClient] na `<origin>/api/v1`, jak w `ServiceLocator.init`.
ApiClient e2eApiClient(
  MemoryTokenStorage storage, {
  UnauthorizedCallback? onUnauthorized,
}) {
  return ApiClient(
    baseUrl: apiBaseUrlFor(e2eOrigin!),
    getToken: storage.readToken,
    onUnauthorized: onUnauthorized,
  );
}

/// Klient z zamrożonym tokenem (np. starym, po zmianie hasła).
ApiClient e2eApiClientWithToken(String token) {
  return ApiClient(
    baseUrl: apiBaseUrlFor(e2eOrigin!),
    getToken: () async => token,
  );
}

/// Unikalny sufiks per uruchomienie — testy można powtarzać na tej samej bazie.
final String e2eRunId =
    '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}'
    '${(DateTime.now().microsecond % 1000).toRadixString(36)}';

Matcher isApiError(String code, {int? status}) {
  return isA<ApiException>()
      .having((e) => e.message, 'message', code)
      .having((e) => e.statusCode, 'statusCode', status ?? anything);
}

const e2ePassword = 'E2eStrong1pass';
