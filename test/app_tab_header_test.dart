import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/widgets/app_tab_header.dart';
import 'package:gym/core/widgets/sync_status_indicator.dart';

void main() {
  testWidgets('renders title, back, actions and sync indicator last', (
    tester,
  ) async {
    var back = false;
    var add = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppTabHeader(
            title: 'Biblioteka',
            leading: AppTabHeaderButton.back(onPressed: () => back = true),
            actions: [
              AppTabHeaderButton(
                icon: Icons.add_rounded,
                tooltip: 'Dodaj',
                accent: true,
                onPressed: () => add = true,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Biblioteka'), findsOneWidget);
    expect(find.byType(SyncStatusIndicator), findsOneWidget);
    expect(
      tester.getCenter(find.byTooltip('Dodaj')).dx,
      lessThan(tester.getCenter(find.byType(SyncStatusIndicator)).dx),
    );

    await tester.tap(find.byTooltip('Wstecz'));
    await tester.tap(find.byTooltip('Dodaj'));
    expect(back, isTrue);
    expect(add, isTrue);
  });

  testWidgets('sync indicator can be hidden', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AppTabHeader(title: 'Profil', showSync: false)),
      ),
    );

    expect(find.byType(SyncStatusIndicator), findsNothing);
  });
}
