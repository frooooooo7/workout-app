import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gym/core/theme/app_colors.dart';
import 'package:gym/features/training/domain/models/training_session.dart';
import 'package:gym/features/training/domain/models/training_stats.dart';
import 'package:gym/features/training/domain/services/stats/session_records_calculator.dart';
import 'package:gym/features/training/domain/services/stats/training_stats_calculator.dart';
import 'package:gym/features/training/domain/services/stats/weekly_goal_calculator.dart';
import 'package:gym/features/training/presentation/widgets/session_details/session_section_card.dart';
import 'package:gym/features/training/presentation/widgets/stats/stats_goal_card.dart';
import 'package:gym/features/training/presentation/widgets/stats/stats_insights_card.dart';
import 'package:gym/features/training/presentation/widgets/stats/stats_rep_ranges_card.dart';
import 'package:gym/features/training/presentation/widgets/stats/stats_session_records_card.dart';

/// Środa 16 września 2026, 12:00.
final _now = DateTime(2026, 9, 16, 12);

const _longPlan =
    'Trening siłowy całego ciała z akcentem na górę pleców i barki — wersja B';
const _longExercise =
    'Wyciskanie hantli na ławce skośnej głową w górę z pauzą na dole ruchu';

/// Środa 16 września: poniedziałek bieżącego tygodnia to 14 września.
WeeklyGoalProgress _goal({
  int goal = 4,
  int done = 3,
  int daysLeft = 4,
  int streak = 2,
  int best = 5,
  List<int> history = const [2, 4, 4, 1, 0, 4, 5],
}) {
  final counts = [...history, done];
  return WeeklyGoalProgress(
    goal: goal,
    workoutsThisWeek: done,
    weeks: [
      for (var i = 0; i < counts.length; i++)
        GoalWeek(
          start: DateTime(2026, 9, 14 - 7 * (counts.length - 1 - i)),
          workouts: counts[i],
        ),
    ],
    streakWeeks: streak,
    bestStreakWeeks: best,
    daysLeft: daysLeft,
  );
}

SessionRecord _record(
  SessionRecordKind kind,
  double value, {
  String id = 'session-1',
  String name = 'Push A',
  DateTime? date,
}) => SessionRecord(
  kind: kind,
  value: value,
  sessionId: id,
  name: name,
  date: date ?? DateTime(2026, 9, 1, 18),
);

SessionRecords _fullRecords() => SessionRecords(
  records: [
    _record(SessionRecordKind.volume, 8450, id: 'heavy', name: 'Nogi'),
    _record(
      SessionRecordKind.duration,
      95 * 60,
      id: 'long',
      name: 'Push A',
      date: DateTime(2026, 9, 8, 18),
    ),
    _record(
      SessionRecordKind.sets,
      27,
      id: 'sets',
      name: 'Pull B',
      date: DateTime(2026, 8, 20, 7),
    ),
  ],
  bestWeek: BestWeek(
    start: DateTime(2026, 8, 31),
    volumeKg: 31200,
    workouts: 4,
  ),
);

Future<void> _pump(
  WidgetTester tester,
  Widget card, {
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: card,
        ),
      ),
    ),
  );
  // Animacje wejścia (pierścień, słupki) mają do 650 ms.
  await tester.pump(const Duration(milliseconds: 800));
}

/// Karta na routerze — dotknięcie otwiera trasę ćwiczenia albo sesji.
Future<void> _pumpRouted(WidgetTester tester, Widget card) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: card,
          ),
        ),
      ),
      GoRoute(
        path: '/app/exercises/:id',
        builder: (_, state) => Text('exercise ${state.pathParameters['id']}'),
      ),
      GoRoute(
        path: '/app/training/history/:id',
        builder: (_, state) => Text('session ${state.pathParameters['id']}'),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(theme: ThemeData.dark(), routerConfig: router),
  );
  await tester.pump(const Duration(milliseconds: 800));
}

/// Tekst z wieloma spanami (`Text.rich`) — zwykłe `find.text` go nie widzi.
Finder _rich(String text) => find.text(text, findRichText: true);

SemanticsData _semanticsOf(Pattern label) =>
    find.semantics.byLabel(label).evaluate().single.getSemanticsData();

bool _canTap(Pattern label) =>
    _semanticsOf(label).hasAction(SemanticsAction.tap);

TrainingSessionExercise _exercise(
  String id,
  String name,
  List<TrainingSessionSet> sets, {
  List<String> muscles = const ['chest'],
}) => TrainingSessionExercise(
  exerciseId: id,
  exerciseName: name,
  exerciseMuscles: muscles,
  exerciseCategory: 'compound',
  sets: sets,
);

TrainingSessionSet _set(String weight, String reps) =>
    TrainingSessionSet(actualWeight: weight, actualReps: reps, completed: true);

TrainingSession _session(
  DateTime startLocal,
  List<TrainingSessionExercise> exercises, {
  String name = 'Push',
  Duration duration = const Duration(hours: 1),
}) => TrainingSession(
  planName: name,
  status: TrainingSessionStatus.completed,
  startedAt: startLocal.toUtc(),
  finishedAt: startLocal.add(duration).toUtc(),
  exercises: exercises,
);

void main() {
  group('StatsGoalCard', () {
    testWidgets('shows progress, status and history for an open week', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, StatsGoalCard(goal: _goal()));

      expect(find.text('Cel tygodnia'), findsOneWidget);
      expect(_rich('3 / 4'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
      expect(find.text('Brakuje 1 treningu'), findsOneWidget);
      // Cztery dni po dzisiejszym plus dziś.
      expect(find.text('do końca tygodnia: 5 dni'), findsOneWidget);
      expect(find.text('Cel wykonany'), findsNothing);
      expect(
        find.text('Cel w tym tygodniu jest już poza zasięgiem'),
        findsNothing,
      );

      expect(find.text('cel: 4 / tydz.'), findsOneWidget);
      expect(find.text('Wykonany w 4 z 8 ostatnich tygodni'), findsOneWidget);
      expect(_rich('Seria celu: 2 tyg.'), findsOneWidget);
      expect(find.text('najdłuższa: 5 tyg.'), findsOneWidget);

      // Czytnik ekranu dostaje liczby zamiast dekoracji.
      expect(find.semantics.byLabel('3 z 4 treningów'), findsOneWidget);
      final chart = _semanticsOf(RegExp('^Treningi w ostatnich tygodniach'));
      expect(chart.label, contains('cel 4'));
      expect(chart.label, contains('Tydzień od 14 wrz: 3'));
      expect(chart.label, contains('Tydzień od 27 lip: 2'));

      expect(tester.takeException(), isNull);
      handle.dispose();
    });

    testWidgets('label of every second week, counted from the current one', (
      tester,
    ) async {
      await _pump(tester, StatsGoalCard(goal: _goal()));

      for (final shown in ['14 wrz', '31 sie', '17 sie', '3 sie']) {
        expect(find.text(shown), findsOneWidget, reason: shown);
      }
      for (final hidden in ['7 wrz', '24 sie', '10 sie', '27 lip']) {
        expect(find.text(hidden), findsNothing, reason: hidden);
      }
    });

    testWidgets('met goal: success wording and a tick instead of percent', (
      tester,
    ) async {
      await _pump(tester, StatsGoalCard(goal: _goal(done: 4)));

      expect(_rich('4 / 4'), findsOneWidget);
      expect(find.text('Cel wykonany'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.textContaining('Brakuje'), findsNothing);
      expect(find.textContaining('%'), findsNothing);
      expect(find.text('Wykonany w 5 z 8 ostatnich tygodni'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a goal exceeded still reads as met', (tester) async {
      await _pump(tester, StatsGoalCard(goal: _goal(done: 6)));

      expect(_rich('6 / 4'), findsOneWidget);
      expect(find.text('Cel wykonany'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('"brakuje" uses the genitive plural forms', (tester) async {
      // Nagłówek nie zależy od tego, czy cel jest jeszcze w zasięgu.
      const cases = {
        13: 'Brakuje 1 treningu',
        12: 'Brakuje 2 treningów',
        10: 'Brakuje 4 treningów',
        9: 'Brakuje 5 treningów',
        0: 'Brakuje 14 treningów',
      };
      for (final entry in cases.entries) {
        await _pump(
          tester,
          StatsGoalCard(goal: _goal(goal: 14, done: entry.key, daysLeft: 6)),
        );
        expect(find.text(entry.value), findsOneWidget, reason: entry.value);
      }
    });

    testWidgets('last day of the week and an unreachable goal', (tester) async {
      await _pump(tester, StatsGoalCard(goal: _goal(done: 3, daysLeft: 0)));
      expect(find.text('Brakuje 1 treningu'), findsOneWidget);
      expect(find.text('dziś ostatni dzień'), findsOneWidget);
      expect(find.textContaining('do końca tygodnia'), findsNothing);

      // Brakują 3 treningi, a zostały dwa dni (jutro plus dziś).
      await _pump(tester, StatsGoalCard(goal: _goal(done: 1, daysLeft: 1)));
      expect(find.text('Brakuje 3 treningów'), findsOneWidget);
      expect(
        find.text('Cel w tym tygodniu jest już poza zasięgiem'),
        findsOneWidget,
      );
      expect(find.textContaining('do końca tygodnia'), findsNothing);
      expect(find.textContaining('dziś ostatni'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('is driven by the calculator output', (tester) async {
      final goal = WeeklyGoalCalculator.compute(
        [
          _session(DateTime(2026, 9, 14, 8), [
            _exercise('a', 'A', [_set('50', '8')]),
          ]),
          _session(DateTime(2026, 9, 15, 8), [
            _exercise('a', 'A', [_set('50', '8')]),
          ]),
          _session(DateTime(2026, 9, 8, 8), [
            _exercise('a', 'A', [_set('50', '8')]),
          ]),
        ],
        today: DateTime(2026, 9, 16),
        goal: 3,
      )!;
      await _pump(tester, StatsGoalCard(goal: goal));

      expect(_rich('2 / 3'), findsOneWidget);
      expect(find.text('Brakuje 1 treningu'), findsOneWidget);
      expect(find.text('do końca tygodnia: 5 dni'), findsOneWidget);
      expect(find.text('Wykonany w 0 z 8 ostatnich tygodni'), findsOneWidget);
      expect(find.text('14 wrz'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a history shorter than eight weeks and none at all', (
      tester,
    ) async {
      await _pump(tester, StatsGoalCard(goal: _goal(history: const [4])));
      expect(find.text('Wykonany w 1 z 2 ostatnich tygodni'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _pump(tester, StatsGoalCard(goal: _goal(history: const [])));
      expect(find.text('Wykonany w 0 z 1 ostatnich tygodni'), findsOneWidget);
      expect(tester.takeException(), isNull);

      const bare = WeeklyGoalProgress(
        goal: 3,
        workoutsThisWeek: 0,
        weeks: [],
        streakWeeks: 0,
        bestStreakWeeks: 0,
        daysLeft: 6,
      );
      await _pump(tester, const StatsGoalCard(goal: bare));
      expect(find.text('Ostatnie tygodnie'), findsNothing);
      expect(_rich('0 / 3'), findsOneWidget);
      expect(find.text('Brakuje 3 treningów'), findsOneWidget);
      expect(_rich('Seria celu: 0 tyg.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('fits 360 px at text scale 1.3 with big numbers', (
      tester,
    ) async {
      await _pump(
        tester,
        StatsGoalCard(
          goal: _goal(
            goal: 14,
            done: 12,
            daysLeft: 6,
            streak: 12,
            best: 24,
            history: const [14, 9, 20, 0, 14, 13, 14],
          ),
        ),
        textScale: 1.3,
      );

      expect(_rich('12 / 14'), findsOneWidget);
      expect(find.text('Brakuje 2 treningów'), findsOneWidget);
      expect(_rich('Seria celu: 12 tyg.'), findsOneWidget);
      expect(find.text('najdłuższa: 24 tyg.'), findsOneWidget);
      expect(find.text('14 wrz'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a huge week does not push bars outside the plot', (
      tester,
    ) async {
      await _pump(
        tester,
        StatsGoalCard(
          goal: _goal(goal: 2, done: 30, history: const [0, 1, 2, 3, 40, 2, 9]),
        ),
        textScale: 1.3,
      );

      // Słupki przekraczające cel rosną, ale nie wychodzą poza obszar wykresu.
      final bars = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).color == AppColors.success,
      );
      expect(bars, findsWidgets);
      for (final bar in bars.evaluate()) {
        final height = (bar.renderObject! as RenderBox).size.height;
        expect(height, lessThanOrEqualTo(64));
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('StatsSessionRecordsCard', () {
    testWidgets('lists the three session records and the best week', (
      tester,
    ) async {
      await _pump(tester, StatsSessionRecordsCard(records: _fullRecords()));

      expect(find.text('Rekordy sesji'), findsOneWidget);

      expect(find.text('Najcięższy trening'), findsOneWidget);
      expect(_rich('8 450 kg'), findsOneWidget);
      // Data idzie przed nazwą planu — to nazwa się skraca.
      expect(find.text('1 września 2026 · Nogi'), findsOneWidget);

      expect(find.text('Najdłuższy trening'), findsOneWidget);
      expect(_rich('1 h 35 min'), findsOneWidget);
      expect(find.text('8 września 2026 · Push A'), findsOneWidget);

      expect(find.text('Najwięcej serii'), findsOneWidget);
      expect(_rich('27 serii'), findsOneWidget);
      expect(find.text('20 sierpnia 2026 · Pull B'), findsOneWidget);

      expect(find.text('Najlepszy tydzień'), findsOneWidget);
      expect(_rich('31,2 t'), findsOneWidget);
      expect(find.text('4 treningi · tydz. od 31 sie'), findsOneWidget);

      // Chevron tylko przy rekordach, które da się otworzyć.
      expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(3));
      expect(
        find.text('Ukończ trening z ciężarami, aby zobaczyć rekordy sesji.'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('is driven by the calculator output', (tester) async {
      final records = SessionRecordsCalculator.compute([
        _session(
          DateTime(2026, 9, 1, 18),
          [
            _exercise('a', 'A', [_set('100', '10'), _set('100', '10')]),
          ],
          name: 'Ciężka',
          duration: const Duration(minutes: 50),
        ),
        _session(
          DateTime(2026, 9, 8, 18),
          [
            _exercise('a', 'A', [for (var i = 0; i < 5; i++) _set('20', '10')]),
          ],
          name: 'Długa',
          duration: const Duration(minutes: 95),
        ),
      ]);
      await _pump(tester, StatsSessionRecordsCard(records: records));

      expect(_rich('2 000 kg'), findsNWidgets(2)); // rekord i najlepszy tydzień
      expect(find.textContaining('· Ciężka'), findsOneWidget);
      expect(_rich('1 h 35 min'), findsOneWidget);
      expect(find.textContaining('· Długa'), findsNWidgets(2)); // czas i serie
      expect(_rich('5 serii'), findsOneWidget);
      expect(find.text('1 trening · tydz. od 31 sie'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('only rows with data are shown', (tester) async {
      await _pump(
        tester,
        StatsSessionRecordsCard(
          records: SessionRecords(
            records: [_record(SessionRecordKind.sets, 12)],
          ),
        ),
      );

      expect(find.text('Najwięcej serii'), findsOneWidget);
      expect(find.text('Najcięższy trening'), findsNothing);
      expect(find.text('Najdłuższy trening'), findsNothing);
      expect(find.text('Najlepszy tydzień'), findsNothing);
      expect(find.byType(Divider), findsNothing);

      await _pump(
        tester,
        StatsSessionRecordsCard(
          records: SessionRecords(
            bestWeek: BestWeek(
              start: DateTime(2026, 8, 31),
              volumeKg: 900,
              workouts: 2,
            ),
          ),
        ),
      );
      expect(find.text('Najlepszy tydzień'), findsOneWidget);
      expect(_rich('900 kg'), findsOneWidget);
      expect(find.text('2 treningi · tydz. od 31 sie'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty history shows a hint instead of rows', (tester) async {
      await _pump(
        tester,
        const StatsSessionRecordsCard(records: SessionRecords.empty),
      );

      expect(find.text('Rekordy sesji'), findsOneWidget);
      expect(
        find.text('Ukończ trening z ciężarami, aby zobaczyć rekordy sesji.'),
        findsOneWidget,
      );
      expect(find.textContaining('Najcięższy'), findsNothing);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('plural forms of sets and workouts', (tester) async {
      const sets = {1: '1 seria', 2: '2 serie', 5: '5 serii', 22: '22 serie'};
      for (final entry in sets.entries) {
        await _pump(
          tester,
          StatsSessionRecordsCard(
            records: SessionRecords(
              records: [_record(SessionRecordKind.sets, entry.key.toDouble())],
            ),
          ),
        );
        expect(_rich(entry.value), findsOneWidget, reason: entry.value);
      }

      const workouts = {
        1: '1 trening · tydz. od 31 sie',
        3: '3 treningi · tydz. od 31 sie',
        7: '7 treningów · tydz. od 31 sie',
      };
      for (final entry in workouts.entries) {
        await _pump(
          tester,
          StatsSessionRecordsCard(
            records: SessionRecords(
              bestWeek: BestWeek(
                start: DateTime(2026, 8, 31),
                volumeKg: 1500,
                workouts: entry.key,
              ),
            ),
          ),
        );
        expect(find.text(entry.value), findsOneWidget, reason: entry.value);
      }
    });

    testWidgets('session rows are buttons with a tap action, week is not', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, StatsSessionRecordsCard(records: _fullRecords()));

      for (final label in [
        RegExp('^Najcięższy trening, 8 450 kg, Nogi'),
        RegExp('^Najdłuższy trening, 1 h 35 min, Push A'),
        RegExp('^Najwięcej serii, 27 serii, Pull B'),
      ]) {
        expect(_canTap(label), isTrue, reason: '$label');
        expect(
          _semanticsOf(label).flagsCollection.isButton,
          isTrue,
          reason: '$label',
        );
      }
      final week = RegExp('^Najlepszy tydzień, 31,2 t, 4 treningi');
      expect(_canTap(week), isFalse);
      expect(_semanticsOf(week).flagsCollection.isButton, isFalse);

      handle.dispose();
    });

    testWidgets('tap and semantic tap open the session', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpRouted(
        tester,
        StatsSessionRecordsCard(
          records: SessionRecords(
            records: [
              _record(SessionRecordKind.volume, 5000, id: 'a/b c'),
              _record(SessionRecordKind.sets, 12, id: 'plain'),
            ],
          ),
        ),
      );

      // Id z ukośnikiem i spacją idzie w ścieżce zakodowane.
      await tester.tap(find.text('Najcięższy trening'));
      await tester.pumpAndSettle();
      expect(find.text('session a/b c'), findsOneWidget);

      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(find.text('Najwięcej serii'), findsOneWidget);

      tester.semantics.performAction(
        find.semantics.byLabel(RegExp('^Najwięcej serii')),
        SemanticsAction.tap,
      );
      await tester.pumpAndSettle();
      expect(find.text('session plain'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('long plan names ellipsize and never overflow', (tester) async {
      final records = SessionRecords(
        records: [
          _record(
            SessionRecordKind.volume,
            1234567,
            name: _longPlan,
            date: DateTime(2026, 10, 28),
          ),
          _record(
            SessionRecordKind.duration,
            3 * 3600 + 5 * 60,
            name: _longPlan,
          ),
          _record(SessionRecordKind.sets, 118, name: _longPlan),
        ],
        bestWeek: BestWeek(
          start: DateTime(2026, 10, 26),
          volumeKg: 1234567,
          workouts: 12,
        ),
      );
      for (final scale in [1.0, 1.3]) {
        await _pump(
          tester,
          StatsSessionRecordsCard(records: records),
          textScale: scale,
        );
        expect(find.textContaining(_longPlan), findsNWidgets(3));
        expect(_rich('1 234,6 t'), findsNWidgets(2));
        expect(_rich('3 h 05 min'), findsOneWidget);
        expect(_rich('118 serii'), findsOneWidget);
        expect(find.textContaining('28 października 2026'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'scale $scale');
      }
    });

    testWidgets('a session without a plan name shows only the date', (
      tester,
    ) async {
      await _pump(
        tester,
        StatsSessionRecordsCard(
          records: SessionRecords(
            records: [_record(SessionRecordKind.sets, 9, name: '  ')],
          ),
        ),
      );
      expect(find.text('1 września 2026'), findsOneWidget);
      expect(find.textContaining(' · '), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('StatsRepRangesCard', () {
    testWidgets('shows the split, legend rows and the dominant range', (
      tester,
    ) async {
      await _pump(
        tester,
        const StatsRepRangesCard(
          ranges: RepRangeDistribution(
            strength: 10,
            hypertrophy: 30,
            endurance: 10,
          ),
        ),
      );

      expect(find.text('Zakresy powtórzeń'), findsOneWidget);
      expect(_rich('Siła · 1–5'), findsOneWidget);
      expect(_rich('Masa · 6–12'), findsOneWidget);
      expect(_rich('Wytrzymałość · 13+'), findsOneWidget);
      expect(find.text('10 serii'), findsNWidgets(2));
      expect(find.text('30 serii'), findsOneWidget);
      expect(find.text('20%'), findsNWidgets(2));
      expect(find.text('60%'), findsOneWidget);
      expect(
        find.text('Najwięcej serii robisz w zakresie masy (6–12 powt.).'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('caption follows the dominant range', (tester) async {
      await _pump(
        tester,
        const StatsRepRangesCard(
          ranges: RepRangeDistribution(strength: 9, hypertrophy: 2),
        ),
      );
      expect(
        find.text('Najwięcej serii robisz w zakresie siły (1–5 powt.).'),
        findsOneWidget,
      );

      await _pump(
        tester,
        const StatsRepRangesCard(
          ranges: RepRangeDistribution(endurance: 7, hypertrophy: 2),
        ),
      );
      expect(
        find.text(
          'Najwięcej serii robisz w zakresie wytrzymałości (13+ powt.).',
        ),
        findsOneWidget,
      );
    });

    testWidgets('sets use polish plural forms', (tester) async {
      await _pump(
        tester,
        const StatsRepRangesCard(
          ranges: RepRangeDistribution(
            strength: 1,
            hypertrophy: 2,
            endurance: 5,
          ),
        ),
      );
      expect(find.text('1 seria'), findsOneWidget);
      expect(find.text('2 serie'), findsOneWidget);
      expect(find.text('5 serii'), findsOneWidget);

      await _pump(
        tester,
        const StatsRepRangesCard(
          ranges: RepRangeDistribution(
            strength: 22,
            hypertrophy: 12,
            endurance: 23,
          ),
        ),
      );
      expect(find.text('22 serie'), findsOneWidget);
      expect(find.text('12 serii'), findsOneWidget);
      expect(find.text('23 serie'), findsOneWidget);
    });

    testWidgets('percentages always add up to 100', (tester) async {
      // 1/3 każdy — bez korekty wyszłoby 99.
      await _pump(
        tester,
        const StatsRepRangesCard(
          ranges: RepRangeDistribution(
            strength: 1,
            hypertrophy: 1,
            endurance: 1,
          ),
        ),
      );
      expect(find.text('34%'), findsOneWidget);
      expect(find.text('33%'), findsNWidgets(2));

      // 1/8, 2/8, 5/8 — 12,5 / 25 / 62,5.
      await _pump(
        tester,
        const StatsRepRangesCard(
          ranges: RepRangeDistribution(
            strength: 1,
            hypertrophy: 2,
            endurance: 5,
          ),
        ),
      );
      expect(find.text('13%'), findsOneWidget);
      expect(find.text('25%'), findsOneWidget);
      expect(find.text('62%'), findsOneWidget);
    });

    testWidgets('a tiny share is "<1%", never a misleading zero', (
      tester,
    ) async {
      await _pump(
        tester,
        const StatsRepRangesCard(
          ranges: RepRangeDistribution(strength: 1, hypertrophy: 500),
        ),
      );
      expect(find.text('<1%'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      // Wytrzymałość bez serii to uczciwe 0%.
      expect(find.text('0%'), findsOneWidget);
      expect(find.text('0 serii'), findsOneWidget);
      // Nawet ułamek procenta dostaje widoczny odcinek.
      final strength = find.byWidgetPredicate(
        (w) => w is ColoredBox && w.color == AppColors.statPink,
      );
      expect(tester.getSize(strength).width, greaterThanOrEqualTo(3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('bar skips empty ranges and segments are proportional', (
      tester,
    ) async {
      Finder segment(Color color) =>
          find.byWidgetPredicate((w) => w is ColoredBox && w.color == color);

      await _pump(
        tester,
        const StatsRepRangesCard(
          ranges: RepRangeDistribution(strength: 10, hypertrophy: 30),
        ),
      );
      expect(segment(AppColors.statTeal), findsNothing);
      expect(segment(AppColors.statPink), findsOneWidget);
      expect(segment(AppColors.primaryVariant), findsOneWidget);

      final pink = tester.getSize(segment(AppColors.statPink)).width;
      final blue = tester.getSize(segment(AppColors.primaryVariant)).width;
      expect(blue / pink, closeTo(3, 0.01));

      // Przerwa 2 px między odcinkami; razem wypełniają całą szerokość.
      final pinkRect = tester.getRect(segment(AppColors.statPink));
      final blueRect = tester.getRect(segment(AppColors.primaryVariant));
      expect(blueRect.left - pinkRect.right, closeTo(2, 0.01));
    });

    testWidgets('no sets with reps gives a note and no legend', (tester) async {
      await _pump(
        tester,
        const StatsRepRangesCard(ranges: RepRangeDistribution.empty),
      );

      expect(find.text('Zakresy powtórzeń'), findsOneWidget);
      expect(
        find.text('Brak serii z podaną liczbą powtórzeń w tym okresie.'),
        findsOneWidget,
      );
      expect(find.textContaining('Siła'), findsNothing);
      expect(find.textContaining('Najwięcej serii robisz'), findsNothing);
      expect(find.textContaining('%'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('legend rows are read out with counts', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        const StatsRepRangesCard(
          ranges: RepRangeDistribution(
            strength: 10,
            hypertrophy: 30,
            endurance: 10,
          ),
        ),
      );
      expect(
        find.semantics.byLabel('Masa, powtórzenia 6–12: 30 serii, 60%'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('fits 360 px at text scale 1.3', (tester) async {
      await _pump(
        tester,
        const StatsRepRangesCard(
          ranges: RepRangeDistribution(
            strength: 1234,
            hypertrophy: 5678,
            endurance: 910,
          ),
        ),
        textScale: 1.3,
      );
      expect(_rich('Wytrzymałość · 13+'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('StatsInsightsCard', () {
    const insights = [
      StatsInsight(
        kind: StatsInsightKind.inactivity,
        tone: StatsInsightTone.attention,
        text: 'Ostatni trening był 9 dni temu. Wróć do rytmu.',
      ),
      StatsInsight(
        kind: StatsInsightKind.records,
        tone: StatsInsightTone.positive,
        text: 'Nowy rekord: Martwy ciąg.',
        exerciseId: 'deadlift',
      ),
      StatsInsight(
        kind: StatsInsightKind.volumeUp,
        tone: StatsInsightTone.positive,
        text: 'Objętość wzrosła o 25% względem poprzedniego okresu.',
      ),
    ];

    testWidgets('renders one row per insight under a titled card', (
      tester,
    ) async {
      await _pump(tester, const StatsInsightsCard(insights: insights));

      expect(find.text('Wnioski'), findsOneWidget);
      expect(find.byIcon(Icons.lightbulb_outline_rounded), findsOneWidget);
      for (final insight in insights) {
        expect(find.text(insight.text), findsOneWidget);
      }
      expect(find.byType(Divider), findsNWidgets(2));
      // Chevron tylko przy wniosku z ćwiczeniem.
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an empty list renders nothing', (tester) async {
      await _pump(tester, const StatsInsightsCard(insights: []));

      expect(find.byType(SessionSectionCard), findsNothing);
      expect(find.text('Wnioski'), findsNothing);
      expect(tester.getSize(find.byType(StatsInsightsCard)), Size.zero);
      expect(tester.takeException(), isNull);
    });

    testWidgets('every kind has its icon and every tone its tint', (
      tester,
    ) async {
      const icons = {
        StatsInsightKind.inactivity: Icons.hourglass_bottom_rounded,
        StatsInsightKind.goalMet: Icons.flag_rounded,
        StatsInsightKind.goalBehind: Icons.flag_outlined,
        StatsInsightKind.volumeUp: Icons.trending_up_rounded,
        StatsInsightKind.volumeDown: Icons.trending_down_rounded,
        StatsInsightKind.records: Icons.emoji_events_outlined,
        StatsInsightKind.plateau: Icons.horizontal_rule_rounded,
        StatsInsightKind.progress: Icons.show_chart_rounded,
        StatsInsightKind.neglected: Icons.warning_amber_rounded,
        StatsInsightKind.streak: Icons.local_fire_department_outlined,
      };
      expect(icons.keys.toSet(), StatsInsightKind.values.toSet());

      await _pump(
        tester,
        StatsInsightsCard(
          insights: [
            for (final kind in StatsInsightKind.values)
              StatsInsight(
                kind: kind,
                tone: StatsInsightTone.neutral,
                text: 'Wniosek ${kind.name}',
              ),
          ],
        ),
      );
      for (final entry in icons.entries) {
        expect(
          find.byIcon(entry.value),
          findsOneWidget,
          reason: '${entry.key}',
        );
      }

      Future<Color> tintFor(StatsInsightTone tone) async {
        await _pump(
          tester,
          StatsInsightsCard(
            insights: [
              StatsInsight(
                kind: StatsInsightKind.volumeUp,
                tone: tone,
                text: 'Wniosek',
              ),
            ],
          ),
        );
        return tester
            .widget<Icon>(find.byIcon(Icons.trending_up_rounded))
            .color!;
      }

      expect(await tintFor(StatsInsightTone.positive), AppColors.trendUp);
      expect(await tintFor(StatsInsightTone.attention), AppColors.statAmber);
      expect(await tintFor(StatsInsightTone.neutral), AppColors.primaryVariant);
    });

    testWidgets('only rows with a usable exercise id are tappable', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        const StatsInsightsCard(
          insights: [
            StatsInsight(
              kind: StatsInsightKind.plateau,
              tone: StatsInsightTone.attention,
              text: 'Wyciskanie: bez progresu od 5 treningów.',
              exerciseId: 'bench',
            ),
            StatsInsight(
              kind: StatsInsightKind.records,
              tone: StatsInsightTone.positive,
              text: 'Nowy rekord: Przysiad.',
              exerciseId: '  ',
            ),
            StatsInsight(
              kind: StatsInsightKind.streak,
              tone: StatsInsightTone.positive,
              text: 'Seria 5 tygodni z rzędu z treningiem.',
              exerciseId: '',
            ),
            StatsInsight(
              kind: StatsInsightKind.volumeDown,
              tone: StatsInsightTone.attention,
              text: 'Objętość spadła o 33% względem poprzedniego okresu.',
            ),
          ],
        ),
      );

      final tappable = _semanticsOf('Wyciskanie: bez progresu od 5 treningów.');
      expect(tappable.hasAction(SemanticsAction.tap), isTrue);
      expect(tappable.flagsCollection.isButton, isTrue);

      for (final label in [
        'Nowy rekord: Przysiad.',
        'Seria 5 tygodni z rzędu z treningiem.',
        'Objętość spadła o 33% względem poprzedniego okresu.',
      ]) {
        expect(_canTap(label), isFalse, reason: label);
        expect(_semanticsOf(label).flagsCollection.isButton, isFalse);
      }
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
      handle.dispose();
    });

    testWidgets('tap and semantic tap open the exercise', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpRouted(
        tester,
        const StatsInsightsCard(
          insights: [
            StatsInsight(
              kind: StatsInsightKind.plateau,
              tone: StatsInsightTone.attention,
              text: 'Wyciskanie: bez progresu od 5 treningów.',
              exerciseId: 'bench/1',
            ),
            StatsInsight(
              kind: StatsInsightKind.progress,
              tone: StatsInsightTone.positive,
              text: 'Przysiad: szacowane 1RM wzrosło o 12 kg.',
              exerciseId: 'squat',
            ),
          ],
        ),
      );

      // Ukośnik w id idzie w ścieżce zakodowany i wraca nienaruszony.
      await tester.tap(find.text('Wyciskanie: bez progresu od 5 treningów.'));
      await tester.pumpAndSettle();
      expect(find.text('exercise bench/1'), findsOneWidget);

      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();

      tester.semantics.performAction(
        find.semantics.byLabel('Przysiad: szacowane 1RM wzrosło o 12 kg.'),
        SemanticsAction.tap,
      );
      await tester.pumpAndSettle();
      expect(find.text('exercise squat'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a non-tappable row does nothing on tap', (tester) async {
      await _pumpRouted(
        tester,
        const StatsInsightsCard(
          insights: [
            StatsInsight(
              kind: StatsInsightKind.streak,
              tone: StatsInsightTone.positive,
              text: 'Seria 5 tygodni z rzędu z treningiem.',
            ),
          ],
        ),
      );
      await tester.tap(find.text('Seria 5 tygodni z rzędu z treningiem.'));
      await tester.pumpAndSettle();
      expect(find.text('Wnioski'), findsOneWidget);
      expect(find.textContaining('exercise'), findsNothing);
    });

    testWidgets('long texts stop at three lines with an ellipsis', (
      tester,
    ) async {
      final long = List.filled(
        14,
        'Ćwiczenie $_longExercise wymaga uwagi.',
      ).join(' ');
      for (final scale in [1.0, 1.3]) {
        await _pump(
          tester,
          StatsInsightsCard(
            insights: [
              StatsInsight(
                kind: StatsInsightKind.plateau,
                tone: StatsInsightTone.attention,
                text: long,
                exerciseId: 'bench',
              ),
              StatsInsight(
                kind: StatsInsightKind.records,
                tone: StatsInsightTone.positive,
                text: 'Nowy rekord: $_longExercise.',
                exerciseId: 'incline',
              ),
            ],
          ),
          textScale: scale,
        );

        final paragraph = tester.renderObject<RenderParagraph>(find.text(long));
        expect(paragraph.didExceedMaxLines, isTrue, reason: 'scale $scale');
        expect(find.text('Nowy rekord: $_longExercise.'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'scale $scale');
      }
    });
  });

  testWidgets('cards built from a real snapshot render together', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final snapshot = TrainingStatsCalculator.compute(
      [
        _session(DateTime(2026, 9, 1, 8), [
          _exercise('bench', 'Wyciskanie leżąc', [
            _set('80', '5'),
            _set('80', '5'),
          ]),
        ], name: _longPlan),
        _session(DateTime(2026, 9, 14, 8), [
          _exercise('bench', 'Wyciskanie leżąc', [
            _set('90', '5'),
            _set('60', '14'),
          ]),
        ]),
      ],
      range: StatsRange.month,
      now: _now,
      weeklyGoal: 3,
    );
    expect(snapshot.goal, isNotNull);
    expect(snapshot.insights, isNotEmpty);
    expect(snapshot.repRanges.total, 4);
    expect(snapshot.sessionRecords.isEmpty, isFalse);

    await _pump(
      tester,
      Column(
        children: [
          StatsGoalCard(goal: snapshot.goal!),
          const SizedBox(height: 12),
          StatsSessionRecordsCard(records: snapshot.sessionRecords),
          const SizedBox(height: 12),
          StatsRepRangesCard(ranges: snapshot.repRanges),
          const SizedBox(height: 12),
          StatsInsightsCard(insights: snapshot.insights),
        ],
      ),
      textScale: 1.3,
    );

    expect(find.text('Cel tygodnia'), findsOneWidget);
    expect(find.text('Rekordy sesji'), findsOneWidget);
    expect(find.text('Zakresy powtórzeń'), findsOneWidget);
    expect(find.text('Wnioski'), findsOneWidget);
    expect(_rich('1 / 3'), findsOneWidget);
    expect(
      find.text('Najwięcej serii robisz w zakresie siły (1–5 powt.).'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    handle.dispose();
  });
}
