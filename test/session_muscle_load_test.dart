import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/body_highlighter/models/muscle_highlight.dart';
import 'package:gym/features/body_highlighter/models/muscle_intensity.dart';
import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:gym/features/training/domain/models/training_history_models.dart';
import 'package:gym/features/training/domain/services/muscle_roles.dart';
import 'package:gym/features/training/presentation/widgets/session_details/muscle_load.dart';
import 'package:gym/features/training/presentation/widgets/session_details/session_muscle_map.dart';

void main() {
  group('computeMuscleLoads', () {
    test('grupa zbiorcza zostaje jedną pozycją, bez dzielenia na mięśnie', () {
      final loads = computeMuscleLoads(
        _session([
          _exercise(
            muscles: [MuscleGroup.back],
            sets: [_set(weight: 100, reps: 10)],
          ),
        ]),
      );

      expect(loads, hasLength(1));
      expect(loads.single.muscle, MuscleGroup.back);
      expect(loads.single.role, MuscleRole.primary);
      expect(loads.single.sets, 1);
    });

    test('powtórzony tag mięśnia liczy się raz', () {
      final loads = computeMuscleLoads(
        _session([
          _exercise(
            muscles: [MuscleGroup.chest, MuscleGroup.chest],
            sets: [_set(weight: 100, reps: 10), _set(weight: 100, reps: 10)],
          ),
        ]),
      );

      expect(loads, hasLength(1));
      expect(loads.single.sets, 2);
      expect(loads.single.primarySets, 2);
      expect(loads.single.sources.single.sets, 2);
    });

    test('to samo ćwiczenie dwa razy składa się w jedno źródło', () {
      final loads = computeMuscleLoads(
        _session([
          _exercise(
            name: 'Wyciskanie',
            muscles: [MuscleGroup.chest],
            sets: [_set(weight: 100, reps: 10)],
          ),
          _exercise(
            name: 'wyciskanie',
            muscles: [MuscleGroup.chest],
            sets: [_set(weight: 100, reps: 8), _set(weight: 100, reps: 8)],
          ),
        ]),
      );

      final sources = loads.single.sources;
      expect(sources, hasLength(1));
      expect(sources.single.sets, 3);
      expect(sources.single.exerciseName, 'Wyciskanie');
    });

    test('odcinek na czas tylko wspomaga, gdy była praca na powtórzenia', () {
      final loads = computeMuscleLoads(
        _session([
          _exercise(
            muscles: [MuscleGroup.chest],
            sets: List.generate(4, (_) => _set(weight: 80, reps: 8)),
          ),
          _exercise(
            name: 'Rower',
            muscles: [MuscleGroup.legs],
            tracking: ExerciseTracking.durationDistance,
            sets: [_set()],
          ),
        ]),
      );

      MuscleLoad of(MuscleGroup m) => loads.firstWhere((l) => l.muscle == m);
      expect(of(MuscleGroup.chest).role, MuscleRole.primary);
      expect(of(MuscleGroup.legs).role, MuscleRole.secondary);
      expect(of(MuscleGroup.legs).primarySets, 0);
    });

    test('sama sesja kardio ma główny mięsień', () {
      final loads = computeMuscleLoads(
        _session([
          _exercise(
            name: 'Rower',
            muscles: [MuscleGroup.legs],
            tracking: ExerciseTracking.durationDistance,
            sets: [_set()],
          ),
        ]),
      );

      expect(loads.single.role, MuscleRole.primary);
    });

    test('pierwszy tag jest celem, kolejne wspomagają', () {
      final loads = computeMuscleLoads(
        _session([
          _exercise(
            muscles: [MuscleGroup.chest, MuscleGroup.triceps],
            sets: [_set(weight: 100, reps: 10)],
          ),
        ]),
      );

      final chest = loads.firstWhere((l) => l.muscle == MuscleGroup.chest);
      final triceps = loads.firstWhere((l) => l.muscle == MuscleGroup.triceps);

      expect(chest.role, MuscleRole.primary);
      expect(triceps.role, MuscleRole.secondary);
      expect(chest.volumeKg, 1000);
      // Objętość ćwiczenia liczy się każdemu jego mięśniowi w całości.
      expect(triceps.volumeKg, 1000);
      expect(chest.primarySets, 1);
      expect(triceps.primarySets, 0);
    });

    test('mięsień będący celem tylko w ułamku serii lidera wspomaga', () {
      // 8 serii na klatkę, 1 seria izolacji na biceps (poniżej 1/4 lidera),
      // 2 serie na triceps (równo 1/4 — już główny).
      final loads = computeMuscleLoads(
        _session([
          _exercise(
            muscles: [MuscleGroup.chest],
            sets: List.generate(8, (_) => _set(weight: 80, reps: 8)),
          ),
          _exercise(
            muscles: [MuscleGroup.biceps],
            sets: [_set(weight: 10, reps: 12)],
          ),
          _exercise(
            muscles: [MuscleGroup.triceps],
            sets: [_set(weight: 20, reps: 12), _set(weight: 20, reps: 12)],
          ),
        ]),
      );

      MuscleRole roleOf(MuscleGroup m) =>
          loads.firstWhere((l) => l.muscle == m).role;
      expect(roleOf(MuscleGroup.chest), MuscleRole.primary);
      expect(roleOf(MuscleGroup.triceps), MuscleRole.primary);
      expect(roleOf(MuscleGroup.biceps), MuscleRole.secondary);
    });

    test('zapamiętuje, z jakich ćwiczeń bierze się mięsień', () {
      final loads = computeMuscleLoads(
        _session([
          _exercise(
            name: 'Wyciskanie sztangi',
            muscles: [MuscleGroup.chest, MuscleGroup.triceps],
            sets: [_set(weight: 100, reps: 10), _set(weight: 100, reps: 10)],
          ),
          _exercise(
            name: 'Prostowanie ramion',
            muscles: [MuscleGroup.triceps],
            sets: [_set(weight: 30, reps: 10)],
          ),
        ]),
      );

      final triceps = loads.firstWhere((l) => l.muscle == MuscleGroup.triceps);
      expect(triceps.sets, 3);
      expect(triceps.primarySets, 1);
      expect(triceps.sources.map((s) => s.exerciseName), [
        'Wyciskanie sztangi',
        'Prostowanie ramion',
      ]);
      expect(triceps.sources.first.isSupport, isTrue);
      expect(triceps.sources.first.sets, 2);
      expect(triceps.sources.last.isTarget, isTrue);
      expect(triceps.sources.last.volumeKg, 300);
    });

    test('pomija serie nieukończone', () {
      final loads = computeMuscleLoads(
        _session([
          _exercise(
            muscles: [MuscleGroup.biceps],
            sets: [
              _set(weight: 20, reps: 10),
              _set(weight: 20, reps: 10, completed: false),
            ],
          ),
        ]),
      );

      final biceps = loads.single;
      expect(biceps.volumeKg, 200);
      expect(biceps.sets, 1);
    });

    test('sesja bez ukończonych serii nie daje żadnego obciążenia', () {
      final loads = computeMuscleLoads(
        _session([
          _exercise(
            muscles: [MuscleGroup.chest],
            sets: [_set(weight: 60, reps: 8, completed: false)],
          ),
        ]),
      );

      expect(loads, isEmpty);
    });

    test('ćwiczenie bez otagowanych mięśni jest pomijane', () {
      final loads = computeMuscleLoads(
        _session([
          _exercise(muscles: [], sets: [_set(weight: 60, reps: 8)]),
        ]),
      );

      expect(loads, isEmpty);
    });

    test(
      'główne są przed wspomagającymi, w grupach od największej liczby serii',
      () {
        final loads = computeMuscleLoads(
          _session([
            _exercise(
              muscles: [MuscleGroup.quads, MuscleGroup.glutes],
              sets: [_set(), _set(), _set()],
            ),
            _exercise(
              muscles: [MuscleGroup.biceps, MuscleGroup.forearms],
              sets: [_set(), _set(), _set()],
            ),
            _exercise(muscles: [MuscleGroup.abs], sets: [_set()]),
          ]),
        );

        expect(loads.map((l) => l.muscle), [
          MuscleGroup.biceps,
          MuscleGroup.quads,
          MuscleGroup.abs,
          MuscleGroup.glutes,
          MuscleGroup.forearms,
        ]);
        expect(loads.take(3).every((l) => l.isPrimary), isTrue);
        expect(loads.skip(3).every((l) => !l.isPrimary), isTrue);
      },
    );

    test('wyjaśnia, dlaczego mięsień dostał rolę', () {
      final loads = computeMuscleLoads(
        _session([
          _exercise(
            muscles: [MuscleGroup.chest, MuscleGroup.triceps],
            sets: List.generate(8, (_) => _set()),
          ),
          _exercise(muscles: [MuscleGroup.biceps], sets: [_set()]),
        ]),
      );
      MuscleLoad of(MuscleGroup m) => loads.firstWhere((l) => l.muscle == m);

      String why(MuscleGroup m) => muscleRoleReason(
        role: of(m).role,
        targetSets: of(m).primarySets,
        leaderTargetSets: 8,
      );

      expect(
        why(MuscleGroup.chest),
        contains('celem ćwiczenia w 8 seriach'),
      );
      expect(
        why(MuscleGroup.triceps),
        contains('na pierwszym miejscu'),
      );
      expect(
        why(MuscleGroup.biceps),
        allOf(contains('tylko w 1 serii'), contains('co najmniej 2')),
      );
    });
  });

  group('highlightsForLoads', () {
    Set<MuscleHighlight> lit(List<TrainingExerciseDetail> exercises) =>
        highlightsForLoads(computeMuscleLoads(_session(exercises)));

    test('główne świecą mocno, wspomagające słabo', () {
      final highlights = lit([
        _exercise(
          muscles: [MuscleGroup.chest, MuscleGroup.triceps],
          sets: [_set(), _set()],
        ),
      ]);

      expect(highlights, {
        MuscleHighlight(muscle: 'chest', intensity: MuscleIntensity.high),
        MuscleHighlight(muscle: 'triceps', intensity: MuscleIntensity.low),
      });
    });

    test('grupa zbiorcza zapala cały region, a ważniejsza rola wygrywa', () {
      // „Barki” wspomagają, ale tylne naramienne są celem — ten sam obszar
      // manekina („deltoids”) ma zostać mocny.
      final highlights = lit([
        _exercise(
          muscles: [MuscleGroup.back, MuscleGroup.shoulders],
          sets: [_set(), _set()],
        ),
        _exercise(muscles: [MuscleGroup.rearDelts], sets: [_set(), _set()]),
      ]);

      expect(
        highlights.where((h) => h.muscle == 'deltoids').single.intensity,
        MuscleIntensity.high,
      );
      expect(
        highlights.map((h) => h.muscle).toSet(),
        containsAll(['trapezius', 'upper-back', 'lower-back', 'deltoids']),
      );
    });
  });

  group('SessionMuscleMap', () {
    testWidgets('pokazuje główne i wspomagające, a po dotknięciu źródła', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SessionMuscleMap(
                detail: _session([
                  _exercise(
                    name: 'Wyciskanie sztangi',
                    muscles: [MuscleGroup.chest, MuscleGroup.triceps],
                    sets: [
                      _set(weight: 100, reps: 5),
                      _set(weight: 100, reps: 5),
                    ],
                  ),
                  _exercise(
                    name: 'Przysiad',
                    muscles: [MuscleGroup.legs],
                    sets: [_set(weight: 120, reps: 5)],
                  ),
                ]),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.text('GŁÓWNE'), findsOneWidget);
      expect(find.text('WSPOMAGAJĄCE'), findsOneWidget);
      expect(find.text('Klatka piersiowa'), findsOneWidget);
      expect(find.text('Triceps'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
      expect(find.text('Wyciskanie sztangi'), findsNothing);

      await tester.tap(find.text('Triceps'));
      await tester.pump();

      expect(find.text('Wyciskanie sztangi'), findsOneWidget);
      expect(find.textContaining('wspomaga · 2 serie'), findsOneWidget);
      expect(find.textContaining('Wspomagający: w żadnym'), findsOneWidget);

      await tester.tap(find.text('Nogi'));
      await tester.pump();
      expect(find.text('Przysiad'), findsOneWidget);
      expect(find.textContaining('zapala cały region'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('agregaty TrainingSessionDetail', () {
    test('sumuje objętość i ukończone serie po ćwiczeniach', () {
      final detail = _session([
        _exercise(
          muscles: [MuscleGroup.chest],
          sets: [_set(weight: 80, reps: 10), _set(weight: 80, reps: 5)],
        ),
        _exercise(
          muscles: [MuscleGroup.lats],
          sets: [_set(weight: 60, reps: 10, completed: false)],
        ),
      ]);

      expect(detail.totalVolumeKg, 1200);
      expect(detail.completedSetsCount, 2);
    });

    test('wykrywa brak znaczników czasu w starszych sesjach', () {
      final withoutStamps = _session([
        _exercise(
          muscles: [MuscleGroup.chest],
          sets: [_set(weight: 80, reps: 5)],
        ),
      ]);
      expect(withoutStamps.hasSetTimestamps, isFalse);

      final withStamps = _session([
        _exercise(
          muscles: [MuscleGroup.chest],
          sets: [
            _set(
              weight: 80,
              reps: 5,
              completedAt: DateTime.utc(2026, 6, 30, 17, 44),
            ),
          ],
        ),
      ]);
      expect(withStamps.hasSetTimestamps, isTrue);
    });

    test('topSet wybiera najcięższą ukończoną serię', () {
      final exercise = _exercise(
        muscles: [MuscleGroup.chest],
        sets: [
          _set(weight: 80, reps: 10),
          _set(weight: 90, reps: 6),
          _set(weight: 100, reps: 3, completed: false),
        ],
      );

      expect(exercise.topSet?.actual?.weightKg, 90);
    });
  });
}

int _setIndex = 0;

TrainingExerciseSetDetail _set({
  double? weight,
  int? reps,
  bool completed = true,
  DateTime? completedAt,
}) {
  final metrics = TrainingSetMetrics(weightKg: weight, reps: reps);
  return TrainingExerciseSetDetail(
    setIndex: ++_setIndex,
    planned: metrics,
    actual: metrics,
    completed: completed,
    completedAt: completedAt,
  );
}

TrainingExerciseDetail _exercise({
  String name = 'Ćwiczenie',
  required List<MuscleGroup> muscles,
  required List<TrainingExerciseSetDetail> sets,
  ExerciseTracking tracking = ExerciseTracking.weightReps,
}) {
  return TrainingExerciseDetail(
    tracking: tracking,
    exerciseId: 'e${muscles.hashCode}',
    exerciseName: name,
    muscles: muscles,
    sets: sets,
  );
}

TrainingSessionDetail _session(List<TrainingExerciseDetail> exercises) {
  return TrainingSessionDetail(
    id: 's1',
    startedAt: DateTime.utc(2026, 6, 30, 17, 42),
    endedAt: DateTime.utc(2026, 6, 30, 18, 54),
    durationSec: 4320,
    status: TrainingSessionStatus.completed,
    plan: const TrainingPlanSummary(id: 'p1', name: 'Siła — góra ciała'),
    note: null,
    exercises: exercises,
    updatedAt: DateTime.utc(2026, 6, 30, 18, 54),
  );
}
