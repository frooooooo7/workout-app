import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/auth/presentation/screens/register_screen.dart';

void main() {
  Future<void> advanceToAccountStep(WidgetTester tester) async {
    await tester.enterText(find.byType(TextFormField).at(0), 'Jan');
    await tester.enterText(find.byType(TextFormField).at(1), 'Kowalski');
    await tester.tap(find.text('Dalej'));
    await tester.pumpAndSettle();
  }

  testWidgets('startuje na kroku imienia i przechodzi do kroku konta', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));

    expect(find.text('Jak masz na imię?'), findsOneWidget);
    expect(find.text('Krok 1 z 2 — kilka podstawowych danych.'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));

    await advanceToAccountStep(tester);

    expect(find.text('Ustaw dostęp'), findsOneWidget);
    expect(find.text('Krok 2 z 2 — e-mail i hasło do logowania.'), findsOneWidget);
    expect(find.text('E-mail'), findsOneWidget);
    expect(find.text('Hasło'), findsOneWidget);
  });

  testWidgets('wstecz na kroku konta wraca do kroku imienia', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));
    await advanceToAccountStep(tester);
    expect(find.text('Ustaw dostęp'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Jak masz na imię?'), findsOneWidget);
    expect(find.text('Ustaw dostęp'), findsNothing);
  });
}
