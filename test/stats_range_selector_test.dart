import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/theme/app_colors.dart';
import 'package:gym/core/theme/app_localization.dart';
import 'package:gym/core/theme/app_spacing.dart';
import 'package:gym/features/training/domain/models/training_stats.dart';
import 'package:gym/features/training/presentation/widgets/stats/stats_date_range_picker.dart';
import 'package:gym/features/training/presentation/widgets/stats/stats_range_selector.dart';

const _calendarKey = ValueKey('stats-range-calendar');

/// Telefon 360 dp — najwęższy ekran, na który pasek ma się zmieścić.
void _phoneView(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _app({
  StatsRange selected = StatsRange.month,
  StatsDateRange? customRange,
  ValueChanged<StatsRange>? onChanged,
  VoidCallback? onPickCustom,
  double textScale = 1,
}) {
  return MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.pageGutter),
        child: Align(
          alignment: Alignment.topCenter,
          child: StatsRangeSelector(
            selected: selected,
            customRange: customRange,
            onChanged: onChanged ?? (_) {},
            onPickCustom: onPickCustom ?? () {},
          ),
        ),
      ),
    ),
  );
}

Future<void> _pump(
  WidgetTester tester, {
  StatsRange selected = StatsRange.month,
  StatsDateRange? customRange,
  ValueChanged<StatsRange>? onChanged,
  VoidCallback? onPickCustom,
  double textScale = 1,
}) async {
  _phoneView(tester);
  await tester.pumpWidget(
    _app(
      selected: selected,
      customRange: customRange,
      onChanged: onChanged,
      onPickCustom: onPickCustom,
      textScale: textScale,
    ),
  );
  await tester.pumpAndSettle();
}

/// Kolor tła opcji pigułki: kolor główny = podświetlona.
Color? _presetFill(WidgetTester tester, String label) {
  final option = tester.widget<AnimatedContainer>(
    find.ancestor(
      of: find.text(label),
      matching: find.byType(AnimatedContainer),
    ),
  );
  return (option.decoration! as BoxDecoration).color;
}

Color? _calendarFill(WidgetTester tester) {
  final button = tester.widget<AnimatedContainer>(
    find.descendant(
      of: find.byKey(_calendarKey),
      matching: find.byType(AnimatedContainer),
    ),
  );
  return (button.decoration! as BoxDecoration).color;
}

void main() {
  final range = StatsDateRange(DateTime(2026, 9, 12), DateTime(2026, 10, 2));

  group('StatsRangeSelector', () {
    testWidgets('tapping a preset reports it', (tester) async {
      final changes = <StatsRange>[];
      await _pump(tester, onChanged: changes.add);

      await tester.tap(find.text('7 dni'));
      await tester.tap(find.text('3 mies.'));
      await tester.tap(find.text('Rok'));
      await tester.tap(find.text('Całość'));

      expect(changes, [
        StatsRange.week,
        StatsRange.quarter,
        StatsRange.year,
        StatsRange.all,
      ]);
    });

    testWidgets('tapping the already selected preset does nothing', (
      tester,
    ) async {
      final changes = <StatsRange>[];
      await _pump(tester, onChanged: changes.add);

      await tester.tap(find.text('30 dni'));

      expect(changes, isEmpty);
    });

    testWidgets('highlights only the selected preset', (tester) async {
      await _pump(tester, selected: StatsRange.quarter);

      expect(_presetFill(tester, '3 mies.'), AppColors.primary);
      for (final label in ['7 dni', '30 dni', 'Rok', 'Całość']) {
        expect(_presetFill(tester, label), Colors.transparent, reason: label);
      }
      expect(_calendarFill(tester), AppColors.surface);
    });

    testWidgets('calendar button asks to pick a custom range', (tester) async {
      var picks = 0;
      final changes = <StatsRange>[];
      await _pump(tester, onChanged: changes.add, onPickCustom: () => picks++);

      await tester.tap(find.byIcon(Icons.date_range_rounded));

      expect(picks, 1);
      expect(changes, isEmpty);
    });

    testWidgets('calendar button stays usable in custom mode', (tester) async {
      var picks = 0;
      await _pump(
        tester,
        selected: StatsRange.custom,
        customRange: range,
        onPickCustom: () => picks++,
      );

      await tester.tap(find.byKey(_calendarKey));

      expect(picks, 1);
    });

    testWidgets('custom range: no preset highlighted, calendar filled, chip', (
      tester,
    ) async {
      await _pump(tester, selected: StatsRange.custom, customRange: range);

      for (final preset in StatsRange.presets) {
        expect(
          _presetFill(tester, preset.label),
          Colors.transparent,
          reason: preset.label,
        );
      }
      expect(_calendarFill(tester), AppColors.primary);
      expect(find.text('12 wrz – 2 paź 2026'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });

    testWidgets('no chip without custom range or outside custom mode', (
      tester,
    ) async {
      await _pump(tester, selected: StatsRange.custom);
      expect(find.byIcon(Icons.close_rounded), findsNothing);

      // Zapamiętane daty nie powinny wisieć pod paskiem przy innym zakresie.
      await tester.pumpWidget(_app(customRange: range));
      await tester.pumpAndSettle();
      expect(find.text('12 wrz – 2 paź 2026'), findsNothing);
      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });

    testWidgets('chip appears and disappears with the mode', (tester) async {
      await _pump(tester, customRange: range);
      final collapsed = tester.getSize(find.byType(StatsRangeSelector)).height;
      expect(collapsed, 40);

      await tester.pumpWidget(
        _app(selected: StatsRange.custom, customRange: range),
      );
      await tester.pumpAndSettle();
      expect(find.text('12 wrz – 2 paź 2026'), findsOneWidget);
      expect(
        tester.getSize(find.byType(StatsRangeSelector)).height,
        greaterThan(collapsed),
      );

      await tester.pumpWidget(_app(customRange: range));
      await tester.pumpAndSettle();
      expect(find.text('12 wrz – 2 paź 2026'), findsNothing);
      expect(tester.getSize(find.byType(StatsRangeSelector)).height, collapsed);
    });

    testWidgets('close button leaves custom mode for the month preset', (
      tester,
    ) async {
      final changes = <StatsRange>[];
      var picks = 0;
      await _pump(
        tester,
        selected: StatsRange.custom,
        customRange: range,
        onChanged: changes.add,
        onPickCustom: () => picks++,
      );

      await tester.tap(find.byIcon(Icons.close_rounded));

      expect(changes, [StatsRange.month]);
      expect(picks, 0);
    });

    testWidgets('tapping the chip text reopens the calendar', (tester) async {
      final changes = <StatsRange>[];
      var picks = 0;
      await _pump(
        tester,
        selected: StatsRange.custom,
        customRange: range,
        onChanged: changes.add,
        onPickCustom: () => picks++,
      );

      await tester.tap(find.text('12 wrz – 2 paź 2026'));

      expect(picks, 1);
      expect(changes, isEmpty);
    });

    testWidgets('a preset chosen in custom mode is reported', (tester) async {
      final changes = <StatsRange>[];
      await _pump(
        tester,
        selected: StatsRange.custom,
        customRange: range,
        onChanged: changes.add,
      );

      await tester.tap(find.text('30 dni'));

      expect(changes, [StatsRange.month]);
    });

    testWidgets('exposes button semantics with actions', (tester) async {
      final semantics = tester.ensureSemantics();
      var picks = 0;
      final changes = <StatsRange>[];
      await _pump(
        tester,
        selected: StatsRange.custom,
        customRange: range,
        onChanged: changes.add,
        onPickCustom: () => picks++,
      );

      // Prawdziwa akcja semantyczna (jak z czytnika ekranu), nie dotyk
      // w środek węzła — ten drugi przechodzi także bez `onTap` w Semantics.
      Future<void> tapBySemantics(String label) async {
        final node = find.semantics.byLabel(label);
        expect(
          node.evaluate().single.getSemanticsData().hasAction(
            SemanticsAction.tap,
          ),
          isTrue,
          reason: label,
        );
        tester.semantics.performAction(node, SemanticsAction.tap);
        await tester.pump();
      }

      await tapBySemantics('Wybierz własny zakres dat');
      expect(picks, 1);

      await tapBySemantics('Zakres 7 dni');
      expect(changes, [StatsRange.week]);

      await tapBySemantics('Wyjdź z własnego zakresu dat');
      expect(changes, [StatsRange.week, StatsRange.month]);

      expect(
        find.bySemanticsLabel(
          'Zakres od 12 września 2026 do 2 października 2026, zmień',
        ),
        findsOneWidget,
      );
      semantics.dispose();
    });

    group('fits a 360 dp phone', () {
      final longRange = StatsDateRange(
        DateTime(2025, 12, 20),
        DateTime(2026, 10, 2),
      );

      for (final scale in [1.0, 1.3, 2.0]) {
        for (final selected in [StatsRange.month, StatsRange.custom]) {
          testWidgets('${selected.name} at text scale $scale', (tester) async {
            await _pump(
              tester,
              selected: selected,
              customRange: longRange,
              textScale: scale,
            );

            expect(tester.takeException(), isNull);
            // Prawa krawędź przycisku kalendarza = prawy margines ekranu.
            expect(tester.getTopRight(find.byKey(_calendarKey)).dx, 344);
            expect(
              tester.getSize(find.byKey(_calendarKey)),
              const Size(40, 40),
            );
            if (selected == StatsRange.custom) {
              final chip = tester.getRect(find.byIcon(Icons.close_rounded));
              expect(chip.right, lessThanOrEqualTo(344));
            }
            for (final preset in StatsRange.presets) {
              final label = find.text(preset.label);
              expect(label, findsOneWidget);
              // Etykieta ma się skalować w dół, a nie ucinać się do „3”.
              expect(
                tester.renderObject<RenderParagraph>(label).didExceedMaxLines,
                isFalse,
                reason: preset.label,
              );
              final option = tester.getRect(
                find.ancestor(
                  of: label,
                  matching: find.byType(AnimatedContainer),
                ),
              );
              expect(
                tester.getTopLeft(label).dx,
                greaterThanOrEqualTo(option.left - 0.01),
                reason: preset.label,
              );
              expect(
                tester.getBottomRight(label).dx,
                lessThanOrEqualTo(option.right + 0.01),
                reason: preset.label,
              );
            }
          });
        }
      }
    });
  });

  group('formatStatsDateRange', () {
    test('year once at the end within one year', () {
      expect(formatStatsDateRange(range), '12 wrz – 2 paź 2026');
    });

    test('each date carries its year across a year boundary', () {
      final crossing = StatsDateRange(
        DateTime(2025, 12, 20),
        DateTime(2026, 1, 5),
      );
      expect(formatStatsDateRange(crossing), '20 gru 2025 – 5 sty 2026');
    });

    test('single day is one date', () {
      final day = StatsDateRange(DateTime(2026, 10, 2), DateTime(2026, 10, 2));
      expect(formatStatsDateRange(day), '2 paź 2026');
    });
  });

  group('pickStatsDateRange', () {
    final first = DateTime(2026, 9, 1);
    final last = DateTime(2026, 9, 30);

    StatsDateRange? result;
    var finished = false;

    setUp(() {
      result = null;
      finished = false;
    });

    Future<void> openPicker(
      WidgetTester tester, {
      StatsDateRange? initial,
      bool polish = true,
    }) async {
      if (initial != null) {
        _phoneView(tester);
      } else {
        // Bez zaznaczenia nagłówek kalendarza pokazuje „Data początkowa”,
        // której framework nie skraca. W testach czcionka (Ahem) jest
        // szeroka i na 360 dp etykieta wylewa się z wiersza, choć na
        // urządzeniu się mieści — tu wystarczy więc większy ekran.
        tester.view.physicalSize = const Size(800, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
      }
      await tester.pumpWidget(
        MaterialApp(
          locale: polish ? AppLocalization.locale : null,
          supportedLocales: polish
              ? AppLocalization.supportedLocales
              : const [Locale('en', 'US')],
          localizationsDelegates: polish ? AppLocalization.delegates : null,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    result = await pickStatsDateRange(
                      context,
                      initial: initial,
                      firstDate: first,
                      lastDate: last,
                    );
                    finished = true;
                  },
                  child: const Text('Otwórz'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Otwórz'));
      await tester.pumpAndSettle();
    }

    testWidgets('returns the chosen days after confirming', (tester) async {
      await openPicker(tester);
      expect(find.byType(DateRangePickerDialog), findsOneWidget);
      expect(find.text('Wybierz zakres'), findsOneWidget);

      await tester.tap(find.text('15'));
      await tester.pump();
      await tester.tap(find.text('20'));
      await tester.pump();
      await tester.tap(find.text('Zastosuj'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(finished, isTrue);
      expect(
        result,
        StatsDateRange(DateTime(2026, 9, 15), DateTime(2026, 9, 20)),
      );
      expect(find.byType(DateRangePickerDialog), findsNothing);
    });

    testWidgets('a single tapped day twice is a one-day range', (tester) async {
      await openPicker(tester);

      await tester.tap(find.text('15'));
      await tester.pump();
      await tester.tap(find.text('15'));
      await tester.pump();
      await tester.tap(find.text('Zastosuj'));
      await tester.pumpAndSettle();

      expect(
        result,
        StatsDateRange(DateTime(2026, 9, 15), DateTime(2026, 9, 15)),
      );
      expect(result!.days, 1);
    });

    testWidgets('returns null when cancelled', (tester) async {
      await openPicker(tester);

      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();

      expect(finished, isTrue);
      expect(result, isNull);
      expect(find.byType(DateRangePickerDialog), findsNothing);
    });

    testWidgets('starts from the initial range', (tester) async {
      final initial = StatsDateRange(
        DateTime(2026, 9, 10),
        DateTime(2026, 9, 12),
      );
      await openPicker(tester, initial: initial);

      await tester.tap(find.text('Zastosuj'));
      await tester.pumpAndSettle();

      expect(result, initial);
    });

    testWidgets('clamps an initial range that sticks out of the bounds', (
      tester,
    ) async {
      await openPicker(
        tester,
        initial: StatsDateRange(DateTime(2026, 8, 20), DateTime(2026, 10, 10)),
      );

      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Zastosuj'));
      await tester.pumpAndSettle();

      expect(result, StatsDateRange(first, last));
    });

    testWidgets('clamps an initial range entirely after the bounds', (
      tester,
    ) async {
      await openPicker(
        tester,
        initial: StatsDateRange(DateTime(2027, 1, 5), DateTime(2027, 1, 9)),
      );

      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Zastosuj'));
      await tester.pumpAndSettle();

      expect(result, StatsDateRange(last, last));
    });

    testWidgets('uses the app dark palette', (tester) async {
      await openPicker(tester);

      final theme = Theme.of(
        tester.element(find.byType(DateRangePickerDialog)),
      );
      expect(theme.colorScheme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, AppColors.primary);
      expect(theme.colorScheme.surface, AppColors.surface);
      // Środek zakresu nie może dziedziczyć jaskrawego `secondaryContainer`.
      expect(
        theme.datePickerTheme.rangeSelectionBackgroundColor,
        isNot(theme.colorScheme.secondaryContainer),
      );
    });

    testWidgets('opens without Polish delegates', (tester) async {
      await openPicker(tester, polish: false);

      expect(tester.takeException(), isNull);
      expect(find.byType(DateRangePickerDialog), findsOneWidget);
      expect(find.text('Zastosuj'), findsOneWidget);
    });
  });
}
