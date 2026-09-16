import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/auth/presentation/screens/login_form_screen.dart';
import 'package:gym/features/auth/presentation/widgets/auth_card.dart';

void main() {
  testWidgets('formularz logowania żyje wewnątrz AuthCard', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginFormScreen()));

    expect(find.byType(AuthCard), findsOneWidget);
    expect(find.text('Witaj z powrotem'), findsOneWidget);
    expect(find.text('Zaloguj się'), findsOneWidget);
    expect(find.text('Zarejestruj się'), findsOneWidget);
    // Logowanie przez Apple/Google/Facebook nie działało — usunięte.
    expect(find.text('lub kontynuuj z'), findsNothing);
    expect(find.byIcon(Icons.apple), findsNothing);
    expect(find.byIcon(Icons.facebook_rounded), findsNothing);
  });
}
