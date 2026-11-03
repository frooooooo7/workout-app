import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/theme/app_colors.dart';
import 'package:gym/features/body_highlighter/models/muscle_highlight.dart';
import 'package:gym/features/body_highlighter/models/muscle_intensity.dart';
import 'package:gym/features/body_highlighter/widgets/muscle_body_highlighter.dart';
import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:gym/features/training/domain/models/training_session.dart';
import 'package:gym/features/training/domain/models/muscle_role.dart';
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

/// Ekran „Mięśnie” bez regeneracji: mapa, serie w tygodniu i ranking.
class _MusclesScreen extends StatelessWidget {
  const _MusclesScreen({required this.muscles});

  final MuscleDistribution muscles;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        StatsMuscleMapCard(muscles: muscles),
        StatsRegionBarsCard(
          muscles: muscles,
          window: StatsWindow(
            start: DateTime(2026, 8, 17),
            end: DateTime(2026, 9, 17),
            bucket: StatsBucket.day,
          ),
          rangeLabel: '30 dni',
        ),
        StatsMuscleRankingCard(muscles: muscles),
      ],
    );
  }
}

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

  group('Muscles screen cards', () {
    testWidgets('ranks groups as tagged: coarse ones stay whole', (
      tester,
    ) async {
      final coarse = _coarseSnapshot().muscles;
      await _pump(tester, _MusclesScreen(muscles: coarse));

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

      // Zasady liczenia siedzą pod ikonką (i), nie nad rankingiem.
      expect(find.textContaining('otagowano'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('stats-muscles-info')));
      await tester.pumpAndSettle();
      expect(find.textContaining('otagowano'), findsOneWidget);
      expect(find.textContaining('po połowie'), findsOneWidget);
      await tester.tap(find.text('Rozumiem'));
      await tester.pumpAndSettle();

      // Pominięty mięsień partii, która ma serie (pośladki w nogach), świeci
      // na mapie na bursztynowo, ale nie dostaje własnego paska.
      expect(find.text('Pośladki'), findsNothing);
      expect(find.text('Przedramiona'), findsNothing);
      expect(find.text('Łydki'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('toggle reveals hidden ranking rows', (tester) async {
      final coarse = _coarseSnapshot().muscles;
      await _pump(tester, _MusclesScreen(muscles: coarse));

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
      await _pump(tester, _MusclesScreen(muscles: snapshot.muscles));

      expect(find.text('Klatka'), findsWidgets); // legenda + ranking
      expect(find.text('Nogi'), findsOneWidget); // tylko paski partii
      expect(find.text('Czworogłowe'), findsOneWidget);
      // Łydki to pominięty mięsień partii, która ma serie — świecą na mapie,
      // ale nie dostają własnego paska.
      expect(find.text('Łydki'), findsNothing);

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
      // to, co jest w bodyRoles.
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
        bodyRoles: {
          MuscleGroup.quads: MuscleRole.primary,
          MuscleGroup.calves: MuscleRole.primary,
          MuscleGroup.hamstrings: MuscleRole.secondary,
          // Dwa mięśnie w tym samym obszarze manekina: wygrywa główny.
          MuscleGroup.lats: MuscleRole.secondary,
          MuscleGroup.rhomboids: MuscleRole.primary,
        },
        regions: [
          RegionStat(region: MuscleRegion.back, sets: 12, share: 0.75),
          RegionStat(region: MuscleRegion.legs, sets: 4, share: 0.25),
        ],
        neglected: [],
      );
      await _pump(tester, const _MusclesScreen(muscles: muscles));

      final maps = _bodyHighlights(tester);
      expect(maps, hasLength(2)); // przód i tył
      final expected = {
        MuscleHighlight(muscle: 'quadriceps', intensity: MuscleIntensity.high),
        MuscleHighlight(muscle: 'calves', intensity: MuscleIntensity.high),
        MuscleHighlight(muscle: 'hamstring', intensity: MuscleIntensity.low),
        MuscleHighlight(muscle: 'upper-back', intensity: MuscleIntensity.high),
      };
      for (final highlights in maps) {
        expect(highlights, expected);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping a ranking row shows where its sets come from', (
      tester,
    ) async {
      const muscles = MuscleDistribution(
        muscles: [
          MuscleStat(
            muscle: MuscleGroup.chest,
            sets: 9,
            volumeKg: 0,
            share: 1,
            intensity: 1,
            sources: [
              MuscleSource(
                exerciseName: 'Wyciskanie sztangi',
                sets: 6,
                targetSets: 6,
                volumeKg: 0,
              ),
              MuscleSource(
                exerciseName: 'Rozpiętki',
                sets: 3,
                targetSets: 0,
                volumeKg: 0,
              ),
            ],
          ),
        ],
        regions: [],
        neglected: [],
      );
      await _pump(tester, const _MusclesScreen(muscles: muscles));

      expect(find.text('Wyciskanie sztangi'), findsNothing);
      expect(find.text('GŁÓWNE'), findsOneWidget);

      await tester.tap(find.text('Klatka'));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Wyciskanie sztangi'), findsOneWidget);
      expect(find.text('cel · 6 serii'), findsOneWidget);
      expect(find.text('Rozpiętki'), findsOneWidget);
      expect(find.text('wspomaga · 3 serie'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Klatka'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Wyciskanie sztangi'), findsNothing);
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
      await _pump(tester, const _MusclesScreen(muscles: muscles));

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
      await _pump(tester, _MusclesScreen(muscles: coarse));

      final lit = {for (final h in _bodyHighlights(tester).first) h.muscle};
      // W rankingu jest tylko „Nogi”, a manekin zapala mięśnie całego regionu.
      expect(
        lit,
        containsAll(['quadriceps', 'hamstring', 'calves', 'adductors']),
      );
      expect(lit, containsAll(['upper-back', 'trapezius', 'deltoids']));
      expect(lit, contains('chest'));
      // Pośladków nikt nie trenował — świecą jako „pominięte” (bursztyn).
      final glutes = _bodyHighlights(
        tester,
      ).first.singleWhere((h) => h.muscle == 'gluteal');
      expect(glutes.customColor, AppColors.statAmber);
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty distribution shows a hint', (tester) async {
      await _pump(
        tester,
        const _MusclesScreen(muscles: MuscleDistribution.empty),
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

      expect(find.text('Rekordy w tym okresie'), findsOneWidget);
      expect(find.text('85 kg × 5'), findsOneWidget);
      expect(find.text('110 kg × 5'), findsOneWidget);
      expect(find.text('12 powt.'), findsOneWidget);
      expect(find.text('+5 kg'), findsWidgets);
      expect(find.text('+2 powt.'), findsWidgets);
      expect(find.text('Powtórzenia'), findsWidgets);
      expect(find.text('wczoraj'), findsNWidgets(3));
      expect(find.textContaining('więcej w tym okresie'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Wszystkie ćwiczenia'));
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
      expect(find.text('Wszystkie ćwiczenia'), findsNothing);
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

      expect(find.text('Szac. 1RM'), findsOneWidget);
      expect(find.text('Najcięższa seria'), findsOneWidget);
      expect(find.text('Objętość'), findsOneWidget);
      expect(find.text('Najlepszy'), findsOneWidget);
      expect(
        find.textContaining(formatStatsLongDate(snapshot.progressFrom)),
        findsOneWidget,
      );

      await tester.tap(find.text('Najcięższa seria'));
      await tester.pump(const Duration(milliseconds: 300));
      // Wyciskanie: 70 → 85 kg.
      expect(find.text('85 kg'), findsNWidgets(2)); // ostatnio + najlepszy
      expect(find.text('+15 kg'), findsOneWidget);

      // Ćwiczenie wybiera się w arkuszu z wyszukiwarką, nie z rzędu chipów.
      await tester.tap(find.byKey(const ValueKey('stats-exercise-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Podciąganie'));
      await tester.pumpAndSettle();
      expect(find.text('Powtórzenia'), findsOneWidget);
      expect(find.text('Szac. 1RM'), findsNothing);
      expect(find.text('+4 powt.'), findsOneWidget);

      // Długa nazwa — jeden trening, za mało na wykres.
      await tester.tap(find.byKey(const ValueKey('stats-exercise-picker')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('stats-exercise-search')),
        'skośnej',
      );
      await tester.pump();
      await tester.tap(find.text(_longName));
      await tester.pumpAndSettle();
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

  group('StatsAllExercisesCard', () {
    testWidgets('lists every exercise with its session count', (tester) async {
      await _pump(tester, StatsAllExercisesCard(exercises: snapshot.exercises));

      expect(find.text('Wszystkie ćwiczenia'), findsOneWidget);
      expect(find.text('4 treningi'), findsOneWidget);
      expect(find.text('3 treningi'), findsWidgets);
      expect(find.text(_longName), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty list shows a note', (tester) async {
      await _pump(tester, const StatsAllExercisesCard(exercises: []));
      expect(find.text('Brak ćwiczeń w tym okresie.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
