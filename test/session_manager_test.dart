import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/network/api_client.dart';
import 'package:gym/core/session/session_manager.dart';
import 'package:gym/core/storage/token_storage.dart';
import 'package:gym/features/auth/domain/models/auth_models.dart';

class FakeTokenStorage extends Fake implements TokenStorage {
  FakeTokenStorage({this.token, this.user});

  String? token;
  AuthUser? user;
  int clearCalls = 0;

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
    clearCalls++;
    token = null;
    user = null;
  }
}

const _user = AuthUser(
  id: 'user-1',
  email: 'jan@example.com',
  firstName: 'Jan',
  lastName: 'Kowalski',
);

const _revoked = ApiException('token_revoked', statusCode: 401);

void main() {
  late FakeTokenStorage storage;
  late ValueNotifier<AuthUser?> currentUser;
  late SessionManager session;
  late int closeScopeCalls;
  late int sessionEndedCalls;
  late List<String> wipedUsers;

  setUp(() {
    storage = FakeTokenStorage(token: 'old-token', user: _user);
    currentUser = ValueNotifier<AuthUser?>(_user);
    closeScopeCalls = 0;
    sessionEndedCalls = 0;
    wipedUsers = [];
    session = SessionManager(
      tokenStorage: storage,
      currentUser: currentUser,
      closeUserScope: () async => closeScopeCalls++,
      wipeUserData: (userId) async => wipedUsers.add(userId),
      onSessionEnded: () => sessionEndedCalls++,
    );
  });

  tearDown(() {
    session.dispose();
    currentUser.dispose();
  });

  test('revoked token forces logout exactly once for parallel 401s', () async {
    await Future.wait([
      session.handleUnauthorized(_revoked, tokenUsed: 'old-token'),
      session.handleUnauthorized(
        const ApiException('invalid_token', statusCode: 401),
        tokenUsed: 'old-token',
      ),
      session.handleUnauthorized(_revoked, tokenUsed: 'old-token'),
    ]);
    // Spóźniona odpowiedź po wylogowaniu.
    await session.handleUnauthorized(_revoked, tokenUsed: 'old-token');

    expect(storage.clearCalls, 1);
    expect(sessionEndedCalls, 1);
    expect(closeScopeCalls, 1);
    expect(currentUser.value, isNull);
    expect(storage.token, isNull);
    expect(session.loginNotice.value, kSessionExpiredNotice);
    // Wymuszone wylogowanie nie usuwa lokalnej bazy.
    expect(wipedUsers, isEmpty);
  });

  test('ignores invalid_credentials and other 401 codes', () async {
    await session.handleUnauthorized(
      const ApiException('invalid_credentials', statusCode: 401),
      tokenUsed: 'old-token',
    );
    await session.handleUnauthorized(
      const ApiException('unauthorized', statusCode: 401),
      tokenUsed: 'old-token',
    );
    await session.handleUnauthorized(
      const ApiException('database_unavailable', statusCode: 503),
      tokenUsed: 'old-token',
    );

    expect(storage.clearCalls, 0);
    expect(currentUser.value, _user);
    expect(session.loginNotice.value, isNull);
  });

  test('ignores 401 for a token that was already replaced', () async {
    storage.token = 'new-token';

    await session.handleUnauthorized(_revoked, tokenUsed: 'old-token');

    expect(storage.clearCalls, 0);
    expect(currentUser.value, _user);
  });

  test('401 during token rotation is evaluated after the new token is saved',
      () async {
    final serverResponded = Completer<void>();
    final rotation = session.guardTokenRotation(() async {
      await serverResponded.future;
      await session.applyRefreshedSession(
        const AuthResult(token: 'new-token', user: _user),
      );
    });

    // Równoległe żądanie synchronizacji ze starym tokenem dostaje 401.
    final handled = session.handleUnauthorized(_revoked, tokenUsed: 'old-token');
    serverResponded.complete();
    await rotation;
    await handled;

    expect(storage.clearCalls, 0);
    expect(storage.token, 'new-token');
    expect(currentUser.value, _user);
  });

  test('applyRefreshedSession stores token and user without changing id',
      () async {
    const renamed = AuthUser(
      id: 'user-1',
      email: 'jan@example.com',
      firstName: 'Janek',
      lastName: 'Kowalski',
    );

    await session.applyRefreshedSession(
      const AuthResult(token: 'fresh', user: renamed),
    );

    expect(storage.token, 'fresh');
    expect(storage.user, renamed);
    expect(currentUser.value?.id, 'user-1');
    expect(currentUser.value?.firstName, 'Janek');
    expect(closeScopeCalls, 0);
  });

  test('completeAccountDeletion ends the session and wipes local data',
      () async {
    await session.completeAccountDeletion('user-1');

    expect(storage.token, isNull);
    expect(currentUser.value, isNull);
    expect(sessionEndedCalls, 1);
    expect(closeScopeCalls, 1);
    expect(wipedUsers, ['user-1']);
    expect(session.loginNotice.value, kAccountDeletedNotice);
  });

  test('login notice is cleared when a user logs in again', () async {
    await session.forceLogout();
    expect(session.loginNotice.value, kSessionExpiredNotice);

    currentUser.value = _user;

    expect(session.loginNotice.value, isNull);
  });
}
