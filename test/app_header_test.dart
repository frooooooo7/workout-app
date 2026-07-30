import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/widgets/app_header.dart';

void main() {
  testWidgets('renders AppHeader with title and back button', (tester) async {
    bool backTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppHeader(
            title: 'Szczegóły sesji',
            onBack: () => backTapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Szczegóły sesji'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pump();
    expect(backTapped, isTrue);
  });

  testWidgets('renders AppHeader without back button when onBack is null', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AppHeader(title: 'Historia treningów')),
      ),
    );

    expect(find.text('Historia treningów'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
  });

  testWidgets('renders AppHeader with right action buttons', (tester) async {
    bool actionTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppHeader(
            title: 'Statystyki',
            onBack: () {},
            actions: [
              AppHeaderIconButton(
                icon: Icons.more_vert_rounded,
                onTap: () => actionTapped = true,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Statystyki'), findsOneWidget);
    expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pump();
    expect(actionTapped, isTrue);
  });

  testWidgets('truncates long title with ellipsis without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1.0;

    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppHeader(
            title: 'Bardzo Długa Nazwa Ekranu Treningowego Bez Przepełnienia',
            onBack: () {},
            actions: [
              AppHeaderIconButton(
                icon: Icons.calendar_month_rounded,
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(
      find.text('Bardzo Długa Nazwa Ekranu Treningowego Bez Przepełnienia'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
