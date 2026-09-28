import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/auth/domain/repositories/password_reset_repository.dart';
import 'package:gym/features/auth/presentation/screens/forgot_password_screen.dart';

class _FakeResetRepository implements PasswordResetRepository {
  _FakeResetRepository({this.fail = false});

  final bool fail;
  final requested = <String>[];

  @override
  bool get isLive => false;

  @override
  Future<void> requestReset({required String email}) async {
    requested.add(email);
    if (fail) throw Exception('network');
  }
}

Widget _app(ForgotPasswordScreen screen) => MaterialApp(home: screen);

/// Rozmiar telefonu zamiast domyślnych 800×600.
void _usePhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.pumpAndSettle();
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('wysyła link i pokazuje potwierdzenie z odliczaniem', (
    tester,
  ) async {
    _usePhoneSize(tester);
    final repository = _FakeResetRepository();
    await tester.pumpWidget(
      _app(
        ForgotPasswordScreen(
          initialEmail: 'jan@example.com',
          repository: repository,
          resendCooldown: const Duration(seconds: 3),
        ),
      ),
    );

    expect(find.text('Nie pamiętasz hasła?'), findsOneWidget);
    await tester.tap(find.text('Wyślij link'));
    await tester.pumpAndSettle();

    expect(repository.requested, ['jan@example.com']);
    expect(find.text('Sprawdź skrzynkę'), findsOneWidget);
    expect(find.textContaining('jan@example.com'), findsOneWidget);
    // Zaślepka uczciwie mówi, że e-mail jeszcze nie dotrze.
    expect(find.textContaining('uruchomiona wkrótce'), findsOneWidget);
    expect(find.text('Wyślij ponownie (0:03)'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await _tapText(tester, 'Wyślij ponownie');
    expect(repository.requested, ['jan@example.com', 'jan@example.com']);

    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('nie wysyła przy błędnym adresie', (tester) async {
    final repository = _FakeResetRepository();
    await tester.pumpWidget(
      _app(ForgotPasswordScreen(repository: repository)),
    );

    await tester.enterText(find.byType(TextFormField), 'to-nie-email');
    await tester.tap(find.text('Wyślij link'));
    await tester.pumpAndSettle();

    expect(repository.requested, isEmpty);
    expect(find.text('Podaj prawidłowy adres e-mail.'), findsOneWidget);
  });

  testWidgets('błąd sieci zostawia formularz z komunikatem', (tester) async {
    final repository = _FakeResetRepository(fail: true);
    await tester.pumpWidget(
      _app(
        ForgotPasswordScreen(
          initialEmail: 'jan@example.com',
          repository: repository,
        ),
      ),
    );

    await tester.tap(find.text('Wyślij link'));
    await tester.pumpAndSettle();

    expect(find.text('Sprawdź skrzynkę'), findsNothing);
    expect(
      find.text('Brak połączenia z serwerem. Sprawdź sieć.'),
      findsOneWidget,
    );
  });

  testWidgets('„Zmień e-mail” wraca do formularza', (tester) async {
    _usePhoneSize(tester);
    await tester.pumpWidget(
      _app(
        ForgotPasswordScreen(
          initialEmail: 'jan@example.com',
          repository: _FakeResetRepository(),
        ),
      ),
    );

    await tester.tap(find.text('Wyślij link'));
    await tester.pumpAndSettle();
    await _tapText(tester, 'Zmień e-mail');

    expect(find.text('Nie pamiętasz hasła?'), findsOneWidget);
  });
}
