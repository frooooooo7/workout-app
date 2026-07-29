import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/navigation/app_bottom_nav.dart';

void main() {
  Widget buildSubject({
    int currentIndex = 2,
    bool hasActiveSession = false,
    ValueChanged<int>? onDestinationSelected,
    VoidCallback? onCenterTap,
  }) {
    return MaterialApp(
      home: Scaffold(
        bottomNavigationBar: AppBottomNav(
          currentIndex: currentIndex,
          hasActiveSession: hasActiveSession,
          onDestinationSelected: onDestinationSelected ?? (_) {},
          onCenterTap: onCenterTap ?? () {},
        ),
      ),
    );
  }

  testWidgets('renders five destinations in order', (tester) async {
    await tester.pumpWidget(buildSubject());

    expect(find.text('Historia'), findsOneWidget);
    expect(find.text('Plany'), findsOneWidget);
    expect(find.text('Trening'), findsOneWidget);
    expect(find.text('Aktywność'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);

    final historiaX = tester.getCenter(find.text('Historia')).dx;
    final planyX = tester.getCenter(find.text('Plany')).dx;
    final treningX = tester.getCenter(find.text('Trening')).dx;
    final aktywnoscX = tester.getCenter(find.text('Aktywność')).dx;
    final profilX = tester.getCenter(find.text('Profil')).dx;
    expect(historiaX < planyX, isTrue);
    expect(planyX < treningX, isTrue);
    expect(treningX < aktywnoscX, isTrue);
    expect(aktywnoscX < profilX, isTrue);
  });

  testWidgets('delegates small destination taps with branch index', (
    tester,
  ) async {
    int? tappedIndex;
    await tester.pumpWidget(
      buildSubject(onDestinationSelected: (index) => tappedIndex = index),
    );

    await tester.tap(find.text('Historia'));
    expect(tappedIndex, 0);

    await tester.tap(find.text('Aktywność'));
    expect(tappedIndex, 3);

    await tester.tap(find.text('Profil'));
    expect(tappedIndex, 4);
  });

  testWidgets('center circle and label call onCenterTap', (tester) async {
    var centerTaps = 0;
    await tester.pumpWidget(buildSubject(onCenterTap: () => centerTaps += 1));

    await tester.tap(find.byKey(const Key('app-bottom-nav-center')));
    expect(centerTaps, 1);

    await tester.tap(find.text('Trening'));
    expect(centerTaps, 2);
  });

  testWidgets('shows active-session dot only when session is active', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject(hasActiveSession: true));
    expect(find.byKey(const Key('app-bottom-nav-active-dot')), findsOneWidget);

    await tester.pumpWidget(buildSubject(hasActiveSession: false));
    expect(find.byKey(const Key('app-bottom-nav-active-dot')), findsNothing);
  });

  testWidgets('selected center shows white ring, unselected does not', (
    tester,
  ) async {
    BoxDecoration decorationOf(WidgetTester tester) {
      final container = tester.widget<Container>(
        find.byKey(const Key('app-bottom-nav-center')),
      );
      return container.decoration! as BoxDecoration;
    }

    await tester.pumpWidget(buildSubject(currentIndex: 2));
    expect(decorationOf(tester).border, isNotNull);

    await tester.pumpWidget(buildSubject(currentIndex: 0));
    expect(decorationOf(tester).border, isNull);
  });
}
