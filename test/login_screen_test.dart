import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/auth/presentation/screens/login_screen.dart';
import 'package:gym/features/auth/presentation/widgets/auth_card.dart';
import 'package:gym/features/auth/presentation/widgets/auth_hero_background.dart';

void main() {
  testWidgets('ekran powitalny pokazuje kartę z marką i akcjami', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.byType(AuthHeroBackground), findsOneWidget);
    expect(find.byType(AuthCard), findsOneWidget);
    expect(find.text('STRONGER'), findsOneWidget);
    expect(find.text('Trenuj mądrze.'), findsOneWidget);
    expect(find.text('Osiągaj więcej.'), findsOneWidget);
    expect(find.text('Zaloguj się'), findsOneWidget);
    expect(find.text('Utwórz konto'), findsOneWidget);
    expect(find.text('lub kontynuuj z'), findsOneWidget);
    // Hero w tle + logo w karcie:
    expect(find.byType(Image), findsNWidgets(2));
  });
}
