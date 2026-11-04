import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/library/domain/exercise_similarity.dart';
import 'package:gym/features/library/domain/models/exercise.dart';

Exercise _e(
  String id,
  List<MuscleGroup> muscles, {
  String? pattern,
  ExerciseEquipment? equipment,
  ExerciseCategory category = ExerciseCategory.compound,
  ExerciseTracking tracking = ExerciseTracking.weightReps,
}) => Exercise(
  id: id,
  name: id,
  muscles: muscles,
  category: category,
  pattern: pattern,
  equipment: equipment,
  tracking: tracking,
);

void main() {
  final bench = _e(
    'bench',
    [MuscleGroup.chest, MuscleGroup.triceps],
    pattern: 'push_horizontal',
    equipment: ExerciseEquipment.barbell,
  );

  test('ten sam ruch i inny sprzęt wygrywa, samo ćwiczenie pominięte', () {
    final dbBench = _e(
      'dbBench',
      [MuscleGroup.chest],
      pattern: 'push_horizontal',
      equipment: ExerciseEquipment.dumbbell,
    );
    final fly = _e(
      'fly',
      [MuscleGroup.chest],
      pattern: 'fly',
      equipment: ExerciseEquipment.cable,
    );
    final squat = _e('squat', [MuscleGroup.quads], pattern: 'squat');
    final result = ExerciseSimilarity.substitutes(bench, [
      bench,
      squat,
      fly,
      dbBench,
    ]);
    expect(result.map((e) => e.id), ['dbBench', 'fly']);
  });

  test('inny sposób zapisu serii nie jest zamiennikiem', () {
    final plank = _e(
      'plank',
      [MuscleGroup.chest],
      pattern: 'push_horizontal',
      tracking: ExerciseTracking.duration,
    );
    expect(ExerciseSimilarity.substitutes(bench, [plank]), isEmpty);
  });

  test('kardio szuka tylko kardio, bez patrzenia na mięśnie', () {
    final run = _e(
      'run',
      [MuscleGroup.quads],
      category: ExerciseCategory.cardio,
      tracking: ExerciseTracking.durationDistance,
    );
    final bike = _e(
      'bike',
      [MuscleGroup.glutes],
      category: ExerciseCategory.cardio,
      tracking: ExerciseTracking.durationDistance,
      equipment: ExerciseEquipment.machine,
    );
    final squat = _e('squat', [MuscleGroup.quads]);
    expect(
      ExerciseSimilarity.substitutes(run, [run, bike, squat]).map((e) => e.id),
      ['bike'],
    );
  });

  test('limit ucina listę', () {
    final many = [
      for (var i = 0; i < 12; i++)
        _e('c$i', [MuscleGroup.chest], pattern: 'push_horizontal'),
    ];
    expect(ExerciseSimilarity.substitutes(bench, many, limit: 5), hasLength(5));
  });
}
