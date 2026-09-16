import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/network/api_client.dart';
import 'package:gym/features/account/presentation/bloc/logout_all_devices_cubit.dart';
import 'package:gym/features/auth/domain/models/auth_models.dart';
import 'package:gym/features/profile/presentation/screens/profile_settings_screen.dart';

import 'change_password_test.dart' show FakeAccountRepository;

const _user = AuthUser(
  id: 'user-1',
  email: 'jan@example.com',
  firstName: 'Jan',
  lastName: 'Kowalski',
);

void main() {
  Future<FakeAccountRepository> pumpScreen(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = FakeAccountRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileSettingsScreen(user: _user, accountRepository: repository),
      ),
    );
    return repository;
  }

  testWidgets('no "Wkrótce" placeholders; danger zone with delete account', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('Wkrótce'), findsNothing);
    expect(find.text('Zmiana hasła'), findsOneWidget);
    expect(find.text('Wyloguj ze wszystkich urządzeń'), findsOneWidget);
    expect(find.text('Powiadomienia'), findsOneWidget);
    expect(find.text('Pomoc'), findsOneWidget);
    expect(find.text('STREFA NIEBEZPIECZNA'), findsOneWidget);
    expect(find.byKey(settingsDeleteAccountRowKey), findsOneWidget);
  });

  testWidgets('logout from all devices asks for confirmation first', (
    tester,
  ) async {
    final repository = await pumpScreen(tester);

    await tester.tap(find.byKey(settingsLogoutAllRowKey));
    await tester.pumpAndSettle();
    expect(find.text('Wylogować ze wszystkich urządzeń?'), findsOneWidget);

    await tester.tap(find.text('Anuluj'));
    await tester.pumpAndSettle();
    expect(repository.logoutAllCalls, 0);

    await tester.tap(find.byKey(settingsLogoutAllRowKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wyloguj wszędzie'));
    await tester.pumpAndSettle();

    expect(repository.logoutAllCalls, 1);
    expect(find.text(kLogoutAllSuccessMessage), findsOneWidget);
  });

  testWidgets('logout from all devices offline shows friendly error', (
    tester,
  ) async {
    final repository = await pumpScreen(tester);
    repository.error = const ApiException('network_error');

    await tester.tap(find.byKey(settingsLogoutAllRowKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wyloguj wszędzie'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Brak połączenia z internetem. Spróbuj ponownie, gdy będziesz online.',
      ),
      findsOneWidget,
    );
  });
}
