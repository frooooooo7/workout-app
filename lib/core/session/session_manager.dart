import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../features/auth/domain/models/auth_models.dart';
import '../network/api_client.dart';
import '../storage/token_storage.dart';

const kSessionExpiredNotice =
    'Sesja wygasła lub zostałeś wylogowany na innym urządzeniu. '
    'Zaloguj się ponownie.';
const kAccountDeletedNotice = 'Konto zostało usunięte.';

const _revokedSessionErrors = {'token_revoked', 'invalid_token'};

/// `401 token_revoked` (zmiana hasła, wylogowanie wszędzie, usunięte konto)
/// albo `401 invalid_token` (wygasły / zły token). Nie obejmuje
/// `invalid_credentials` z logowania ani zmiany hasła.
bool isRevokedSessionError(ApiException error) =>
    error.statusCode == 401 && _revokedSessionErrors.contains(error.message);

/// Cykl życia sesji zalogowanego użytkownika:
///
/// * wymuszone wylogowanie, gdy serwer unieważni token ([handleUnauthorized])
///   — jeden raz, niezależnie od liczby równoległych żądań z `401`,
/// * podmiana tokenu po zmianie hasła / wylogowaniu wszędzie
///   ([applyRefreshedSession]) bez przebudowy bazy per-user,
/// * sprzątanie po usunięciu konta ([completeAccountDeletion]).
///
/// Lokalna baza konta **nie** jest usuwana przy wymuszonym wylogowaniu —
/// po ponownym zalogowaniu niewysłane zmiany nadal się zsynchronizują.
class SessionManager {
  SessionManager({
    required TokenStorage tokenStorage,
    required ValueNotifier<AuthUser?> currentUser,
    required Future<void> Function() closeUserScope,
    required Future<void> Function(String userId) wipeUserData,
    ValueNotifier<String?>? loginNotice,
    this.onSessionEnded,
  }) : loginNotice = loginNotice ?? ValueNotifier<String?>(null),
       _tokenStorage = tokenStorage,
       _currentUser = currentUser,
       _closeUserScope = closeUserScope,
       _wipeUserData = wipeUserData {
    _currentUser.addListener(_onUserChanged);
  }

  final TokenStorage _tokenStorage;
  final ValueNotifier<AuthUser?> _currentUser;
  final Future<void> Function() _closeUserScope;
  final Future<void> Function(String userId) _wipeUserData;

  /// Nawigacja do logowania — ustawiana przez aplikację (router).
  VoidCallback? onSessionEnded;

  /// Komunikat na ekranie logowania po zakończeniu sesji. Czyszczony, gdy
  /// ktoś znów się zaloguje.
  final ValueNotifier<String?> loginNotice;

  int _rotations = 0;
  Completer<void>? _rotationsDone;
  Future<void>? _ending;

  String? get currentUserId => _currentUser.value?.id;

  void _onUserChanged() {
    if (_currentUser.value != null) loginNotice.value = null;
  }

  /// Operacja, po której serwer unieważnia bieżący token i zwraca nowy
  /// (albo kasuje konto). Odpowiedzi `401` na stary token, które przyjdą
  /// w trakcie, są oceniane dopiero po jej zakończeniu — wtedy token jest już
  /// nowy (lub go nie ma), więc nie wylogowują użytkownika przez pomyłkę.
  Future<T> guardTokenRotation<T>(Future<T> Function() body) async {
    _rotations++;
    try {
      return await body();
    } finally {
      _rotations--;
      if (_rotations == 0) {
        final done = _rotationsDone;
        _rotationsDone = null;
        done?.complete();
      }
    }
  }

  /// Podpinane pod [ApiClient.onUnauthorized].
  Future<void> handleUnauthorized(
    ApiException error, {
    required String tokenUsed,
  }) async {
    if (!isRevokedSessionError(error)) return;
    while (_rotations > 0) {
      await (_rotationsDone ??= Completer<void>()).future;
    }
    if (_ending != null) return;

    final String? current;
    try {
      current = await _tokenStorage.readToken();
    } catch (_) {
      return;
    }
    // Brak tokenu — już wylogowano. Inny token — odpowiedź dotyczy sesji,
    // która została zastąpiona (np. po zmianie hasła albo ponownym logowaniu).
    if (current == null || current != tokenUsed) return;
    if (_ending != null || _rotations > 0) return;
    await forceLogout();
  }

  /// Wylogowanie bez udziału użytkownika: token i cache użytkownika znikają,
  /// `currentUser = null` (zamyka bazę i zatrzymuje synchronizację), a ekran
  /// logowania pokazuje [notice].
  Future<void> forceLogout({String notice = kSessionExpiredNotice}) {
    return _ending ??= _endSession(notice).whenComplete(() => _ending = null);
  }

  Future<void> _endSession(String notice) async {
    try {
      await _tokenStorage.clear();
    } catch (_) {
      /* pamięć podręczna tokenu jest już wyczyszczona */
    }
    loginNotice.value = notice;
    onSessionEnded?.call();
    _currentUser.value = null;
    try {
      await _closeUserScope();
    } catch (_) {
      /* baza i tak zostanie zamknięta przy następnej zmianie konta */
    }
  }

  /// Nowy token po zmianie hasła lub wylogowaniu ze wszystkich urządzeń.
  /// Id użytkownika się nie zmienia, więc baza per-user zostaje otwarta.
  Future<void> applyRefreshedSession(AuthResult result) async {
    await _tokenStorage.saveToken(result.token);
    await _tokenStorage.saveUser(result.user);
    _currentUser.value = result.user;
  }

  /// Po `204` z `DELETE /auth/me`: koniec sesji, potem usunięcie lokalnych
  /// danych konta (baza zamknięta wcześniej, żeby dało się skasować plik).
  Future<void> completeAccountDeletion(String userId) async {
    final pending = _ending;
    if (pending != null) await pending;
    await forceLogout(notice: kAccountDeletedNotice);
    try {
      await _wipeUserData(userId);
    } catch (_) {
      /* sprzątanie jest best-effort — konto na serwerze już nie istnieje */
    }
  }

  @visibleForTesting
  void dispose() {
    _currentUser.removeListener(_onUserChanged);
  }
}
