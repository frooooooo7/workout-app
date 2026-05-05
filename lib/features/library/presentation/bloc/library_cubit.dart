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
  LibraryCubit(this._repository) : super(const LibraryState());

  final ExerciseRepository _repository;

  Future<void> refresh() async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final result = await _repository.getAll(
        filter: state.filter,
        muscleGroup: state.category,
        query: state.query,
      );
      emit(
        state.copyWith(
          exercises: result,
          loading: false,
          clearError: true,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          loading: false,
          error: 'Nie można załadować ćwiczeń. Sprawdź połączenie.',
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
    refresh();
  }

  Future<void> toggleFavourite(Exercise exercise) async {
    try {
      await _repository.setFavourite(
        exercise.id,
        isFavourite: !exercise.isFavourite,
      );
      await refresh();
    } catch (_) {
      rethrow;
    }
  }
}
