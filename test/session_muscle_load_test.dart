import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:gym/features/training/domain/models/training_history_models.dart';
import 'package:gym/features/training/presentation/widgets/session_details/muscle_load.dart';

void main() {
  group('computeMuscleLoads', () {
    test('rozwija grupę zbiorczą na wszystkie mięśnie regionu', () {
      final loads = computeMuscleLoads(
        _session([
          _exercise(muscles: [MuscleGroup.back], sets: [_set(weight: 100, reps: 10)]),
        ]),
      );

      expect(
        loads.map((l) => l.muscle).toSet(),
        {
          MuscleGroup.traps,
          MuscleGroup.lats,
          MuscleGroup.rhomboids,
          MuscleGroup.lowerBack,
        },
      );
      // Cały region pracował tak samo — wszystkie na pełnej intensywności...
      expect(loads.every((l) => l.intensity == 1), isTrue);
      // ...i dzielą się po równo łączną objętością sesji (4 mięśnie -> 25%).
      expect(loads.every((l) => l.percent == 25), isTrue);
    });

    test('mięsień wiodący dostaje dwa razy większy udział niż wspomagający', () {
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

      expect(chest.volumeKg, 1000);
      expect(triceps.volumeKg, 500);
      // Intensywność (podświetlenie manekina) liczona względem lidera.
      expect(chest.intensity, 1);
      expect(triceps.intensity, 0.5);
      // Procent w rankingu to udział w łącznej objętości sesji (1000+500=1500).
      expect(chest.percent, 67);
      expect(triceps.percent, 33);
    });

    test('pomija serie nieukończone przy liczeniu objętości', () {
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

    test('bez zalogowanych ciężarów normalizuje po liczbie serii', () {
      final loads = computeMuscleLoads(
        _session([
          _exercise(
            muscles: [MuscleGroup.abs],
            sets: [_set(), _set(), _set(), _set()],
          ),
          _exercise(
            muscles: [MuscleGroup.calves],
            sets: [_set(), _set()],
          ),
        ]),
      );

      final abs = loads.firstWhere((l) => l.muscle == MuscleGroup.abs);
      final calves = loads.firstWhere((l) => l.muscle == MuscleGroup.calves);

      expect(abs.intensity, 1);
      expect(calves.intensity, 0.5);
      // Udział w łącznej liczbie serii sesji (4+2=6).
      expect(abs.percent, 67);
      expect(calves.percent, 33);
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

    test('wynik jest posortowany malejąco po obciążeniu', () {
      final loads = computeMuscleLoads(
        _session([
          _exercise(
            muscles: [MuscleGroup.quads],
            sets: [_set(weight: 200, reps: 5)],
          ),
          _exercise(
            muscles: [MuscleGroup.biceps],
            sets: [_set(weight: 20, reps: 10)],
          ),
        ]),
      );

      expect(loads.first.muscle, MuscleGroup.quads);
      expect(loads.last.muscle, MuscleGroup.biceps);
      expect(loads.first.intensity, greaterThan(loads.last.intensity));
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
        _exercise(muscles: [MuscleGroup.chest], sets: [_set(weight: 80, reps: 5)]),
      ]);
      expect(withoutStamps.hasSetTimestamps, isFalse);

      final withStamps = _session([
        _exercise(
          muscles: [MuscleGroup.chest],
          sets: [
            _set(weight: 80, reps: 5, completedAt: DateTime.utc(2026, 6, 30, 17, 44)),
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
  required List<MuscleGroup> muscles,
  required List<TrainingExerciseSetDetail> sets,
}) {
  return TrainingExerciseDetail(
    exerciseId: 'e${muscles.hashCode}',
    exerciseName: 'Ćwiczenie',
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
