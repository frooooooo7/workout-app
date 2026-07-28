import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/theme/app_colors.dart';
import 'package:gym/features/auth/presentation/widgets/auth_card.dart';
import 'package:gym/features/auth/presentation/widgets/auth_glow_background.dart';

void main() {
  testWidgets('AuthCard rysuje dziecko w kontenerze surface z ramką', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AuthCard(child: Text('inside'))),
      ),
    );

    expect(find.text('inside'), findsOneWidget);

    final container = tester.widget<Container>(
      find
          .ancestor(of: find.text('inside'), matching: find.byType(Container))
          .first,
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, AppColors.surface);
    expect(decoration.borderRadius, BorderRadius.circular(20));
  });

  testWidgets('AuthGlowBackground rysuje poświatę i dziecko', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AuthGlowBackground(child: Text('content'))),
      ),
    );

    expect(find.text('content'), findsOneWidget);

    final glowContainers = tester
        .widgetList<Container>(find.byType(Container))
        .where(
          (c) =>
              c.decoration is BoxDecoration &&
              (c.decoration! as BoxDecoration).gradient is RadialGradient,
        );
    expect(glowContainers.length, 1);
  });
}
