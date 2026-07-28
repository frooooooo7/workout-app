import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/theme/app_colors.dart';
import 'package:gym/features/auth/presentation/widgets/register_step_progress.dart';

void main() {
  testWidgets('krok 1: aktywny tylko pierwszy segment', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: RegisterStepProgress(currentStep: 0)),
      ),
    );

    final colors = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => (c.decoration as BoxDecoration?)?.color)
        .toList();

    expect(colors.where((c) => c == AppColors.primary).length, 1);
    expect(colors.where((c) => c == AppColors.border).length, 1);
  });

  testWidgets('krok 2: oba segmenty aktywne', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: RegisterStepProgress(currentStep: 1)),
      ),
    );

    final colors = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => (c.decoration as BoxDecoration?)?.color)
        .toList();

    expect(colors.where((c) => c == AppColors.primary).length, 2);
  });
}
