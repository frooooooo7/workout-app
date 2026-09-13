import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:gym/features/training/domain/models/training_session.dart';
import 'package:gym/features/training/domain/services/training_session_detail_mapper.dart';
import 'package:gym/features/training/presentation/widgets/session_details/muscle_load.dart';

void main() {
  test('maps duration, volume and completed sets from raw set input', () {
    final startedAt = DateTime.utc(2026, 1, 1, 10);
    final session = TrainingSession(
      planName: 'FBW',
      status: TrainingSessionStatus.completed,
      startedAt: startedAt,
      finishedAt: startedAt.add(const Duration(minutes: 61, seconds: 5)),
      exercises: [
        TrainingSessionExercise(
          exerciseId: 'squat',
          exerciseName: 'Przysiad',
          exerciseMuscles: const ['legs', 'glutes', 'unknown-muscle'],
          exerciseCategory: 'compound',
          sets: [
            TrainingSessionSet(
              plannedReps: '5',
              actualWeight: ' 100 ',
              actualReps: '5',
              completed: true,
            ),
            TrainingSessionSet(
              plannedReps: '5',
              actualWeight: '102,5',
              actualReps: '5 powt.',
              completed: true,
            ),
            TrainingSessionSet(
              plannedReps: '8-10',
              actualWeight: '80',
              actualReps: '8-10',
              completed: true,
            ),
            TrainingSessionSet(
              plannedReps: '5',
              actualWeight: '110',
              actualReps: '3',
            ),
          ],
        ),
      ],
    );

    final detail = trainingSessionDetailFromSession(session);

    expect(detail.durationSec, 3665);
    expect(detail.plan.name, 'FBW');
    expect(detail.status, TrainingSessionStatus.completed);
    expect(detail.exercises, hasLength(1));

    final exercise = detail.exercises.single;
    expect(exercise.muscles, [MuscleGroup.legs, MuscleGroup.glutes]);
    expect(exercise.completedSetsCount, 3);
    // 100×5 + 102,5×5 = 1012,5; zakres "8-10" nie ma jednej liczby powtórzeń,
    // a nieukończona seria nie liczy się do objętości.
    expect(exercise.volumeKg, 1012.5);
    expect(exercise.sets[2].actual?.weightKg, 80);
    expect(exercise.sets[2].actual?.reps, isNull);
    expect(exercise.topSet?.actual?.weightKg, 102.5);
    expect(detail.totalVolumeKg, 1012.5);

    final loads = computeMuscleLoads(detail);
    expect(loads, isNotEmpty);
    expect(loads.first.intensity, 1);
  });

  test('handles active session without finishedAt', () {
    final session = TrainingSession(planName: 'Custom', exercises: const []);

    final detail = trainingSessionDetailFromSession(session);

    expect(detail.durationSec, 0);
    expect(detail.endedAt, isNull);
    expect(detail.exercises, isEmpty);
    expect(detail.totalVolumeKg, 0);
  });

  test('parses weight and reps defensively', () {
    expect(parseWeightKg('82,5'), 82.5);
    expect(parseWeightKg('60 kg'), 60);
    expect(parseWeightKg(''), isNull);
    expect(parseWeightKg('abc'), isNull);
    expect(parseWeightKg(null), isNull);

    expect(parseReps('8'), 8);
    expect(parseReps('10 powt.'), 10);
    expect(parseReps('8-10'), isNull);
    expect(parseReps('8–10'), isNull);
    expect(parseReps(''), isNull);
    expect(parseReps(null), isNull);
  });
}
