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
    expect(find.text('lub kontynuuj z'), findsOneWidget);
  });
}
