import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:gym/features/library/domain/models/exercise_stats.dart';
import 'package:gym/features/training/domain/models/training_session.dart';

const _bench = Exercise(
  id: 'bench',
  name: 'Wyciskanie sztangi na ławce',
  muscles: [MuscleGroup.chest, MuscleGroup.triceps],
  category: ExerciseCategory.compound,
);

TrainingSessionSet _set(String weight, String reps, {bool completed = true}) =>
    TrainingSessionSet(
      actualWeight: weight,
      actualReps: reps,
      completed: completed,
    );

TrainingSession _session(
  DateTime startedAt,
  List<TrainingSessionExercise> exercises, {
  TrainingSessionStatus status = TrainingSessionStatus.completed,
}) =>
    TrainingSession(
      planName: 'Push',
      status: status,
      startedAt: startedAt,
      finishedAt: startedAt.add(const Duration(hours: 1)),
      exercises: exercises,
    );

TrainingSessionExercise _entry(
  List<TrainingSessionSet> sets, {
  String id = 'bench',
  String name = 'Wyciskanie sztangi na ławce',
}) =>
    TrainingSessionExercise(
      exerciseId: id,
      exerciseName: name,
      exerciseMuscles: const ['chest'],
      exerciseCategory: 'compound',
      sets: sets,
    );

void main() {
  group('ExerciseStats.fromSessions', () {
    test('liczy rekord, 1RM, objętość i historię tylko z ukończonych serii',
        () {
      final stats = ExerciseStats.fromSessions(_bench, [
        _session(DateTime.utc(2026, 9, 1), [
          _entry([_set('80', '8'), _set('85', '5'), _set('200', '1', completed: false)]),
        ]),
        _session(DateTime.utc(2026, 9, 8), [
          _entry([_set('90', '3')]),
        ]),
      ]);

      expect(stats.sessionsCount, 2);
      expect(stats.totalSets, 3);
      expect(stats.totalVolumeKg, 80 * 8 + 85 * 5 + 90 * 3);
      expect(stats.bestWeightKg, 90);
      expect(stats.bestWeightReps, 3);
      // Epley: 80 × 8 ≈ 101,3 bije 85 × 5 ≈ 99,2 i 90 × 3 = 99.
      expect(stats.bestEstimatedOneRepMaxKg, closeTo(101.33, 0.01));
      expect(stats.history.map((p) => p.topWeightKg), [85, 90]);
      expect(stats.lastPerformedAt, DateTime.utc(2026, 9, 8, 1));
    });

    test('dopasowuje po nazwie, gdy sesja ma identyfikator serwera', () {
      final stats = ExerciseStats.fromSessions(_bench, [
        _session(DateTime.utc(2026, 9, 1), [
          _entry([_set('60', '10')], id: 'server-uuid', name: '  wyciskanie SZTANGI na ławce '),
        ]),
      ]);

      expect(stats.sessionsCount, 1);
      expect(stats.bestWeightKg, 60);
    });

    test('pomija anulowane treningi i inne ćwiczenia', () {
      final stats = ExerciseStats.fromSessions(_bench, [
        _session(
          DateTime.utc(2026, 9, 1),
          [_entry([_set('100', '5')])],
          status: TrainingSessionStatus.cancelled,
        ),
        _session(DateTime.utc(2026, 9, 2), [
          _entry([_set('140', '5')], id: 'squat', name: 'Przysiad'),
        ]),
      ]);

      expect(stats.hasData, isFalse);
      expect(stats.bestWeightKg, isNull);
    });

    test('historia treningu: serie z rozgrzewką, najlepsza seria i rekord', () {
      final first = _session(DateTime.utc(2026, 9, 1), [
        _entry([_set('80', '8'), _set('85', '5')]),
      ]);
      final second = _session(DateTime.utc(2026, 9, 8), [
        _entry([
          TrainingSessionSet(
            setType: SetType.warmup,
            actualWeight: '40',
            actualReps: '10',
            completed: true,
          ),
          _set('90', '3'),
          _set('80', '10'),
        ]).copyWith(note: '  ławka niżej '),
      ]);
      final third = _session(DateTime.utc(2026, 9, 15), [
        _entry([_set('85', '6')]),
      ]);

      final stats = ExerciseStats.fromSessions(_bench, [third, first, second]);
      final history = stats.history;

      expect(history.map((p) => p.sessionId), [first.id, second.id, third.id]);
      expect(history.map((p) => p.sessionName), everyElement('Push'));
      // Pierwszy trening nie jest rekordem, drugi bije 85 kg, trzeci nie.
      expect(history.map((p) => p.isRecord), [false, true, false]);

      final middle = history[1];
      expect(middle.setDetails, hasLength(3));
      expect(middle.setDetails.first.type, SetType.warmup);
      expect(middle.setDetails.first.weightKg, 40);
      // Rozgrzewka nie wchodzi do serii, objętości ani najlepszej serii.
      expect(middle.sets, 2);
      expect(middle.volumeKg, 90 * 3 + 80 * 10);
      expect(middle.totalReps, 13);
      expect(middle.maxReps, 10);
      // 80 × 10 ≈ 106,7 kg 1RM bije 90 × 3 = 99 kg.
      expect(middle.bestSetIndex, 2);
      expect(middle.note, 'ławka niżej');
      expect(stats.totalVolumeKg, 80 * 8 + 85 * 5 + 90 * 3 + 80 * 10 + 85 * 6);
    });

    test('historia nie jest przycinana', () {
      final stats = ExerciseStats.fromSessions(_bench, [
        for (var i = 0; i < 20; i++)
          _session(DateTime.utc(2026, 1, 1 + i), [
            _entry([_set('${60 + i}', '5')]),
          ]),
      ]);

      expect(stats.history, hasLength(20));
      expect(stats.history.last.topWeightKg, 79);
    });

    test('bez ciężaru rekordem jest więcej powtórzeń', () {
      final stats = ExerciseStats.fromSessions(_bench, [
        _session(DateTime.utc(2026, 9, 1), [
          _entry([_set('', '12')]),
        ]),
        _session(DateTime.utc(2026, 9, 2), [
          _entry([_set('', '15')]),
        ]),
        _session(DateTime.utc(2026, 9, 3), [
          _entry([_set('', '14')]),
        ]),
      ]);

      expect(stats.history.map((p) => p.isRecord), [false, true, false]);
      expect(stats.history[1].setDetails.single.weightKg, isNull);
      expect(stats.history[1].bestSetIndex, 0);
    });

    test('ćwiczenie bez ciężaru ma rekord powtórzeń zamiast kilogramów', () {
      final stats = ExerciseStats.fromSessions(_bench, [
        _session(DateTime.utc(2026, 9, 1), [
          _entry([_set('', '12'), _set('', '15')]),
        ]),
      ]);

      expect(stats.hasWeights, isFalse);
      expect(stats.maxReps, 15);
      expect(stats.bestEstimatedOneRepMaxKg, isNull);
    });
  });

  test('ExerciseStats.usage liczy jedno wystąpienie na trening', () {
    final usage = ExerciseStats.usage([
      _session(DateTime.utc(2026, 9, 1), [
        _entry([_set('80', '8')]),
        _entry([_set('80', '8')]),
      ]),
      _session(DateTime.utc(2026, 9, 2), [
        _entry([_set('80', '8')], id: 'server-uuid'),
      ]),
      _session(DateTime.utc(2026, 9, 3), [
        _entry([_set('80', '8', completed: false)]),
      ]),
    ]);

    expect(usage.countFor(_bench), 2);
    expect(
      usage.countFor(
        const Exercise(
          id: 'x',
          name: 'Inne',
          muscles: [],
          category: ExerciseCategory.isolation,
        ),
      ),
      0,
    );
  });
}
