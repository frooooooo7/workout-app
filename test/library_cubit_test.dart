import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:gym/features/library/domain/repositories/exercise_repository.dart';
import 'package:gym/features/library/presentation/bloc/library_cubit.dart';

class _FakeExerciseRepository implements ExerciseRepository {
  _FakeExerciseRepository(this.data);

  List<Exercise> data;

  @override
  Future<Exercise> create({
    required String name,
    required List<MuscleGroup> muscles,
    required ExerciseCategory category,
    required String description,
    Uint8List? imageBytes,
    String? imageFilename,
  }) async {
    final e = Exercise(
      id: 'new-${data.length + 1}',
      name: name,
      muscles: muscles,
      category: category,
      description: description,
      isMine: true,
    );
    data = [...data, e];
    return e;
  }

  @override
  Future<void> delete(String id) => throw UnimplementedError();

  @override
  Future<List<Exercise>> getAll({
    MuscleGroup? muscleGroup,
    LibraryFilter? filter,
    String? query,
  }) async =>
      List<Exercise>.from(data);

  @override
  Future<void> setFavourite(String id, {required bool isFavourite}) async {}

  @override
  Future<Exercise> update({
    required String id,
    required String name,
    required List<MuscleGroup> muscles,
    required ExerciseCategory category,
    required String description,
  }) =>
      throw UnimplementedError();
}

void main() {
  test('LibraryCubit refresh emits loaded exercises', () async {
    final sample = [
      Exercise(
        id: '1',
        name: 'Bench',
        muscles: const [MuscleGroup.chest],
        category: ExerciseCategory.compound,
      ),
    ];
    final repo = _FakeExerciseRepository(sample);
    final cubit = LibraryCubit(repo);
    await cubit.refresh();

    expect(cubit.state.loading, false);
    expect(cubit.state.error, isNull);
    expect(cubit.state.exercises, sample);
    await cubit.close();
  });

  test('LibraryCubit createExercise appends exercise after refresh', () async {
    final sample = [
      Exercise(
        id: '1',
        name: 'Bench',
        muscles: const [MuscleGroup.chest],
        category: ExerciseCategory.compound,
      ),
    ];
    final repo = _FakeExerciseRepository(sample);
    final cubit = LibraryCubit(repo);
    await cubit.refresh();

    expect(cubit.state.exercises.length, 1);

    await cubit.createExercise(
      name: 'Custom curl',
      muscles: const [MuscleGroup.biceps],
      category: ExerciseCategory.isolation,
      description: '',
    );

    expect(cubit.state.loading, false);
    expect(cubit.state.error, isNull);
    expect(cubit.state.exercises.length, 2);
    expect(
      cubit.state.exercises.any((e) => e.name == 'Custom curl' && e.isMine),
      true,
    );
    await cubit.close();
  });

  test('LibraryCubit sets error state when repository throws', () async {
    final repo = _ThrowingExerciseRepository();
    final cubit = LibraryCubit(repo);
    await cubit.refresh();

    expect(cubit.state.loading, false);
    expect(cubit.state.error, isNotNull);
    await cubit.close();
  });
}

class _ThrowingExerciseRepository implements ExerciseRepository {
  @override
  Future<Exercise> create({
    required String name,
    required List<MuscleGroup> muscles,
    required ExerciseCategory category,
    required String description,
    Uint8List? imageBytes,
    String? imageFilename,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> delete(String id) => throw UnimplementedError();

  @override
  Future<List<Exercise>> getAll({
    MuscleGroup? muscleGroup,
    LibraryFilter? filter,
    String? query,
  }) async {
    throw Exception('network');
  }

  @override
  Future<void> setFavourite(String id, {required bool isFavourite}) async {}

  @override
  Future<Exercise> update({
    required String id,
    required String name,
    required List<MuscleGroup> muscles,
    required ExerciseCategory category,
    required String description,
  }) =>
      throw UnimplementedError();
}
