import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/network/api_client.dart';
import 'package:gym/features/account/presentation/bloc/delete_account_cubit.dart';
import 'package:gym/features/account/presentation/screens/delete_account_screen.dart';

import 'change_password_test.dart' show FakeAccountRepository;

void main() {
  Future<FakeAccountRepository> pumpScreen(
    WidgetTester tester, {
    int unsynced = 0,
  }) async {
    await tester.binding.setSurfaceSize(const Size(430, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = FakeAccountRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => DeleteAccountCubit(
            repository,
            countUnsyncedChanges: () async => unsynced,
          ),
          child: const DeleteAccountScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repository;
  }

  ElevatedButton submitButton(WidgetTester tester) =>
      tester.widget<ElevatedButton>(find.byKey(deleteAccountSubmitButtonKey));

  Finder passwordField() => find.descendant(
    of: find.byKey(deleteAccountPasswordFieldKey),
    matching: find.byType(TextField),
  );

  testWidgets('explains consequences; requires password and confirmation', (
    tester,
  ) async {
    final repository = await pumpScreen(tester);

    expect(find.text('Tej operacji nie można cofnąć'), findsOneWidget);
    expect(find.textContaining('wszystkie treningi'), findsOneWidget);
    expect(find.textContaining('kudosy i komentarze'), findsOneWidget);
    expect(find.textContaining('obserwujący'), findsOneWidget);
    expect(find.byKey(deleteAccountUnsyncedWarningKey), findsNothing);
    expect(submitButton(tester).onPressed, isNull);

    await tester.enterText(passwordField(), 'Secret123');
    await tester.pump();
    expect(submitButton(tester).onPressed, isNull);

    await tester.tap(find.byKey(deleteAccountConfirmCheckboxKey));
    await tester.pump();
    expect(submitButton(tester).onPressed, isNotNull);

    await tester.tap(find.byKey(deleteAccountSubmitButtonKey));
    await tester.pumpAndSettle();

    expect(repository.deleteCalls, ['Secret123']);
  });

  testWidgets('warns about unsynced local changes', (tester) async {
    await pumpScreen(tester, unsynced: 3);

    expect(find.byKey(deleteAccountUnsyncedWarningKey), findsOneWidget);
    expect(find.textContaining('Masz 3 zmiany'), findsOneWidget);
    expect(find.textContaining('Przepadną razem z kontem'), findsOneWidget);
  });

  testWidgets('maps wrong password and offline errors', (tester) async {
    final repository = await pumpScreen(tester);
    repository.error = const ApiException('invalid_credentials', statusCode: 401);

    await tester.enterText(passwordField(), 'bad');
    await tester.tap(find.byKey(deleteAccountConfirmCheckboxKey));
    await tester.pump();
    await tester.tap(find.byKey(deleteAccountSubmitButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('Nieprawidłowe hasło.'), findsOneWidget);

    repository.error = const ApiException('network_error');
    await tester.tap(find.byKey(deleteAccountSubmitButtonKey));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Brak połączenia z internetem. Spróbuj ponownie, gdy będziesz online.',
      ),
      findsOneWidget,
    );
  });
}
