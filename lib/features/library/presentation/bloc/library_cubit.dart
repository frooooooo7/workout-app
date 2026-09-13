import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/models/exercise.dart';
import '../../domain/repositories/exercise_repository.dart';

class LibraryState {
  const LibraryState({
    this.filter = LibraryFilter.all,
    this.category = MuscleGroup.all,
    this.query = '',
    this.exercises = const [],
    this.loading = true,
    this.error,
  });

  final LibraryFilter filter;
  final MuscleGroup category;
  final String query;
  final List<Exercise> exercises;
  final bool loading;
  final String? error;

  LibraryState copyWith({
    LibraryFilter? filter,
    MuscleGroup? category,
    String? query,
    List<Exercise>? exercises,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return LibraryState(
      filter: filter ?? this.filter,
      category: category ?? this.category,
      query: query ?? this.query,
      exercises: exercises ?? this.exercises,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class LibraryCubit extends Cubit<LibraryState> {
  /// [dataChanges] — sygnał synchronizacji; po pobraniu zmian z serwera lista
  /// odświeża się sama (np. przy pierwszym logowaniu na nowym urządzeniu).
  LibraryCubit(this._repository, {Listenable? dataChanges})
    : _dataChanges = dataChanges,
      super(const LibraryState()) {
    _dataChanges?.addListener(_onDataChanged);
  }

  final ExerciseRepository _repository;
  final Listenable? _dataChanges;

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
    } else {
      emit(state.copyWith(clearError: true));
    }
    try {
      final result = await _repository.getAll(
        filter: state.filter,
        muscleGroup: state.category,
        query: state.query,
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          exercises: result,
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
    try {
      await _repository.setFavourite(
        exercise.id,
        isFavourite: !exercise.isFavourite,
      );
      await refresh(showLoadingIndicator: false);
    } catch (_) {
      rethrow;
    }
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
