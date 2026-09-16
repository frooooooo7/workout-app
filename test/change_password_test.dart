import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/network/api_client.dart';
import 'package:gym/features/account/domain/repositories/account_repository.dart';
import 'package:gym/features/account/presentation/bloc/change_password_cubit.dart';
import 'package:gym/features/account/presentation/screens/change_password_screen.dart';
import 'package:gym/features/account/presentation/utils/account_error_messages.dart';

class FakeAccountRepository implements AccountRepository {
  final changePasswordCalls = <(String, String)>[];
  var logoutAllCalls = 0;
  final deleteCalls = <String>[];
  Object? error;

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    changePasswordCalls.add((currentPassword, newPassword));
    if (error != null) throw error!;
  }

  @override
  Future<void> logoutAllDevices() async {
    logoutAllCalls++;
    if (error != null) throw error!;
  }

  @override
  Future<void> deleteAccount({required String password}) async {
    deleteCalls.add(password);
    if (error != null) throw error!;
  }
}

void main() {
  group('ChangePasswordCubit', () {
    late FakeAccountRepository repository;
    late ChangePasswordCubit cubit;

    setUp(() {
      repository = FakeAccountRepository();
      cubit = ChangePasswordCubit(repository);
    });

    tearDown(() => cubit.close());

    void fill(String current, String next, String confirm) {
      cubit
        ..currentPasswordChanged(current)
        ..newPasswordChanged(next)
        ..confirmPasswordChanged(confirm);
    }

    test('validation mirrors registration rules', () {
      fill('OldPass1', 'short', 'short');
      expect(cubit.state.newPasswordError, 'Min. 8 znaków.');
      expect(cubit.state.canSubmit, isFalse);

      cubit.newPasswordChanged('longpassword');
      expect(cubit.state.newPasswordError, 'Wymagana wielka litera.');

      cubit.newPasswordChanged('Longpassword');
      expect(cubit.state.newPasswordError, 'Wymagana cyfra.');

      cubit.newPasswordChanged('OldPass1');
      expect(
        cubit.state.newPasswordError,
        'Nowe hasło musi różnić się od obecnego.',
      );

      cubit.newPasswordChanged('NewPass1');
      expect(cubit.state.newPasswordError, isNull);
      expect(cubit.state.confirmPasswordError, 'Hasła nie są identyczne.');
      expect(cubit.state.canSubmit, isFalse);

      cubit.confirmPasswordChanged('NewPass1');
      expect(cubit.state.canSubmit, isTrue);

      cubit.currentPasswordChanged('');
      expect(cubit.state.canSubmit, isFalse);
    });

    test('submit calls repository and marks success', () async {
      fill('OldPass1', 'NewPass1', 'NewPass1');

      await cubit.submit();

      expect(repository.changePasswordCalls, [('OldPass1', 'NewPass1')]);
      expect(cubit.state.succeeded, isTrue);
      expect(cubit.state.submitting, isFalse);
    });

    test('invalid form does not call repository', () async {
      fill('OldPass1', 'NewPass1', 'Other1234');

      await cubit.submit();

      expect(repository.changePasswordCalls, isEmpty);
    });

    test('maps server errors to Polish', () async {
      fill('OldPass1', 'NewPass1', 'NewPass1');
      repository.error = const ApiException(
        'invalid_credentials',
        statusCode: 401,
      );

      await cubit.submit();

      expect(cubit.state.error, 'Obecne hasło jest nieprawidłowe.');
      expect(cubit.state.succeeded, isFalse);
      // Edycja pola czyści błąd.
      cubit.currentPasswordChanged('OldPass12');
      expect(cubit.state.error, isNull);
    });
  });

  test('changePasswordErrorMessage covers every backend code', () {
    String map(String code, [int? status = 400]) =>
        changePasswordErrorMessage(ApiException(code, statusCode: status));

    expect(map('invalid_credentials', 401), 'Obecne hasło jest nieprawidłowe.');
    expect(map('password_too_short'), 'Nowe hasło musi mieć co najmniej 8 znaków.');
    expect(
      map('password_too_weak'),
      'Nowe hasło musi zawierać wielką literę i cyfrę.',
    );
    expect(map('missing_fields'), 'Uzupełnij wszystkie pola.');
    expect(map('password_unchanged'), 'Nowe hasło musi różnić się od obecnego.');
    expect(map('too_many_requests', 429), 'Zbyt wiele prób. Spróbuj za chwilę.');
    expect(
      map('database_unavailable', 503),
      'Serwer chwilowo niedostępny. Spróbuj później.',
    );
    expect(map('network_error', null), kAccountOfflineMessage);
    expect(map('token_revoked', 401), 'Sesja wygasła. Zaloguj się ponownie.');
    expect(map('something_else'), 'Nie udało się zmienić hasła. Spróbuj ponownie.');
  });

  group('ChangePasswordScreen', () {
    Future<FakeAccountRepository> pumpScreen(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = FakeAccountRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => BlocProvider(
                      create: (_) => ChangePasswordCubit(repository),
                      child: const ChangePasswordScreen(),
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return repository;
    }

    Finder field(Key key) =>
        find.descendant(of: find.byKey(key), matching: find.byType(TextField));

    ElevatedButton submitButton(WidgetTester tester) =>
        tester.widget<ElevatedButton>(find.byKey(changePasswordSubmitButtonKey));

    testWidgets('submit enabled only for a valid form; success pops with snack',
        (tester) async {
      final repository = await pumpScreen(tester);

      expect(find.text('Obecne hasło'), findsWidgets);
      expect(find.text('Powtórz nowe hasło'), findsWidgets);
      expect(submitButton(tester).onPressed, isNull);

      await tester.enterText(field(changePasswordCurrentFieldKey), 'OldPass1');
      await tester.enterText(field(changePasswordNewFieldKey), 'newpas1');
      await tester.pump();
      expect(find.text('Min. 8 znaków.'), findsOneWidget);
      expect(find.text('Słabe'), findsOneWidget);

      await tester.enterText(field(changePasswordNewFieldKey), 'NewPass1');
      await tester.enterText(field(changePasswordConfirmFieldKey), 'NewPass2');
      await tester.pump();
      expect(find.text('Hasła nie są identyczne.'), findsOneWidget);
      expect(submitButton(tester).onPressed, isNull);

      await tester.enterText(field(changePasswordConfirmFieldKey), 'NewPass1');
      await tester.pump();
      expect(submitButton(tester).onPressed, isNotNull);

      await tester.tap(find.byKey(changePasswordSubmitButtonKey));
      await tester.pumpAndSettle();

      expect(repository.changePasswordCalls, [('OldPass1', 'NewPass1')]);
      expect(find.byType(ChangePasswordScreen), findsNothing);
      expect(find.text(kChangePasswordSuccessMessage), findsOneWidget);
    });

    testWidgets('shows mapped server error and stays open', (tester) async {
      final repository = await pumpScreen(tester);
      repository.error = const ApiException('password_unchanged', statusCode: 400);

      await tester.enterText(field(changePasswordCurrentFieldKey), 'OldPass1');
      await tester.enterText(field(changePasswordNewFieldKey), 'NewPass1');
      await tester.enterText(field(changePasswordConfirmFieldKey), 'NewPass1');
      await tester.pump();
      await tester.tap(find.byKey(changePasswordSubmitButtonKey));
      await tester.pumpAndSettle();

      expect(find.byType(ChangePasswordScreen), findsOneWidget);
      expect(find.text('Nowe hasło musi różnić się od obecnego.'), findsOneWidget);
    });

    testWidgets('visibility toggle reveals the password', (tester) async {
      await pumpScreen(tester);

      TextField current() => tester.widget<TextField>(
        field(changePasswordCurrentFieldKey),
      );
      expect(current().obscureText, isTrue);

      await tester.tap(
        find.descendant(
          of: find.byKey(changePasswordCurrentFieldKey),
          matching: find.byIcon(Icons.visibility_outlined),
        ),
      );
      await tester.pump();

      expect(current().obscureText, isFalse);
    });
  });
}
