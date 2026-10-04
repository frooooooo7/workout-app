import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/profile/domain/models/body_weight_entry.dart';
import 'package:gym/features/profile/presentation/bloc/body_weight_cubit.dart';
import 'package:gym/features/profile/presentation/screens/body_weight_screen.dart';
import 'package:gym/features/profile/presentation/widgets/body_weight_chart.dart';
import 'package:gym/features/profile/presentation/widgets/body_weight_entry_sheet.dart';

import 'body_weight_test.dart' show FakeBodyWeightRepository;

BodyWeightEntry _e(int month, int day, double kg) =>
    BodyWeightEntry(date: DateTime(2026, month, day), weightKg: kg);

DateTime _now() => DateTime(2026, 10, 4, 9);

Future<BodyWeightCubit> _pump(
  WidgetTester tester,
  FakeBodyWeightRepository repo,
) async {
  await tester.binding.setSurfaceSize(const Size(430, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final cubit = BodyWeightCubit(repo);
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

String _text(WidgetTester tester, Key key) =>
    tester.widget<Text>(find.byKey(key)).data!;

void main() {
  testWidgets('shows current weight, change in range, chart and entries', (
    tester,
  ) async {
    final repo = FakeBodyWeightRepository([
      _e(6, 1, 90),
      _e(8, 20, 85.4),
      _e(9, 30, 84),
      _e(10, 3, 83.5),
    ]);
    await _pump(tester, repo);

    expect(_text(tester, const Key('body-weight-current')), '83,5 kg');
    // Domyślnie 3 miesiące: od 6 lipca, więc czerwcowy pomiar się nie liczy.
    expect(_text(tester, const Key('body-weight-change')), '−1,9 kg');
    expect(find.text('od 20 sie'), findsOneWidget);
    expect(find.byType(BodyWeightChart), findsOneWidget);
    expect(find.text('3 października 2026'), findsOneWidget);
    expect(find.text('1 czerwca 2026'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('body-weight-range-all')));
    await tester.pumpAndSettle();
    expect(_text(tester, const Key('body-weight-change')), '−6,5 kg');

    await tester.tap(find.byKey(const ValueKey('body-weight-range-days30')));
    await tester.pumpAndSettle();
    expect(_text(tester, const Key('body-weight-change')), '−0,5 kg');
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
    expect(_text(tester, const Key('body-weight-current')), '75 kg');
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

  testWidgets('deletes a measurement from its menu', (tester) async {
    final repo = FakeBodyWeightRepository([_e(9, 1, 82), _e(10, 1, 81)]);
    await _pump(tester, repo);

    await tester.tap(find.byTooltip('Więcej').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Usuń pomiar'));
    await tester.pumpAndSettle();

    expect(repo.deleted, [DateTime(2026, 10, 1)]);
    expect(_text(tester, const Key('body-weight-current')), '82 kg');
    expect(find.text('1 października 2026'), findsNothing);
  });

  testWidgets('offers a retry when loading fails', (tester) async {
    final repo = FakeBodyWeightRepository([_e(9, 1, 82)])
      ..listError = Exception('boom');
    await _pump(tester, repo);
    expect(find.text('Spróbuj ponownie'), findsOneWidget);

    repo.listError = null;
    await tester.tap(find.text('Spróbuj ponownie'));
    await tester.pumpAndSettle();
    expect(_text(tester, const Key('body-weight-current')), '82 kg');
  });
}
