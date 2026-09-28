import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/models/exercise.dart';
import '../../domain/models/exercise_stats.dart';
import '../../domain/models/library_sort.dart';
import '../../domain/repositories/exercise_repository.dart';

class LibraryState {
  const LibraryState({
    this.filter = LibraryFilter.all,
    this.category = MuscleGroup.all,
    this.query = '',
    this.sort = LibrarySort.popular,
    this.types = const {},
    this.exercises = const [],
    this.loading = true,
    this.error,
  });

  final LibraryFilter filter;
  final MuscleGroup category;
  final String query;
  final LibrarySort sort;

  /// Filtr typu ćwiczenia (wielostaw, izolacja…); pusty zbiór — wszystkie.
  final Set<ExerciseCategory> types;

  final List<Exercise> exercises;
  final bool loading;
  final String? error;

  LibraryState copyWith({
    LibraryFilter? filter,
    MuscleGroup? category,
    String? query,
    LibrarySort? sort,
    Set<ExerciseCategory>? types,
    List<Exercise>? exercises,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return LibraryState(
      filter: filter ?? this.filter,
      category: category ?? this.category,
      query: query ?? this.query,
      sort: sort ?? this.sort,
      types: types ?? this.types,
      exercises: exercises ?? this.exercises,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LibraryState &&
        other.filter == filter &&
        other.category == category &&
        other.query == query &&
        other.sort == sort &&
        setEquals(other.types, types) &&
        listEquals(other.exercises, exercises) &&
        other.loading == loading &&
        other.error == error;
  }

  @override
  int get hashCode => Object.hash(
    filter,
    category,
    query,
    sort,
    Object.hashAllUnordered(types),
    Object.hashAll(exercises),
    loading,
    error,
  );
}

class LibraryCubit extends Cubit<LibraryState> {
  /// [dataChanges] — sygnał synchronizacji; po pobraniu zmian z serwera lista
  /// odświeża się sama (np. przy pierwszym logowaniu na nowym urządzeniu).
  ///
  /// [loadUsage] — liczniki wykonań ćwiczeń z historii treningów dla
  /// sortowania „Popularne”. Bez niego sortowanie zostawia kolejność bazy.
  LibraryCubit(
    this._repository, {
    Listenable? dataChanges,
    Future<ExerciseUsage> Function()? loadUsage,
  }) : _dataChanges = dataChanges,
       _loadUsage = loadUsage,
       super(const LibraryState()) {
    _dataChanges?.addListener(_onDataChanged);
  }

  final ExerciseRepository _repository;
  final Listenable? _dataChanges;
  final Future<ExerciseUsage> Function()? _loadUsage;

  ExerciseUsage? _usage;

  /// Ostatnia lista z repozytorium (przed filtrem typu i sortowaniem) —
  /// zmiana sortowania nie musi ponownie czytać bazy.
  List<Exercise> _source = const [];

  Timer? _queryDebounce;

  @override
  Future<void> close() async {
    _dataChanges?.removeListener(_onDataChanged);
    _queryDebounce?.cancel();
    return super.close();
  }

  void _onDataChanged() {
    if (isClosed) return;
    unawaited(refresh(showLoadingIndicator: false));
  }

  Future<void> refresh({bool showLoadingIndicator = true}) async {
    if (isClosed) return;
    if (showLoadingIndicator) {
      emit(state.copyWith(loading: true, clearError: true));
    }
    try {
      final result = await _repository.getAll(
        filter: state.filter,
        muscleGroup: state.category,
        query: state.query,
      );
      if (state.sort == LibrarySort.popular) await _ensureUsage();
      if (isClosed) return;
      _source = result;
      emit(
        state.copyWith(
          exercises: _arrange(result),
          loading: false,
          clearError: true,
        ),
      );
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          loading: false,
          error: 'Nie można załadować ćwiczeń z pamięci telefonu.',
        ),
      );
    }
  }

  Future<void> _ensureUsage() async {
    if (_usage != null || _loadUsage == null) return;
    try {
      _usage = await _loadUsage();
    } catch (_) {
      // Bez historii „Popularne” zostawia kolejność bazy — to nie jest błąd
      // biblioteki.
      _usage = ExerciseUsage.empty;
    }
  }

  List<Exercise> _arrange(
    List<Exercise> source, {
    Set<ExerciseCategory>? types,
    LibrarySort? sort,
  }) {
    final activeTypes = types ?? state.types;
    final filtered = activeTypes.isEmpty
        ? source
        : source.where((e) => activeTypes.contains(e.category)).toList();
    return sortExercises(filtered, sort ?? state.sort, usage: _usage);
  }

  Future<void> setSort(LibrarySort sort) async {
    if (sort == state.sort) return;
    emit(state.copyWith(sort: sort));
    if (sort == LibrarySort.popular) await _ensureUsage();
    if (isClosed) return;
    emit(state.copyWith(exercises: _arrange(_source)));
  }

  void setTypes(Set<ExerciseCategory> types) {
    final next = Set<ExerciseCategory>.unmodifiable(types);
    emit(state.copyWith(types: next, exercises: _arrange(_source, types: next)));
  }

  void setFilter(LibraryFilter filter) {
    emit(state.copyWith(filter: filter));
    refresh();
  }

  void setCategory(MuscleGroup category) {
    emit(state.copyWith(category: category));
    refresh();
  }

  void setQuery(String query) {
    emit(state.copyWith(query: query));
    _queryDebounce?.cancel();
    _queryDebounce = Timer(const Duration(milliseconds: 250), () {
      refresh(showLoadingIndicator: false);
    });
  }

  Future<void> toggleFavourite(Exercise exercise) async {
    await _repository.setFavourite(
      exercise.id,
      isFavourite: !exercise.isFavourite,
    );
    await refresh(showLoadingIndicator: false);
  }

  Future<Exercise> updateExercise({
    required String id,
    required String name,
    required List<MuscleGroup> muscles,
    required ExerciseCategory category,
    required String description,
  }) async {
    final updated = await _repository.update(
      id: id,
      name: name,
      muscles: muscles,
      category: category,
      description: description,
    );
    await refresh(showLoadingIndicator: false);
    return updated;
  }

  Future<void> deleteExercise(Exercise exercise) async {
    await _repository.delete(exercise.id);
    await refresh(showLoadingIndicator: false);
  }

  /// Saves locally first (offline-first), refreshes from SQLite, returns created row.
  Future<Exercise> createExercise({
    required String name,
    required List<MuscleGroup> muscles,
    required ExerciseCategory category,
    required String description,
    Uint8List? imageBytes,
    String? imageFilename,
  }) async {
    final created = await _repository.create(
      name: name,
      muscles: muscles,
      category: category,
      description: description,
      imageBytes: imageBytes,
      imageFilename: imageFilename,
    );
    await refresh(showLoadingIndicator: false);
    return created;
  }
}

/// Stabilne sortowanie listy biblioteki — remisy zostają w kolejności
/// wejściowej (`List.sort` w Dart nie gwarantuje stabilności).
List<Exercise> sortExercises(
  List<Exercise> exercises,
  LibrarySort sort, {
  ExerciseUsage? usage,
}) {
  int byName(Exercise a, Exercise b) =>
      a.name.toLowerCase().compareTo(b.name.toLowerCase());

  final int Function(Exercise, Exercise) compare = switch (sort) {
    LibrarySort.popular => (a, b) {
      final counts = usage ?? ExerciseUsage.empty;
      return counts.countFor(b).compareTo(counts.countFor(a));
    },
    LibrarySort.alphabetical => byName,
    LibrarySort.newest => (a, b) {
      final aDate = a.createdAt;
      final bDate = b.createdAt;
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    },
    LibrarySort.favouritesFirst => (a, b) {
      if (a.isFavourite == b.isFavourite) return byName(a, b);
      return a.isFavourite ? -1 : 1;
    },
  };

  final indexed = exercises.indexed.toList()
    ..sort((a, b) {
      final result = compare(a.$2, b.$2);
      return result != 0 ? result : a.$1.compareTo(b.$1);
    });
  return [for (final entry in indexed) entry.$2];
}
