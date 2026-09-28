import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:gym/features/library/domain/models/exercise_stats.dart';
import 'package:gym/features/library/domain/models/library_sort.dart';
import 'package:gym/features/library/domain/repositories/exercise_repository.dart';
import 'package:gym/features/library/presentation/bloc/library_cubit.dart';
import 'package:gym/features/training/domain/models/training_session.dart';

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

  group('sortowanie i filtr typu', () {
    final sample = [
      Exercise(
        id: 'c',
        name: 'Ćwiczenie C',
        muscles: const [MuscleGroup.abs],
        category: ExerciseCategory.calisthenics,
        createdAt: DateTime.utc(2026, 1, 1),
      ),
      Exercise(
        id: 'a',
        name: 'Arnoldki',
        muscles: const [MuscleGroup.shoulders],
        category: ExerciseCategory.compound,
        isFavourite: true,
        createdAt: DateTime.utc(2026, 3, 1),
      ),
      Exercise(
        id: 'b',
        name: 'Bicepsy',
        muscles: const [MuscleGroup.biceps],
        category: ExerciseCategory.isolation,
        createdAt: DateTime.utc(2026, 2, 1),
      ),
    ];

    List<String> ids(LibraryCubit cubit) =>
        cubit.state.exercises.map((e) => e.id).toList();

    TrainingSession session(String exerciseId, String name) => TrainingSession(
          planName: 'Plan',
          status: TrainingSessionStatus.completed,
          exercises: [
            TrainingSessionExercise(
              exerciseId: exerciseId,
              exerciseName: name,
              exerciseMuscles: const [],
              exerciseCategory: 'compound',
              sets: [TrainingSessionSet(actualReps: '10', completed: true)],
            ),
          ],
        );

    test('„Popularne” układa według liczby treningów, remisy stabilnie',
        () async {
      final cubit = LibraryCubit(
        _FakeExerciseRepository(sample),
        loadUsage: () async => ExerciseStats.usage([
          session('b', 'Bicepsy'),
          session('b', 'Bicepsy'),
          session('a', 'Arnoldki'),
        ]),
      );
      await cubit.refresh();

      expect(cubit.state.sort, LibrarySort.popular);
      expect(ids(cubit), ['b', 'a', 'c']);
      await cubit.close();
    });

    test('bez historii „Popularne” zostawia kolejność repozytorium', () async {
      final cubit = LibraryCubit(_FakeExerciseRepository(sample));
      await cubit.refresh();

      expect(ids(cubit), ['c', 'a', 'b']);
      await cubit.close();
    });

    test('A–Z, najnowsze i ulubione najpierw', () async {
      final cubit = LibraryCubit(_FakeExerciseRepository(sample));
      await cubit.refresh();

      await cubit.setSort(LibrarySort.alphabetical);
      expect(ids(cubit), ['a', 'b', 'c']);

      await cubit.setSort(LibrarySort.newest);
      expect(ids(cubit), ['a', 'b', 'c']);

      await cubit.setSort(LibrarySort.favouritesFirst);
      expect(ids(cubit).first, 'a');
      await cubit.close();
    });

    test('filtr typu zawęża listę i wraca do pełnej po wyczyszczeniu',
        () async {
      final cubit = LibraryCubit(_FakeExerciseRepository(sample));
      await cubit.refresh();

      cubit.setTypes({ExerciseCategory.isolation, ExerciseCategory.compound});
      expect(ids(cubit), ['a', 'b']);

      cubit.setTypes({});
      expect(ids(cubit), ['c', 'a', 'b']);
      await cubit.close();
    });
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
