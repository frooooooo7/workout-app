import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/library/data/exercise_filter_utils.dart';
import 'package:gym/features/library/domain/models/exercise.dart';

Exercise _exercise(String name, List<MuscleGroup> muscles) => Exercise(
  id: name,
  name: name,
  muscles: muscles,
  category: ExerciseCategory.compound,
);

void main() {
  test('the API gets muscles as chosen: groups and specific ones, no all', () {
    expect(
      MuscleGroup.toApiList(const [
        MuscleGroup.quads,
        MuscleGroup.glutes,
        MuscleGroup.lats,
        MuscleGroup.rearDelts,
        MuscleGroup.back,
        MuscleGroup.lats,
        MuscleGroup.all,
      ]),
      ['quads', 'glutes', 'lats', 'rearDelts', 'back'],
    );
  });

  test('every group rolls up into a group of the same body region', () {
    for (final muscle in MuscleGroup.values) {
      if (muscle == MuscleGroup.all) continue;
      expect(muscle.broadGroup.region, muscle.region, reason: muscle.name);
    }
  });

  test('a library tab for a group also matches its specific muscles', () {
    expect(MuscleGroup.back.filterMatches, {
      MuscleGroup.back,
      MuscleGroup.traps,
      MuscleGroup.lats,
      MuscleGroup.rhomboids,
      MuscleGroup.lowerBack,
    });
    expect(MuscleGroup.abs.filterMatches, {
      MuscleGroup.abs,
      MuscleGroup.obliques,
    });
    expect(MuscleGroup.chest.filterMatches, {MuscleGroup.chest});
    expect(MuscleGroup.lats.filterMatches, {MuscleGroup.lats});
    expect(MuscleGroup.all.filterMatches, isEmpty);
  });

  test('the offline library filter uses the same grouping as the server', () {
    final row = _exercise('Wiosłowanie', const [
      MuscleGroup.lats,
      MuscleGroup.biceps,
    ]);
    final squat = _exercise('Przysiad', const [
      MuscleGroup.quads,
      MuscleGroup.glutes,
    ]);
    final legacy = _exercise('Stare plecy', const [MuscleGroup.back]);
    final all = [row, squat, legacy];

    List<String> tab(MuscleGroup group) => [
      for (final e in ExerciseFilterUtils.apply(all, muscleGroup: group))
        e.name,
    ];

    expect(tab(MuscleGroup.back), ['Wiosłowanie', 'Stare plecy']);
    expect(tab(MuscleGroup.legs), ['Przysiad']);
    expect(tab(MuscleGroup.biceps), ['Wiosłowanie']);
    expect(tab(MuscleGroup.glutes), ['Przysiad']);
    expect(tab(MuscleGroup.lats), ['Wiosłowanie']);
    expect(ExerciseFilterUtils.apply(all, muscleGroup: MuscleGroup.all), all);
  });
}
