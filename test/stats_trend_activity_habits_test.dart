import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gym/features/training/domain/models/training_session.dart';
import 'package:gym/features/training/domain/models/training_stats.dart';
import 'package:gym/features/training/domain/services/stats/training_stats_calculator.dart';
import 'package:gym/features/training/presentation/widgets/stats/stats_activity_card.dart';
import 'package:gym/features/training/presentation/widgets/stats/stats_habits_card.dart';
import 'package:gym/features/training/presentation/widgets/stats/stats_trend_chart_card.dart';

/// Środa 16 września 2026, 12:00.
final _now = DateTime(2026, 9, 16, 12);

TrainingSession _session(
  DateTime startLocal, {
  int sets = 3,
  String weight = '80',
  String? rir = '2',
  Duration duration = const Duration(minutes: 45),
}) {
  return TrainingSession(
    planName: 'Push',
    status: TrainingSessionStatus.completed,
    startedAt: startLocal.toUtc(),
    finishedAt: startLocal.add(duration).toUtc(),
    exercises: [
      TrainingSessionExercise(
        exerciseId: 'bench',
        exerciseName: 'Wyciskanie',
        exerciseMuscles: const ['chest'],
        exerciseCategory: 'compound',
        sets: [
          for (var i = 0; i < sets; i++)
            TrainingSessionSet(
              actualWeight: weight,
              actualReps: '10',
              actualRir: rir,
              completed: true,
            ),
        ],
      ),
    ],
  );
}

final _sessions = [
  _session(DateTime(2026, 9, 16, 8), sets: 4), // śr, rano
  _session(DateTime(2026, 9, 14, 18), sets: 2), // pn, wieczór
  _session(DateTime(2026, 9, 9, 18)), // śr
  _session(DateTime(2026, 9, 2, 18), sets: 6), // śr
  _session(DateTime(2026, 8, 20, 13)), // cz, w dzień
  _session(DateTime(2026, 7, 1, 18)),
];

TrainingStatsSnapshot _snapshot(
  StatsRange range, [
  List<TrainingSession>? sessions,
]) => TrainingStatsCalculator.compute(
  sessions ?? _sessions,
  range: range,
  now: _now,
);

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  group('StatsTrendChartCard', () {
    testWidgets('shows volume summary and switches metrics', (tester) async {
      await _pump(
        tester,
        StatsTrendChartCard(snapshot: _snapshot(StatsRange.month)),
      );

      expect(find.text('Przebieg w czasie'), findsOneWidget);
      expect(find.byType(BarChart), findsOneWidget);
      // 30 dni: 5 treningów, 18 serii × 800 kg, 5 × 45 min.
      expect(find.text('14,4 t'), findsOneWidget);
      expect(find.text('łącznie podniesione'), findsOneWidget);
      expect(find.text('śr. 480 kg / dzień'), findsOneWidget);
      expect(find.textContaining('średnia krocząca'), findsOneWidget);

      await tester.tap(find.text('Serie'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('14,4 t'), findsNothing);
      expect(find.text('18'), findsOneWidget);
      expect(find.text('serii łącznie'), findsOneWidget);
      expect(find.text('śr. 0,6 / dzień'), findsOneWidget);

      await tester.tap(find.text('Treningi'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('5'), findsOneWidget);
      expect(find.text('treningów łącznie'), findsOneWidget);

      await tester.tap(find.text('Czas'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('3 h 45 min'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders every range without overflow', (tester) async {
      for (final range in StatsRange.values) {
        await _pump(tester, StatsTrendChartCard(snapshot: _snapshot(range)));
        expect(find.byType(BarChart), findsOneWidget, reason: '$range');
        expect(tester.takeException(), isNull, reason: '$range');
      }
    });

    testWidgets('all-zero series shows empty chart and a note', (tester) async {
      // Historia jest, ale w ostatnich 7 dniach nic.
      final snapshot = _snapshot(StatsRange.week, [
        _session(DateTime(2026, 3, 1, 18)),
      ]);
      expect(snapshot.series.every((p) => p.workouts == 0), isTrue);

      await _pump(tester, StatsTrendChartCard(snapshot: snapshot));

      expect(find.text('Brak danych w tym okresie'), findsOneWidget);
      expect(find.text('0 kg'), findsOneWidget);
      final chart = tester.widget<BarChart>(find.byType(BarChart));
      expect(chart.data.maxY, greaterThan(0));
      // Bez danych nie ma czego uśredniać — ani linii, ani legendy.
      expect(find.byType(LineChart), findsNothing);
      expect(find.textContaining('średnia krocząca'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('duration axis uses minutes below two hours', (tester) async {
      await _pump(
        tester,
        StatsTrendChartCard(snapshot: _snapshot(StatsRange.month)),
      );
      await tester.tap(find.text('Czas'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining(RegExp(r'^\d+,\d h$')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('StatsActivityCard', () {
    testWidgets('shows summary and selected day details', (tester) async {
      final snapshot = _snapshot(StatsRange.month);
      await _pump(tester, StatsActivityCard(activity: snapshot.activity));

      expect(find.text('Aktywność'), findsOneWidget);
      expect(find.text('mniej'), findsOneWidget);
      expect(find.text('więcej'), findsOneWidget);
      expect(find.text('Pn'), findsOneWidget);
      expect(find.text('wrz'), findsOneWidget);
      expect(
        find.text('6 dni treningowych w ostatnich 12 tyg.'),
        findsOneWidget,
      );

      // Ostatnia kolumna, wiersz środy (indeks 2) — dzisiejszy trening.
      final grid = find.byKey(const ValueKey('stats-activity-grid'));
      final rect = tester.getRect(grid);
      final weeks = snapshot.activity.weeks;
      final pitch = _pitch(rect, weeks);
      await tester.tapAt(
        rect.topLeft + Offset((weeks - 1) * pitch + 2, 2 * pitch + 2),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Śr, 16 wrz · 1 trening · 4 serie'), findsOneWidget);

      // Wtorek bez treningu.
      await tester.tapAt(
        rect.topLeft + Offset((weeks - 1) * pitch + 2, 1 * pitch + 2),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Wt, 15 wrz · brak treningu'), findsOneWidget);

      // Przyszły dzień (sobota) nie zmienia zaznaczenia.
      await tester.tapAt(
        rect.topLeft + Offset((weeks - 1) * pitch + 2, 5 * pitch + 2),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Wt, 15 wrz · brak treningu'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    group('day drill-down', () {
      // Dzisiejsza środa 16.09: dwa treningi (08:00 i 11:30), a wtorek pusty.
      final sessions = [
        _session(DateTime(2026, 9, 16, 11, 30), sets: 2).copyWith(
          id: 'late',
          planName:
              'Nogi z bardzo długą nazwą planu, która nie mieści się w jednym wierszu',
        ),
        _session(DateTime(2026, 9, 16, 8), sets: 4).copyWith(id: 'morning'),
        _session(DateTime(2026, 9, 9, 18)).copyWith(id: 'older'),
      ];

      Future<void> tapToday(WidgetTester tester, StatsActivity activity) async {
        final rect = tester.getRect(
          find.byKey(const ValueKey('stats-activity-grid')),
        );
        final pitch = _pitch(rect, activity.weeks);
        await tester.tapAt(
          rect.topLeft +
              Offset((activity.weeks - 1) * pitch + 2, 2 * pitch + 2),
        );
        // AnimatedSize startuje dopiero po układzie — czekamy na koniec animacji.
        await tester.pumpAndSettle();
      }

      testWidgets('lists sessions of the selected day, earliest first', (
        tester,
      ) async {
        final snapshot = _snapshot(StatsRange.month, sessions);
        await _pump(tester, StatsActivityCard(activity: snapshot.activity));

        // Bez zaznaczenia nie ma listy sesji.
        expect(
          find.byKey(const ValueKey('stats-activity-session-morning')),
          findsNothing,
        );

        await tapToday(tester, snapshot.activity);

        expect(find.text('Śr, 16 wrz · 2 treningi · 6 serii'), findsOneWidget);
        final morning = find.byKey(
          const ValueKey('stats-activity-session-morning'),
        );
        final late = find.byKey(const ValueKey('stats-activity-session-late'));
        expect(morning, findsOneWidget);
        expect(late, findsOneWidget);
        expect(find.text('08:00'), findsOneWidget);
        expect(find.text('11:30'), findsOneWidget);
        expect(find.text('Push'), findsOneWidget);
        expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(2));
        expect(
          tester.getTopLeft(morning).dy,
          lessThan(tester.getTopLeft(late).dy),
        );

        // Długa nazwa jest przycięta, a karta mieści się w 360 px.
        final card = tester.getRect(find.byType(StatsActivityCard));
        expect(card.right, lessThanOrEqualTo(360 - 16));
        expect(tester.takeException(), isNull);

        // Drugie stuknięcie odznacza dzień i chowa listę.
        await tapToday(tester, snapshot.activity);
        expect(morning, findsNothing);
        expect(late, findsNothing);
      });

      testWidgets('day without sessions shows only the summary line', (
        tester,
      ) async {
        final snapshot = _snapshot(StatsRange.month, sessions);
        await _pump(tester, StatsActivityCard(activity: snapshot.activity));

        final rect = tester.getRect(
          find.byKey(const ValueKey('stats-activity-grid')),
        );
        final pitch = _pitch(rect, snapshot.activity.weeks);
        await tester.tapAt(
          rect.topLeft +
              Offset((snapshot.activity.weeks - 1) * pitch + 2, 1 * pitch + 2),
        );
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Wt, 15 wrz · brak treningu'), findsOneWidget);
        expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
      });

      testWidgets('tapping a row without a router does not throw', (
        tester,
      ) async {
        final snapshot = _snapshot(StatsRange.month, sessions);
        await _pump(tester, StatsActivityCard(activity: snapshot.activity));
        await tapToday(tester, snapshot.activity);

        await tester.tap(
          find.byKey(const ValueKey('stats-activity-session-morning')),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
      });

      testWidgets('row exposes a tap action and opens the session', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final snapshot = _snapshot(StatsRange.month, sessions);
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: StatsActivityCard(activity: snapshot.activity),
                ),
              ),
            ),
            GoRoute(
              path: '/app/training/history/:id',
              builder: (_, state) =>
                  Text('session ${state.pathParameters['id']}'),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          MaterialApp.router(theme: ThemeData.dark(), routerConfig: router),
        );
        await tester.pump(const Duration(milliseconds: 400));
        await tapToday(tester, snapshot.activity);

        final row = find.semantics.byLabel(RegExp('^11:30, Nogi'));
        final data = row.evaluate().single.getSemanticsData();
        expect(data.hasAction(SemanticsAction.tap), isTrue);
        expect(data.flagsCollection.isButton, isTrue);

        tester.semantics.performAction(row, SemanticsAction.tap);
        await tester.pumpAndSettle();

        expect(find.text('session late'), findsOneWidget);
        semantics.dispose();
      });
    });

    testWidgets('fits 26 weeks at 360 px', (tester) async {
      final sessions = [
        for (var i = 0; i < 200; i += 3)
          _session(DateTime(2026, 9, 16 - i, 18), sets: 1 + i % 7),
      ];
      final snapshot = _snapshot(StatsRange.all, sessions);
      expect(snapshot.activity.weeks, 26);

      await _pump(tester, StatsActivityCard(activity: snapshot.activity));

      final grid = tester.getRect(
        find.byKey(const ValueKey('stats-activity-grid')),
      );
      expect(grid.right, lessThanOrEqualTo(360 - 32));
      expect(grid.width / 26, greaterThanOrEqualTo(6));
      expect(tester.takeException(), isNull);
    });
  });

  group('StatsHabitsCard', () {
    testWidgets('shows weekdays, time of day and metrics', (tester) async {
      final snapshot = _snapshot(StatsRange.month);
      await _pump(tester, StatsHabitsCard(habits: snapshot.habits));

      expect(find.text('Nawyki treningowe'), findsOneWidget);
      expect(find.text('najczęściej: środa'), findsOneWidget);
      expect(find.text('najczęściej: wieczorem'), findsOneWidget);
      for (final label in ['Pn', 'Wt', 'Śr', 'Cz', 'Pt', 'So', 'Nd']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('Rano'), findsOneWidget);
      expect(find.text('Nocą'), findsOneWidget);
      // 5 treningów: 1 rano, 1 w dzień, 3 wieczorem.
      expect(find.text('60%'), findsOneWidget);
      expect(find.text('20%'), findsNWidgets(2));
      expect(find.text('0%'), findsOneWidget);
      expect(find.text('Śr. czas sesji'), findsOneWidget);
      expect(find.text('45 min'), findsOneWidget);
      expect(find.text('Serie / trening'), findsOneWidget);
      expect(find.text('3,6'), findsOneWidget);
      expect(find.text('Śr. RIR'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Treningi / tydz.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty habits show dashes', (tester) async {
      await _pump(tester, const StatsHabitsCard(habits: TrainingHabits.empty));

      expect(find.text('—'), findsNWidgets(5));
      expect(find.textContaining('najczęściej'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}

/// Krok kratki (bok + szczelina) odczytany z wymiarów siatki:
/// szer. = w·c + (w-1)·g, wys. = 7·c + 6·g.
double _pitch(Rect grid, int weeks) {
  final gap = (7 * grid.width - weeks * grid.height) / (weeks - 7);
  final cell = (grid.height - 6 * gap) / 7;
  return cell + gap;
}
