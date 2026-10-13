import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/network/api_client.dart';
import 'package:gym/features/profile/domain/models/body_weight_entry.dart';
import 'package:gym/features/profile/presentation/bloc/body_weight_cubit.dart';
import 'package:gym/features/profile/presentation/screens/body_weight_screen.dart';
import 'package:gym/features/profile/presentation/widgets/body_weight_chart.dart';
import 'package:gym/features/profile/presentation/widgets/body_weight_entry_sheet.dart';
import 'package:gym/features/profile/presentation/widgets/body_weight_goal_card.dart';
import 'package:gym/features/profile/presentation/widgets/body_weight_goal_sheet.dart';

import 'body_weight_test.dart'
    show FakeBodyWeightRepository, FakeGoalProfileRepository;

BodyWeightEntry _e(int month, int day, double kg) =>
    BodyWeightEntry(date: DateTime(2026, month, day), weightKg: kg);

DateTime _now() => DateTime(2026, 10, 4, 9);

Future<BodyWeightCubit> _pump(
  WidgetTester tester,
  FakeBodyWeightRepository repo, {
  FakeGoalProfileRepository? profile,
}) async {
  await tester.binding.setSurfaceSize(const Size(430, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final cubit = BodyWeightCubit(
    repo,
    profile: profile ?? FakeGoalProfileRepository(),
  );
  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider.value(
        value: cubit,
        child: const BodyWeightScreen(clock: _now),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return cubit;
}

String _text(WidgetTester tester, Key key) {
  final found = find.byKey(key);
  final text = tester.widget(found) is Text
      ? found
      : find.descendant(of: found, matching: find.byType(Text));
  return tester.widget<Text>(text).data!;
}

Future<void> _expandWeek(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows current weight, change in range, chart and weeks', (
    tester,
  ) async {
    final repo = FakeBodyWeightRepository([
      _e(6, 1, 90),
      _e(8, 20, 85.4),
      _e(9, 30, 84),
      _e(10, 3, 83.5),
    ]);
    await _pump(tester, repo);

    expect(find.text('Masa ciała'), findsOneWidget);
    expect(find.text('WCZORAJ · 3 PAŹ'), findsOneWidget);
    expect(_text(tester, const Key('body-weight-current')), '83,5');
    // Domyślnie 3 miesiące: od 6 lipca, więc czerwcowy pomiar się nie liczy.
    expect(_text(tester, const Key('body-weight-change')), '1,9 kg');
    expect(find.text('od 20 sierpnia'), findsOneWidget);
    expect(find.byType(BodyWeightChart), findsOneWidget);
    expect(find.text('Średnia 7 dni'), findsOneWidget);

    // Tygodnie od najnowszego, każdy ze średnią.
    expect(find.text('Tygodnie'), findsOneWidget);
    expect(find.text('4 pomiary'), findsOneWidget);
    expect(find.text('28 wrz – 4 paź'), findsOneWidget);
    expect(find.text('2 pomiary · śr.'), findsOneWidget);
    // Średnia tygodnia i średnia 7 dni.
    expect(find.text('83,8 kg'), findsNWidgets(2));
    expect(find.text('1–7 cze'), findsOneWidget);

    // Pomiary tygodnia po rozwinięciu.
    expect(find.text('sobota, 3 października 2026'), findsNothing);
    await _expandWeek(tester, '28 wrz – 4 paź');
    expect(find.text('sobota, 3 października 2026'), findsOneWidget);
    expect(find.text('środa, 30 września 2026'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('body-weight-range-all')));
    await tester.pumpAndSettle();
    expect(_text(tester, const Key('body-weight-change')), '6,5 kg');

    await tester.tap(find.byKey(const ValueKey('body-weight-range-days30')));
    await tester.pumpAndSettle();
    expect(_text(tester, const Key('body-weight-change')), '0,5 kg');
  });

  testWidgets('adds a measurement for today from the sheet', (tester) async {
    final repo = FakeBodyWeightRepository();
    await _pump(tester, repo);
    expect(find.text('Brak pomiarów'), findsOneWidget);

    await tester.tap(find.byKey(bodyWeightAddButtonKey));
    await tester.pumpAndSettle();
    expect(find.text('Nowy pomiar'), findsOneWidget);
    expect(find.text('Dziś'), findsOneWidget);

    await tester.tap(find.byKey(bodyWeightSheetSaveKey));
    await tester.pumpAndSettle();

    expect(repo.saved, [_e(10, 4, 75)]);
    expect(_text(tester, const Key('body-weight-current')), '75,0');
    expect(find.text('Zapisano pomiar.'), findsOneWidget);
  });

  testWidgets('warns when the day already has a measurement', (tester) async {
    final repo = FakeBodyWeightRepository([_e(10, 4, 80)]);
    await _pump(tester, repo);

    await tester.tap(find.byKey(bodyWeightAddButtonKey));
    await tester.pumpAndSettle();

    expect(
      find.text('Ten dzień ma już pomiar — zapis go zastąpi.'),
      findsOneWidget,
    );
  });

  testWidgets('edits and deletes a measurement from its week', (tester) async {
    final repo = FakeBodyWeightRepository([_e(9, 1, 82), _e(10, 1, 81)]);
    await _pump(tester, repo);
    await _expandWeek(tester, '28 wrz – 4 paź');

    await tester.tap(find.text('czwartek, 1 października 2026'));
    await tester.pumpAndSettle();
    expect(find.text('Edytuj pomiar'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Więcej'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Usuń pomiar'));
    await tester.pumpAndSettle();

    expect(repo.deleted, [DateTime(2026, 10, 1)]);
    expect(_text(tester, const Key('body-weight-current')), '82,0');
    expect(find.text('28 wrz – 4 paź'), findsNothing);
  });

  testWidgets('offers a retry when loading fails', (tester) async {
    final repo = FakeBodyWeightRepository([_e(9, 1, 82)])
      ..listError = Exception('boom');
    await _pump(tester, repo);
    expect(find.text('Spróbuj ponownie'), findsOneWidget);

    repo.listError = null;
    await tester.tap(find.text('Spróbuj ponownie'));
    await tester.pumpAndSettle();
    expect(_text(tester, const Key('body-weight-current')), '82,0');
  });

  testWidgets('sets, shows and clears the weight goal', (tester) async {
    final profile = FakeGoalProfileRepository();
    final repo = FakeBodyWeightRepository([_e(9, 1, 84), _e(10, 3, 82)]);
    await _pump(tester, repo, profile: profile);

    expect(find.byKey(bodyWeightGoalCardKey), findsNothing);
    await tester.tap(find.byKey(bodyWeightGoalCtaKey));
    await tester.pumpAndSettle();
    expect(find.text('Ustaw cel'), findsWidgets);
    expect(find.byKey(bodyWeightGoalClearKey), findsNothing);

    // Linijka startuje od aktualnej wagi.
    await tester.tap(find.byKey(bodyWeightGoalSaveKey));
    await tester.pumpAndSettle();
    expect(profile.updates, [82]);
    expect(find.text('Cel: 82 kg'), findsOneWidget);
    expect(find.text('Cel osiągnięty'), findsOneWidget);
    expect(find.text('Zapisano cel.'), findsOneWidget);

    await tester.tap(find.byKey(bodyWeightGoalCardKey));
    await tester.pumpAndSettle();
    expect(find.text('Zmień cel'), findsOneWidget);
    await tester.tap(find.byKey(bodyWeightGoalClearKey));
    await tester.pumpAndSettle();

    expect(profile.updates, [82, null]);
    expect(find.byKey(bodyWeightGoalCtaKey), findsOneWidget);
  });

  testWidgets('shows goal progress and hides the projection going away', (
    tester,
  ) async {
    final falling = [
      for (var d = 0; d < 28; d += 2)
        BodyWeightEntry(date: DateTime(2026, 9, 6 + d), weightKg: 85 - d * 0.1),
    ];
    final profile = FakeGoalProfileRepository(80);
    await _pump(tester, FakeBodyWeightRepository(falling), profile: profile);

    expect(find.text('Cel: 80 kg'), findsOneWidget);
    expect(find.textContaining('zostało'), findsOneWidget);
    expect(find.text('Cel około'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('body-weight-pace')),
        matching: find.text('−0,7 kg/tydz.'),
      ),
      findsOneWidget,
    );

    // Ta sama historia, ale cel powyżej — trend od niego ucieka.
    profile.goalKg = 90;
    await tester.pumpWidget(const SizedBox());
    await _pump(tester, FakeBodyWeightRepository(falling), profile: profile);
    expect(find.text('Cel: 90 kg'), findsOneWidget);
    expect(find.text('Cel około'), findsNothing);
  });

  testWidgets('without the profile offline there is no goal at all', (
    tester,
  ) async {
    final profile = FakeGoalProfileRepository(80)
      ..error = const ApiException('network_error');
    await _pump(
      tester,
      FakeBodyWeightRepository([_e(9, 1, 82), _e(10, 1, 81)]),
      profile: profile,
    );

    expect(_text(tester, const Key('body-weight-current')), '81,0');
    expect(find.byKey(bodyWeightGoalCardKey), findsNothing);
    expect(find.byKey(bodyWeightGoalCtaKey), findsNothing);
  });
}
