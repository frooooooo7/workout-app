import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/widgets/app_tab_header.dart';

void main() {
  Widget buildTab() {
    return MaterialApp(
      home: Scaffold(
        body: AppTabBackground(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppTabHeader(title: 'Plany', showSync: false),
              const AppTabScrollEdge(),
              Expanded(
                child: ListView.builder(
                  itemCount: 40,
                  itemBuilder: (_, i) =>
                      SizedBox(height: 80, child: Text('Wiersz $i')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color edgeColor(WidgetTester tester) {
    final container = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byType(AppTabScrollEdge),
        matching: find.byType(AnimatedContainer),
      ),
    );
    return (container.decoration as BoxDecoration?)?.color ??
        Colors.transparent;
  }

  double glowOffset(WidgetTester tester) {
    final transform = tester.widget<Transform>(
      find
          .descendant(
            of: find.byType(AppTabBackground),
            matching: find.byType(Transform),
          )
          .first,
    );
    return transform.transform.getTranslation().y;
  }

  testWidgets('glow scrolls with content and the edge appears when scrolled', (
    tester,
  ) async {
    await tester.pumpWidget(buildTab());

    expect(edgeColor(tester).a, 0);
    expect(glowOffset(tester), 0);

    await tester.drag(find.byType(ListView), const Offset(0, -120));
    await tester.pumpAndSettle();

    expect(edgeColor(tester).a, greaterThan(0));
    expect(glowOffset(tester), lessThan(-100));

    await tester.drag(find.byType(ListView), const Offset(0, 400));
    await tester.pumpAndSettle();

    expect(edgeColor(tester).a, 0);
    expect(glowOffset(tester), 0);
  });

  testWidgets('glow offset is capped at the glow height', (tester) async {
    await tester.pumpWidget(buildTab());

    await tester.drag(find.byType(ListView), const Offset(0, -1500));
    await tester.pumpAndSettle();

    expect(glowOffset(tester), -AppTabBackground.glowHeight);
  });
}
