import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/library/domain/models/exercise.dart';

void main() {
  test('only the 8 backend muscle groups are API-supported', () {
    expect(
      MuscleGroup.values.where((m) => m.isApiSupported).map((m) => m.name),
      [
        'chest',
        'back',
        'legs',
        'shoulders',
        'biceps',
        'triceps',
        'abs',
        'glutes',
      ],
    );
  });

  test('granular groups map to their coarse API group, deduplicated', () {
    expect(
      MuscleGroup.toApiList(const [
        MuscleGroup.quads,
        MuscleGroup.glutes,
        MuscleGroup.hamstrings,
        MuscleGroup.lats,
        MuscleGroup.rearDelts,
        MuscleGroup.obliques,
        MuscleGroup.forearms,
        MuscleGroup.all,
      ]),
      ['legs', 'glutes', 'back', 'shoulders', 'abs', 'biceps'],
    );
  });

  test('every group maps into the same body region', () {
    for (final muscle in MuscleGroup.values) {
      if (muscle == MuscleGroup.all) continue;
      expect(muscle.apiGroup.isApiSupported, isTrue, reason: muscle.name);
      expect(muscle.apiGroup.region, muscle.region, reason: muscle.name);
    }
  });
}
