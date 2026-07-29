import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/training/presentation/widgets/training_day_hero.dart';

void main() {
  testWidgets('rest day shows copy and fires onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainingDayHero(
            label: 'Na dziś',
            isLoading: false,
            isRestDay: true,
            title: 'Dzień odpoczynku',
            subtitle: 'Regeneracja to postęp.',
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Na dziś'), findsOneWidget);
    expect(find.text('Dzień odpoczynku'), findsOneWidget);
    expect(find.text('Regeneracja to postęp.'), findsOneWidget);
    expect(find.byKey(const ValueKey('monk-rest-icon')), findsOneWidget);

    await tester.tap(find.byType(TrainingDayHero));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('training day shows title, plan name, no monk, fires onTap', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainingDayHero(
            label: 'Poniedziałek',
            isLoading: false,
            isRestDay: false,
            title: 'Dzień treningowy',
            subtitle: 'Push Power',
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Dzień treningowy'), findsOneWidget);
    expect(find.text('Push Power'), findsOneWidget);
    expect(find.byKey(const ValueKey('monk-rest-icon')), findsNothing);
    expect(find.byKey(const ValueKey('training-day-icon')), findsOneWidget);

    await tester.tap(find.byType(TrainingDayHero));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('loading shows spinner only', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainingDayHero(
            label: 'Na dziś',
            isLoading: true,
            isRestDay: true,
            title: '',
            subtitle: '',
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const ValueKey('monk-rest-icon')), findsNothing);
  });
}
