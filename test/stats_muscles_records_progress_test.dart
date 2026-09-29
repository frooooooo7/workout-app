import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/body_highlighter/models/muscle_highlight.dart';
import 'package:gym/features/body_highlighter/models/muscle_intensity.dart';
import 'package:gym/features/body_highlighter/widgets/muscle_body_highlighter.dart';
import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:gym/features/training/domain/models/training_session.dart';
import 'package:gym/features/training/domain/models/training_stats.dart';
import 'package:gym/features/training/domain/services/stats/training_stats_calculator.dart';
import 'package:gym/features/training/presentation/widgets/stats/stats_exercise_progress_card.dart';
import 'package:gym/features/training/presentation/widgets/stats/stats_format.dart';
import 'package:gym/features/training/presentation/widgets/stats/stats_muscles_card.dart';
import 'package:gym/features/training/presentation/widgets/stats/stats_personal_bests_screen.dart';
import 'package:gym/features/training/presentation/widgets/stats/stats_records_card.dart';
import 'package:gym/features/training/presentation/widgets/stats/stats_top_exercises_card.dart';

/// Środa 16 września 2026, 12:00.
final _now = DateTime(2026, 9, 16, 12);

const _longName =
    'Wyciskanie hantli na ławce skośnej głową w górę z pauzą na dole ruchu';

TrainingSessionExercise _exercise(
  String id,
  String name,
  List<String> muscles, {
  String? weight,
  required String reps,
  int sets = 3,
}) => TrainingSessionExercise(
  exerciseId: id,
  exerciseName: name,
  exerciseMuscles: muscles,
  exerciseCategory: 'compound',
  sets: [
    for (var i = 0; i < sets; i++)
      TrainingSessionSet(
        actualWeight: weight,
        actualReps: reps,
        completed: true,
      ),
  ],
);

TrainingSession _session(
  DateTime startLocal,
  List<TrainingSessionExercise> exercises,
) => TrainingSession(
  planName: 'Plan',
  status: TrainingSessionStatus.completed,
  startedAt: startLocal.toUtc(),
  finishedAt: startLocal.add(const Duration(hours: 1)).toUtc(),
  exercises: exercises,
);

TrainingSessionExercise _bench(String w) => _exercise(
  'bench',
  'Wyciskanie leżąc',
  const ['chest', 'triceps', 'frontDelts'],
  weight: w,
  reps: '5',
);

TrainingSessionExercise _squat(String w) => _exercise(
  'squat',
  'Przysiad',
  const ['quads', 'glutes'],
  weight: w,
  reps: '5',
);

TrainingSessionExercise _pullUps(String reps) =>
    _exercise('', 'Podciąganie', const ['lats', 'biceps'], reps: reps, sets: 4);

TrainingSessionExercise _incline() =>
    _exercise('incline', _longName, const ['chest'], weight: '30', reps: '10');

TrainingStatsSnapshot _snapshot() {
  final sessions = [
    _session(DateTime(2026, 8, 26, 18), [_bench('70'), _pullUps('8')]),
    _session(DateTime(2026, 9, 2, 18), [_bench('75'), _squat('100')]),
    _session(DateTime(2026, 9, 9, 18), [
      _bench('80'),
      _squat('105'),
      _pullUps('10'),
      _incline(),
    ]),
    _session(DateTime(2026, 9, 15, 18), [
      _bench('85'),
      _squat('110'),
      _pullUps('12'),
    ]),
  ];
  return TrainingStatsCalculator.compute(
    sessions,
    range: StatsRange.month,
    now: _now,
  );
}

/// Ćwiczenia otagowane tak jak w backendzie: tylko grupy zbiorcze i podstawowe.
/// Wychodzi: Nogi 10, Plecy 7, Klatka 4, Biceps 3,5, Triceps 3, Barki 2,
/// Brzuch 1 — siedem pozycji, więc ostatnia chowa się za „Pokaż wszystkie”.
TrainingStatsSnapshot _coarseSnapshot() {
  TrainingSessionExercise squat() => _exercise(
    'squat',
    'Przysiad',
    const ['legs'],
    weight: '100',
    reps: '5',
    sets: 5,
  );
  TrainingSessionExercise row(int sets) => _exercise(
    'row',
    'Wiosłowanie',
    const ['back', 'biceps'],
    weight: '60',
    reps: '8',
    sets: sets,
  );
  final sessions = [
    _session(DateTime(2026, 9, 2, 18), [
      squat(),
      row(4),
      _exercise('abs', 'Spięcia', const ['abs'], reps: '15', sets: 1),
    ]),
    _session(DateTime(2026, 9, 9, 18), [
      squat(),
      _exercise(
        'ohp',
        'Wyciskanie nad głowę',
        const ['shoulders', 'triceps'],
        weight: '40',
        reps: '8',
        sets: 2,
      ),
    ]),
    _session(DateTime(2026, 9, 15, 18), [
      _exercise(
        'bench',
        'Wyciskanie leżąc',
        const ['chest', 'triceps'],
        weight: '80',
        reps: '5',
        sets: 4,
      ),
      row(3),
    ]),
  ];
  return TrainingStatsCalculator.compute(
    sessions,
    range: StatsRange.month,
    now: _now,
  );
}

/// Podświetlenia przekazane do manekinów (przód i tył) karty mięśni.
List<Set<MuscleHighlight>> _bodyHighlights(WidgetTester tester) => [
  for (final w in tester.widgetList<MuscleBodyHighlighter>(
    find.byType(MuscleBodyHighlighter),
  ))
    w.highlights,
];

Future<void> _pump(WidgetTester tester, Widget card) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: card,
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 800));
}

void main() {
  late TrainingStatsSnapshot snapshot;

  setUp(() => snapshot = _snapshot());

  group('StatsMusclesCard', () {
    testWidgets('ranks groups as tagged: coarse ones stay whole', (
      tester,
    ) async {
      final coarse = _coarseSnapshot().muscles;
      await _pump(tester, StatsMusclesCard(muscles: coarse));

      expect(find.text('Partie mięśni'), findsOneWidget);
      // Grupy zbiorcze nie rozpadają się na czworogłowe, łydki itd.
      expect(coarse.muscles.first.muscle, MuscleGroup.legs);
      expect(coarse.muscles[1].muscle, MuscleGroup.back);
      expect(find.text('Nogi'), findsNWidgets(2)); // legenda + ranking
      expect(find.text('Plecy'), findsNWidgets(2));
      expect(find.text('Barki'), findsNWidgets(2));
      expect(find.text('Czworogłowe'), findsNothing);
      expect(find.text('Dwugłowe'), findsNothing);
      expect(find.text('Najszersze'), findsNothing);
      expect(find.text('Przednie barki'), findsNothing);

      // Podpis mówi wprost, jak liczymy.
      expect(find.textContaining('otagowano'), findsOneWidget);
      expect(find.textContaining('po połowie'), findsOneWidget);

      // Nogi i plecy pokrywają łydki i najszersze — nie ma o nich ostrzeżenia,
      // brakuje tylko pośladków (przedramion backend nie zna, więc nie ostrzegamy).
      expect(find.textContaining('Bez serii w tym okresie'), findsOneWidget);
      expect(find.textContaining('Przedramiona'), findsNothing);
      expect(find.textContaining('Pośladki'), findsOneWidget);
      expect(find.textContaining('Łydki'), findsNothing);
      expect(find.textContaining('Grupy zbiorcze'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('toggle reveals hidden ranking rows', (tester) async {
      final coarse = _coarseSnapshot().muscles;
      await _pump(tester, StatsMusclesCard(muscles: coarse));

      // Siedem pozycji, widać sześć — Brzuch (najmniej serii) ukryty.
      expect(coarse.muscles, hasLength(7));
      expect(coarse.muscles.last.muscle, MuscleGroup.abs);
      expect(find.text('Brzuch'), findsNothing);

      await tester.ensureVisible(find.text('Pokaż wszystkie'));
      await tester.tap(find.text('Pokaż wszystkie'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Brzuch'), findsOneWidget);
      expect(find.text('Zwiń'), findsOneWidget);

      await tester.tap(find.text('Zwiń'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Brzuch'), findsNothing);
      expect(find.text('Pokaż wszystkie'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('granular tags keep their short labels', (tester) async {
      await _pump(tester, StatsMusclesCard(muscles: snapshot.muscles));

      expect(find.text('Klatka'), findsWidgets); // legenda + ranking
      expect(find.text('Nogi'), findsOneWidget); // tylko legenda partii
      expect(find.text('Czworogłowe'), findsOneWidget);
      expect(find.textContaining('po połowie'), findsOneWidget);
      expect(find.textContaining('Bez serii w tym okresie'), findsOneWidget);
      expect(find.textContaining('Łydki'), findsOneWidget);

      // Siedem mięśni, widać sześć — pośladki (najmniej serii) ukryte.
      expect(snapshot.muscles.muscles, hasLength(7));
      expect(snapshot.muscles.muscles.last.muscle.shortLabel, 'Pośladki');
      expect(find.text('Pośladki'), findsNothing);
      expect(find.text('4,5'), findsNothing);

      await tester.ensureVisible(find.text('Pokaż wszystkie'));
      await tester.tap(find.text('Pokaż wszystkie'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Pośladki'), findsOneWidget);
      expect(find.text('4,5'), findsOneWidget);
      expect(find.text('Zwiń'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('body map is driven by bodyMap, not by ranking intensity', (
      tester,
    ) async {
      // Ranking mówi „Plecy najmocniej”, ale manekin ma świecić wyłącznie
      // to, co jest w bodyMap.
      const muscles = MuscleDistribution(
        muscles: [
          MuscleStat(
            muscle: MuscleGroup.back,
            sets: 12,
            volumeKg: 0,
            share: 0.75,
            intensity: 1,
          ),
          MuscleStat(
            muscle: MuscleGroup.legs,
            sets: 4,
            volumeKg: 0,
            share: 0.25,
            intensity: 0.33,
          ),
        ],
        bodyMap: {
          MuscleGroup.quads: 1,
          MuscleGroup.calves: 0.5,
          MuscleGroup.hamstrings: 0.2,
          // Dwa mięśnie w tym samym obszarze manekina: wygrywa mocniejszy.
          MuscleGroup.lats: 0.3,
          MuscleGroup.rhomboids: 0.9,
        },
        regions: [
          RegionStat(region: MuscleRegion.back, sets: 12, share: 0.75),
          RegionStat(region: MuscleRegion.legs, sets: 4, share: 0.25),
        ],
        neglected: [],
      );
      await _pump(tester, const StatsMusclesCard(muscles: muscles));

      final maps = _bodyHighlights(tester);
      expect(maps, hasLength(2)); // przód i tył
      final expected = {
        MuscleHighlight(muscle: 'quadriceps', intensity: MuscleIntensity.high),
        MuscleHighlight(muscle: 'calves', intensity: MuscleIntensity.medium),
        MuscleHighlight(muscle: 'hamstring', intensity: MuscleIntensity.low),
        MuscleHighlight(muscle: 'upper-back', intensity: MuscleIntensity.high),
      };
      for (final highlights in maps) {
        expect(highlights, expected);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty bodyMap leaves the figures unlit', (tester) async {
      const muscles = MuscleDistribution(
        muscles: [
          MuscleStat(
            muscle: MuscleGroup.legs,
            sets: 4,
            volumeKg: 0,
            share: 1,
            intensity: 1,
          ),
        ],
        regions: [],
        neglected: [],
      );
      await _pump(tester, const StatsMusclesCard(muscles: muscles));

      expect(find.text('Nogi'), findsOneWidget);
      for (final highlights in _bodyHighlights(tester)) {
        expect(highlights, isEmpty);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('calculator body map expands "Nogi" into leg muscles', (
      tester,
    ) async {
      final coarse = _coarseSnapshot().muscles;
      await _pump(tester, StatsMusclesCard(muscles: coarse));

      final lit = {for (final h in _bodyHighlights(tester).first) h.muscle};
      // W rankingu jest tylko „Nogi”, a manekin zapala mięśnie całego regionu.
      expect(
        lit,
        containsAll(['quadriceps', 'hamstring', 'calves', 'adductors']),
      );
      expect(lit, containsAll(['upper-back', 'trapezius', 'deltoids']));
      expect(lit, contains('chest'));
      expect(lit, isNot(contains('gluteal'))); // pośladków nikt nie trenował
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty distribution shows a hint', (tester) async {
      await _pump(
        tester,
        const StatsMusclesCard(muscles: MuscleDistribution.empty),
      );
      expect(find.textContaining('Dodaj partie mięśni'), findsOneWidget);
      expect(find.text('Pokaż wszystkie'), findsNothing);
      expect(find.byType(MuscleBodyHighlighter), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('StatsRecordsCard', () {
    testWidgets('lists newest records and opens all bests with search', (
      tester,
    ) async {
      expect(snapshot.records.length, greaterThan(4));
      await _pump(
        tester,
        StatsRecordsCard(
          records: snapshot.records,
          bests: snapshot.bests,
          now: _now,
        ),
      );

      expect(find.text('Rekordy'), findsOneWidget);
      expect(find.text('85 kg × 5'), findsOneWidget);
      expect(find.text('110 kg × 5'), findsOneWidget);
      expect(find.text('12 powt.'), findsOneWidget);
      expect(find.text('+5 kg'), findsWidgets);
      expect(find.text('+2 powt.'), findsWidgets);
      expect(find.text('Powtórzenia'), findsWidgets);
      expect(find.text('wczoraj'), findsNWidgets(3));
      expect(find.textContaining('więcej w tym okresie'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Wszystkie'));
      await tester.pumpAndSettle();

      expect(find.byType(PersonalBestsScreen), findsOneWidget);
      expect(find.text('Przysiad'), findsOneWidget);
      expect(find.text('Podciąganie'), findsOneWidget);
      expect(find.text('Wyciskanie leżąc'), findsOneWidget);
      expect(find.text('85 kg × 5'), findsOneWidget);
      expect(find.textContaining('ostatnio poprawiony'), findsWidgets);

      await tester.enterText(find.byType(TextField), 'przys');
      await tester.pump();
      expect(find.text('Przysiad'), findsOneWidget);
      expect(find.text('Podciąganie'), findsNothing);
      expect(find.text('Wyciskanie leżąc'), findsNothing);

      await tester.enterText(find.byType(TextField), 'xyz');
      await tester.pump();
      expect(find.textContaining('Brak ćwiczeń pasujących'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.text('Alfabetycznie'));
      await tester.pump(const Duration(milliseconds: 300));
      final names = [
        'Podciąganie',
        'Przysiad',
        'Wyciskanie leżąc',
      ].map((n) => tester.getTopLeft(find.text(n)).dy).toList();
      expect(names, orderedEquals([...names]..sort()));
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty state mentions tracked exercises', (tester) async {
      await _pump(
        tester,
        StatsRecordsCard(records: const [], bests: snapshot.bests, now: _now),
      );
      expect(find.text('Brak nowych rekordów w tym okresie'), findsOneWidget);
      expect(find.textContaining('w 4 ćwiczeniach'), findsOneWidget);

      await _pump(
        tester,
        StatsRecordsCard(records: const [], bests: const [], now: _now),
      );
      expect(find.text('Brak nowych rekordów w tym okresie'), findsOneWidget);
      expect(find.text('Wszystkie'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('StatsExerciseProgressCard', () {
    testWidgets('switches exercises and metrics', (tester) async {
      await _pump(
        tester,
        StatsExerciseProgressCard(
          exercises: snapshot.exercises,
          progressFrom: snapshot.progressFrom,
        ),
      );

      expect(find.text('Progres ćwiczeń'), findsOneWidget);
      expect(find.text('1RM'), findsOneWidget);
      expect(find.text('Ciężar'), findsOneWidget);
      expect(find.text('Objętość'), findsOneWidget);
      expect(find.text('Najlepszy'), findsOneWidget);
      expect(
        find.textContaining(formatStatsLongDate(snapshot.progressFrom)),
        findsOneWidget,
      );

      await tester.tap(find.text('Ciężar'));
      await tester.pump(const Duration(milliseconds: 300));
      // Wyciskanie: 70 → 85 kg.
      expect(find.text('85 kg'), findsNWidgets(2)); // ostatnio + najlepszy
      expect(find.text('+15 kg'), findsOneWidget);

      await tester.tap(find.text('Podciąganie'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Powtórzenia'), findsOneWidget);
      expect(find.text('1RM'), findsNothing);
      expect(find.text('+4 powt.'), findsOneWidget);

      // Długa nazwa — jeden trening, za mało na wykres.
      await tester.dragUntilVisible(
        find.text(_longName),
        find.byType(ListView),
        const Offset(-120, 0),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text(_longName));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.text('Za mało treningów, żeby narysować progres'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty list shows a note', (tester) async {
      await _pump(
        tester,
        StatsExerciseProgressCard(
          exercises: const [],
          progressFrom: DateTime(2026, 6, 18),
        ),
      );
      expect(find.textContaining('Brak ćwiczeń'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('StatsTopExercisesCard', () {
    testWidgets('ranks most frequent exercises', (tester) async {
      await _pump(tester, StatsTopExercisesCard(exercises: snapshot.exercises));

      expect(find.text('Najczęstsze ćwiczenia'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('4 treningi · 12 serii'), findsOneWidget);
      expect(find.text('3 treningi · 12 serii'), findsOneWidget);
      expect(find.text('masa ciała'), findsOneWidget);
      expect(find.text(_longName), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty list shows a note', (tester) async {
      await _pump(tester, const StatsTopExercisesCard(exercises: []));
      expect(find.text('Brak ćwiczeń w tym okresie.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
