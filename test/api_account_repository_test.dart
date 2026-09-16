import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/network/api_client.dart';
import 'package:gym/core/session/session_manager.dart';
import 'package:gym/features/account/data/account_remote_data_source.dart';
import 'package:gym/features/account/data/api_account_repository.dart';
import 'package:gym/features/auth/data/auth_repository.dart';
import 'package:gym/features/auth/domain/models/auth_models.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'session_manager_test.dart' show FakeTokenStorage;

const _user = AuthUser(
  id: 'user-1',
  email: 'jan@example.com',
  firstName: 'Jan',
  lastName: 'Kowalski',
);

http.Response _json(int status, Object body) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  late FakeTokenStorage storage;
  late ValueNotifier<AuthUser?> currentUser;
  late SessionManager session;
  late List<http.Request> requests;
  late http.Response Function(http.Request request) respond;
  late List<String> wiped;
  late int sessionEnded;
  late ApiClient client;
  late ApiAccountRepository repository;

  setUp(() {
    storage = FakeTokenStorage(token: 'old-token', user: _user);
    currentUser = ValueNotifier<AuthUser?>(_user);
    requests = [];
    wiped = [];
    sessionEnded = 0;
    respond = (_) => http.Response('', 500);
    session = SessionManager(
      tokenStorage: storage,
      currentUser: currentUser,
      closeUserScope: () async => currentUser.value = null,
      wipeUserData: (userId) async => wiped.add(userId),
      onSessionEnded: () => sessionEnded++,
    );
    client = http.runWithClient(
      () => ApiClient(
        baseUrl: 'http://api',
        getToken: storage.readToken,
        onUnauthorized: (error, token) =>
            session.handleUnauthorized(error, tokenUsed: token),
      ),
      () => MockClient((request) async {
        requests.add(request);
        return respond(request);
      }),
    );
    repository = ApiAccountRepository(
      remote: AccountRemoteDataSource(client),
      session: session,
    );
  });

  tearDown(() {
    session.dispose();
    currentUser.dispose();
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('changePassword sends both passwords and stores the new token', () async {
    respond = (_) => _json(200, {
      'token': 'new-token',
      'user': {
        'id': 'user-1',
        'email': 'jan@example.com',
        'firstName': 'Jan',
        'lastName': 'Kowalski',
      },
    });

    await repository.changePassword(
      currentPassword: 'OldPass1',
      newPassword: 'NewPass1',
    );

    final request = requests.single;
    expect(request.method, 'POST');
    expect(request.url.path, '/auth/change-password');
    expect(request.headers['Authorization'], 'Bearer old-token');
    expect(jsonDecode(request.body), {
      'currentPassword': 'OldPass1',
      'newPassword': 'NewPass1',
    });
    expect(storage.token, 'new-token');
    expect(currentUser.value?.id, 'user-1');
    expect(sessionEnded, 0);
  });

  test('wrong current password (401 invalid_credentials) does not log out',
      () async {
    respond = (_) => _json(401, {'error': 'invalid_credentials'});

    await expectLater(
      repository.changePassword(currentPassword: 'x', newPassword: 'NewPass1'),
      throwsA(
        isA<ApiException>().having((e) => e.message, 'message', 'invalid_credentials'),
      ),
    );
    await settle();

    expect(storage.token, 'old-token');
    expect(currentUser.value, _user);
    expect(sessionEnded, 0);
  });

  test('logoutAllDevices stores the returned token', () async {
    respond = (_) => _json(200, {
      'token': 'rotated',
      'user': {
        'id': 'user-1',
        'email': 'jan@example.com',
        'firstName': 'Jan',
        'lastName': 'Kowalski',
      },
    });

    await repository.logoutAllDevices();

    expect(requests.single.url.path, '/auth/logout-all');
    expect(storage.token, 'rotated');
    expect(currentUser.value, isNotNull);
  });

  test('deleteAccount posts the password and wipes local data',
      () async {
    respond = (_) => http.Response('', 204);

    await repository.deleteAccount(password: 'Secret123');

    final request = requests.single;
    expect(request.method, 'POST');
    expect(request.url.path, '/auth/delete-account');
    expect(jsonDecode(request.body), {'password': 'Secret123'});
    expect(storage.token, isNull);
    expect(currentUser.value, isNull);
    expect(wiped, ['user-1']);
    expect(sessionEnded, 1);
    expect(session.loginNotice.value, kAccountDeletedNotice);
  });

  test('deleteAccount with wrong password keeps the session', () async {
    respond = (_) => _json(401, {'error': 'invalid_credentials'});

    await expectLater(
      repository.deleteAccount(password: 'bad'),
      throwsA(isA<ApiException>()),
    );
    await settle();

    expect(storage.token, 'old-token');
    expect(wiped, isEmpty);
    expect(sessionEnded, 0);
  });

  test('token_revoked from any authenticated call forces logout once',
      () async {
    respond = (_) => _json(401, {'error': 'token_revoked'});

    await Future.wait([
      for (var i = 0; i < 3; i++)
        client.get('/exercises', auth: true).catchError((_) => null),
    ]);
    await settle();
    await settle();

    expect(sessionEnded, 1);
    expect(storage.token, isNull);
    expect(currentUser.value, isNull);
    expect(session.loginNotice.value, kSessionExpiredNotice);
    expect(wiped, isEmpty);
  });

  test('login invalid_credentials (unauthenticated call) is not reported',
      () async {
    respond = (_) => _json(401, {'error': 'invalid_credentials'});
    var reported = 0;
    final plainClient = http.runWithClient(
      () => ApiClient(
        baseUrl: 'http://api',
        getToken: storage.readToken,
        onUnauthorized: (_, _) => reported++,
      ),
      () => MockClient((request) async => respond(request)),
    );

    await expectLater(
      AuthRepository(plainClient).login(email: 'a@b.pl', password: 'x'),
      throwsA(isA<ApiException>()),
    );

    expect(reported, 0);
  });

  test('DELETE call sites still work', () async {
    respond = (_) => http.Response('', 204);

    final result = await client.delete('/posts/1/kudos', auth: true);

    expect(result, isNull);
    expect(requests.single.method, 'DELETE');
    expect(requests.single.body, isEmpty);
  });
}
