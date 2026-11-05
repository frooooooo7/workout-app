import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:gym/features/library/domain/models/exercise_stats.dart';
import 'package:gym/features/library/domain/models/library_part.dart';
import 'package:gym/features/library/domain/models/library_sort.dart';
import 'package:gym/features/library/domain/repositories/exercise_repository.dart';
import 'package:gym/features/library/presentation/bloc/library_cubit.dart';
import 'package:gym/features/training/domain/models/training_session.dart';

class _FakeExerciseRepository implements ExerciseRepository {
  _FakeExerciseRepository(this.data);

  List<Exercise> data;

  @override
  Future<Exercise?> getById(String id) async =>
      data.where((e) => e.id == id).firstOrNull;

  @override
  Future<Exercise> create({
    required String name,
    required List<MuscleGroup> muscles,
    required ExerciseCategory category,
    required String description,
    Uint8List? imageBytes,
    String? imageFilename,
    ExerciseTracking tracking = ExerciseTracking.weightReps,
    DistanceUnit distanceUnit = DistanceUnit.km,
    ExerciseExtras? extras,
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
    ExerciseTracking tracking = ExerciseTracking.weightReps,
    DistanceUnit distanceUnit = DistanceUnit.km,
    ExerciseExtras? extras,
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

    test('„Ostatnio robione” bierze ćwiczenia z treningów, najnowsze pierwsze', () async {
      TrainingSession at(String id, String name, DateTime day) => TrainingSession(
        planName: 'Plan',
        status: TrainingSessionStatus.completed,
        startedAt: day,
        finishedAt: day,
        exercises: [
          TrainingSessionExercise(
            exerciseId: id,
            exerciseName: name,
            exerciseMuscles: const [],
            exerciseCategory: 'compound',
            sets: [TrainingSessionSet(actualReps: '10', completed: true)],
          ),
        ],
      );
      final cubit = LibraryCubit(
        _FakeExerciseRepository(sample),
        loadUsage: () async => ExerciseStats.usage([
          at('a', 'Arnoldki', DateTime.utc(2026, 5, 1)),
          at('b', 'Bicepsy', DateTime.utc(2026, 6, 1)),
        ]),
      );
      cubit.setFilter(LibraryFilter.recent);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // „c” nie było w żadnym treningu, więc nie ma go na liście.
      expect(ids(cubit), ['b', 'a']);
      await cubit.close();
    });

    test('filtry sprzętu i mięśni zawężają listę, „Wyczyść” przywraca', () async {
      final data = [
        Exercise(
          id: 'a',
          name: 'Wyciskanie',
          muscles: const [MuscleGroup.chest, MuscleGroup.triceps],
          category: ExerciseCategory.compound,
          equipment: ExerciseEquipment.barbell,
        ),
        Exercise(
          id: 'b',
          name: 'Rozpiętki',
          muscles: const [MuscleGroup.chest],
          category: ExerciseCategory.isolation,
          equipment: ExerciseEquipment.dumbbell,
        ),
        Exercise(
          id: 'c',
          name: 'Ściąganie',
          muscles: const [MuscleGroup.lats],
          category: ExerciseCategory.compound,
        ),
      ];
      final cubit = LibraryCubit(_FakeExerciseRepository(data));
      await cubit.refresh();
      List<String> ids() => [for (final e in cubit.state.exercises) e.id];

      cubit.setFilters(equipment: {ExerciseEquipment.barbell});
      expect(ids(), ['a']);
      expect(cubit.state.activeFilterCount, 1);

      cubit.setFilters(equipment: const {}, muscles: {MuscleGroup.chest});
      expect(ids().toSet(), {'a', 'b'});

      // Grupa zbiorcza „plecy” obejmuje najszersze; dwa filtry łączą się I.
      cubit.setFilters(
        muscles: {MuscleGroup.back},
        equipment: const {},
        types: {ExerciseCategory.compound},
      );
      expect(ids(), ['c']);
      expect(cubit.state.activeFilterCount, 2);

      cubit.setFilters(
        types: const {},
        equipment: const {},
        muscles: const {},
      );
      expect(ids().toSet(), {'a', 'b', 'c'});
      await cubit.close();
    });

    test('starsze ćwiczenie z ogólnym tagiem pasuje do dokładnego mięśnia', () async {
      const legacy = Exercise(
        id: 'old',
        name: 'Własne plecy',
        muscles: [MuscleGroup.back],
        category: ExerciseCategory.compound,
      );
      const legacyLegs = Exercise(
        id: 'legs',
        name: 'Własne nogi',
        muscles: [MuscleGroup.legs],
        category: ExerciseCategory.compound,
      );
      final cubit = LibraryCubit(_FakeExerciseRepository([legacy, legacyLegs]));
      await cubit.refresh();
      cubit.setFilters(muscles: {MuscleGroup.lats});
      expect([for (final e in cubit.state.exercises) e.id], ['old']);
      cubit.setFilters(muscles: {MuscleGroup.quads});
      expect([for (final e in cubit.state.exercises) e.id], ['legs']);
      await cubit.close();
    });

    test('brak sprzętu liczy się jako „Inne”, podgląd liczby wyników', () async {
      final data = [
        Exercise(
          id: 'a',
          name: 'Własne',
          muscles: const [MuscleGroup.chest],
          category: ExerciseCategory.compound,
        ),
        Exercise(
          id: 'b',
          name: 'Ze sztangą',
          muscles: const [MuscleGroup.chest],
          category: ExerciseCategory.compound,
          equipment: ExerciseEquipment.barbell,
        ),
      ];
      final cubit = LibraryCubit(_FakeExerciseRepository(data));
      await cubit.refresh();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(cubit.previewCount(equipment: {ExerciseEquipment.other}), 1);
      expect(cubit.previewCount(equipment: {ExerciseEquipment.barbell}), 1);
      expect(cubit.previewCount(), 2);
      cubit.setFilters(equipment: {ExerciseEquipment.other});
      expect([for (final e in cubit.state.exercises) e.id], ['a']);
      await cubit.close();
    });

    test('podgląd liczby wyników uwzględnia tekst i „Ulubione”', () async {
      final data = [
        Exercise(
          id: 'a',
          name: 'Wyciskanie sztangi',
          muscles: const [MuscleGroup.chest],
          category: ExerciseCategory.compound,
          isFavourite: true,
        ),
        Exercise(
          id: 'b',
          name: 'Wyciskanie hantli',
          muscles: const [MuscleGroup.chest],
          category: ExerciseCategory.compound,
        ),
        Exercise(
          id: 'c',
          name: 'Przysiad',
          muscles: const [MuscleGroup.quads],
          category: ExerciseCategory.compound,
        ),
      ];
      final cubit = LibraryCubit(_FakeExerciseRepository(data));
      await cubit.refresh();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(cubit.previewCount(muscles: {MuscleGroup.chest}), 2);

      cubit.setQuery('wyciskanie');
      expect(cubit.previewCount(), 2);
      expect(cubit.previewCount(muscles: {MuscleGroup.quads}), 0);

      cubit.setQuery('');
      cubit.setFilter(LibraryFilter.favourite);
      expect(cubit.previewCount(muscles: {MuscleGroup.chest}), 1);
      await cubit.close();
    });

    test('data ostatniego wyniku: dziś, wczoraj, dzień tygodnia, data', () {
      final now = DateTime(2026, 11, 3, 12);
      String label(DateTime d) => ExerciseLastResult(date: d).dateLabel(now);
      expect(label(DateTime(2026, 11, 3, 8)), 'dziś');
      expect(label(DateTime(2026, 11, 2, 20)), 'wczoraj');
      expect(label(DateTime(2026, 10, 30)), 'pt.');
      expect(label(DateTime(2026, 10, 12)), '12 paź');
      // Zmiana czasu w nocy nie przesuwa „wczoraj”.
      expect(
        ExerciseLastResult(date: DateTime(2026, 10, 25, 23)).dateLabel(
          DateTime(2026, 10, 26, 1),
        ),
        'wczoraj',
      );
    });

    test('ostatni wynik: najcięższa seria z najnowszego treningu', () {
      TrainingSession at(DateTime day, List<TrainingSessionSet> sets) =>
          TrainingSession(
            planName: 'Plan',
            status: TrainingSessionStatus.completed,
            startedAt: day,
            finishedAt: day,
            exercises: [
              TrainingSessionExercise(
                exerciseId: 'a',
                exerciseName: 'Arnoldki',
                exerciseMuscles: const [],
                exerciseCategory: 'compound',
                sets: sets,
              ),
            ],
          );
      final usage = ExerciseStats.usage([
        at(DateTime.utc(2026, 5, 1), [
          TrainingSessionSet(
            actualWeight: '100',
            actualReps: '3',
            completed: true,
          ),
        ]),
        at(DateTime.utc(2026, 6, 1), [
          TrainingSessionSet(
            actualWeight: '60',
            actualReps: '10',
            completed: true,
          ),
          TrainingSessionSet(
            actualWeight: '80',
            actualReps: '5',
            completed: true,
          ),
          TrainingSessionSet(
            actualWeight: '120',
            actualReps: '1',
            completed: false,
          ),
        ]),
      ]);
      const arnoldki = Exercise(
        id: 'a',
        name: 'Arnoldki',
        muscles: [MuscleGroup.shoulders],
        category: ExerciseCategory.compound,
      );
      final result = usage.lastResultFor(arnoldki)!;
      expect(result.weightKg, 80);
      expect(result.reps, 5);
      expect(result.label, contains('× 5'));
      expect(
        usage.lastResultFor(
          const Exercise(
            id: 'zz',
            name: 'Inne',
            muscles: [MuscleGroup.abs],
            category: ExerciseCategory.isolation,
          ),
        ),
        isNull,
      );
    });

    test('ekran startowy: liczby przy partiach i ostatnio robione', () async {
      TrainingSession at(String id, String name, DateTime day) => TrainingSession(
        planName: 'Plan',
        status: TrainingSessionStatus.completed,
        startedAt: day,
        finishedAt: day,
        exercises: [
          TrainingSessionExercise(
            exerciseId: id,
            exerciseName: name,
            exerciseMuscles: const [],
            exerciseCategory: 'compound',
            sets: [TrainingSessionSet(actualReps: '10', completed: true)],
          ),
        ],
      );
      final cubit = LibraryCubit(
        _FakeExerciseRepository(sample),
        loadUsage: () async => ExerciseStats.usage([
          at('a', 'Arnoldki', DateTime.utc(2026, 5, 1)),
          at('b', 'Bicepsy', DateTime.utc(2026, 6, 1)),
        ]),
      );
      await cubit.refresh();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final overview = cubit.state.overview;
      expect(overview.total, sample.length);
      expect(overview.partCounts[LibraryPart.shoulders], 1);
      expect(overview.partCounts[LibraryPart.biceps], 1);
      expect(overview.partCounts[LibraryPart.chest], 0);
      expect([for (final e in overview.recent) e.id], ['b', 'a']);
      await cubit.close();
    });

    test('historia dopasowana po id z serwera, gdy nazwa się zmieniła', () {
      final exercise = Exercise(
        id: 'local-1',
        serverId: 'srv-1',
        name: 'Nowa nazwa',
        muscles: const [MuscleGroup.chest],
        category: ExerciseCategory.compound,
      );
      final usage = ExerciseStats.usage([session('srv-1', 'Stara nazwa')]);
      expect(usage.countFor(exercise), 1);
      expect(usage.lastDoneFor(exercise), isNotNull);
      expect(ExerciseStats.matches(session('srv-1', 'Stara nazwa').exercises.first, exercise), isTrue);
    });

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
  Future<Exercise?> getById(String id) async => throw UnimplementedError();

  @override
  Future<Exercise> create({
    required String name,
    required List<MuscleGroup> muscles,
    required ExerciseCategory category,
    required String description,
    Uint8List? imageBytes,
    String? imageFilename,
    ExerciseTracking tracking = ExerciseTracking.weightReps,
    DistanceUnit distanceUnit = DistanceUnit.km,
    ExerciseExtras? extras,
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
    ExerciseTracking tracking = ExerciseTracking.weightReps,
    DistanceUnit distanceUnit = DistanceUnit.km,
    ExerciseExtras? extras,
  }) =>
      throw UnimplementedError();
}
