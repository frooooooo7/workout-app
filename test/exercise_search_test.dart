import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/library/domain/exercise_search.dart';
import 'package:gym/features/library/domain/models/exercise.dart';

Exercise _e(String name, List<MuscleGroup> muscles) => Exercise(
  id: name,
  name: name,
  muscles: muscles,
  category: ExerciseCategory.compound,
);

void main() {
  final bench = _e('Wyciskanie sztangi na ławce', [
    MuscleGroup.chest,
    MuscleGroup.triceps,
  ]);
  final dbBench = _e('Wyciskanie hantli na ławce płaskiej', [
    MuscleGroup.chest,
  ]);
  final curl = _e('Uginanie ramion ze sztangą', [MuscleGroup.biceps]);
  final row = _e('Wiosłowanie sztangą', [MuscleGroup.lats, MuscleGroup.biceps]);
  final all = [bench, dbBench, curl, row];

  List<String> names(String q) => [
    for (final e in ExerciseSearch.rank(all, q)) e.name,
  ];

  test('normalize strips Polish diacritics', () {
    expect(ExerciseSearch.normalize('Łydki ŻÓŁĆ'), 'lydki zolc');
  });

  test('works without Polish characters', () {
    expect(names('lawce'), [bench.name, dbBench.name]);
    expect(names('wioslowanie'), [row.name]);
  });

  test('words in any order, stem tolerates endings', () {
    expect(names('sztanga wyciskanie'), [bench.name]);
    expect(names('wyciskanie sztangi'), [bench.name]);
  });

  test('searches muscles, primary before supporting', () {
    expect(names('biceps'), [curl.name, row.name]);
    expect(names('plecy'), [row.name]);
  });

  test('no match returns empty, every token must match', () {
    expect(names('hip thrust'), isEmpty);
    expect(names('lawce sztanga curl'), isEmpty);
  });

  test('name beats muscle', () {
    final press = _e('Triceps pushdown', [MuscleGroup.triceps]);
    final other = _e('Wyciskanie francuskie', [MuscleGroup.triceps]);
    expect(
      ExerciseSearch.rank([other, press], 'triceps').first.name,
      press.name,
    );
  });
}
