import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/auth/presentation/screens/login_screen.dart';
import 'package:gym/features/auth/presentation/widgets/auth_card.dart';

void main() {
  testWidgets('ekran powitalny pokazuje kartę z marką i akcjami', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.byType(AuthCard), findsOneWidget);
    expect(find.text('STRONGER'), findsOneWidget);
    expect(find.text('Trenuj mądrze.'), findsOneWidget);
    expect(find.text('Osiągaj więcej.'), findsOneWidget);
    expect(find.text('Zaloguj się'), findsOneWidget);
    expect(find.text('Utwórz konto'), findsOneWidget);
    expect(find.text('lub kontynuuj z'), findsOneWidget);
    // Tylko logo — bez zdjęcia hero:
    expect(find.byType(Image), findsOneWidget);
  });
}
