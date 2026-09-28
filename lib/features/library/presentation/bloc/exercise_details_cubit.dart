import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../training/domain/repositories/training_stats_repository.dart';
import '../../domain/models/exercise.dart';
import '../../domain/models/exercise_stats.dart';
import '../../domain/repositories/exercise_repository.dart';

class ExerciseDetailsState {
  const ExerciseDetailsState({
    this.exercise,
    this.stats,
    this.loading = false,
    this.notFound = false,
  });

  /// `null` tylko do czasu odnalezienia ćwiczenia po identyfikatorze (wejście
  /// z linku bez przekazanego obiektu).
  final Exercise? exercise;

  /// `null` — wyniki jeszcze się liczą.
  final ExerciseStats? stats;

  final bool loading;
  final bool notFound;

  ExerciseDetailsState copyWith({
    Exercise? exercise,
    ExerciseStats? stats,
    bool? loading,
    bool? notFound,
  }) {
    return ExerciseDetailsState(
      exercise: exercise ?? this.exercise,
      stats: stats ?? this.stats,
      loading: loading ?? this.loading,
      notFound: notFound ?? this.notFound,
    );
  }
}

/// Karta ćwiczenia: dane z biblioteki plus Twoje wyniki z historii treningów.
class ExerciseDetailsCubit extends Cubit<ExerciseDetailsState> {
  ExerciseDetailsCubit({
    required ExerciseRepository repository,
    required TrainingStatsRepository statsRepository,
    required this.exerciseId,
    Exercise? initialExercise,
    Listenable? dataChanges,
  }) : _repository = repository,
       _statsRepository = statsRepository,
       _dataChanges = dataChanges,
       super(
         ExerciseDetailsState(
           exercise: initialExercise,
           loading: initialExercise == null,
         ),
       ) {
    _dataChanges?.addListener(_onDataChanged);
  }

  final String exerciseId;
  final ExerciseRepository _repository;
  final TrainingStatsRepository _statsRepository;
  final Listenable? _dataChanges;

  /// Początek „całej historii” — statystyki liczymy ze wszystkich treningów.
  static final _historyStart = DateTime(2000);

  @override
  Future<void> close() {
    _dataChanges?.removeListener(_onDataChanged);
    return super.close();
  }

  void _onDataChanged() {
    if (isClosed) return;
    unawaited(_reloadExercise());
  }

  Future<void> load() async {
    if (state.exercise == null) await _reloadExercise();
    await _loadStats();
  }

  Future<void> _reloadExercise() async {
    try {
      final all = await _repository.getAll();
      if (isClosed) return;
      final found = all.where((e) => e.id == exerciseId).firstOrNull;
      if (found == null) {
        emit(state.copyWith(loading: false, notFound: state.exercise == null));
        return;
      }
      emit(state.copyWith(exercise: found, loading: false, notFound: false));
    } catch (_) {
      if (isClosed) return;
      emit(state.copyWith(loading: false, notFound: state.exercise == null));
    }
  }

  Future<void> _loadStats() async {
    final exercise = state.exercise;
    if (exercise == null) return;
    try {
      final sessions = await _statsRepository.completedSessionsSince(
        _historyStart,
      );
      if (isClosed) return;
      emit(
        state.copyWith(stats: ExerciseStats.fromSessions(exercise, sessions)),
      );
    } catch (_) {
      if (isClosed) return;
      // Brak historii nie blokuje karty — pokazujemy stan „brak wyników”.
      emit(state.copyWith(stats: ExerciseStats.empty));
    }
  }

  /// Optymistycznie przełącza gwiazdkę; przy błędzie cofa i rzuca dalej.
  Future<void> toggleFavourite() async {
    final exercise = state.exercise;
    if (exercise == null) return;
    final next = !exercise.isFavourite;
    emit(state.copyWith(exercise: exercise.copyWith(isFavourite: next)));
    try {
      await _repository.setFavourite(exercise.id, isFavourite: next);
    } catch (_) {
      if (!isClosed) emit(state.copyWith(exercise: exercise));
      rethrow;
    }
  }

  Future<Exercise> update({
    required String name,
    required List<MuscleGroup> muscles,
    required ExerciseCategory category,
    required String description,
  }) async {
    final updated = await _repository.update(
      id: exerciseId,
      name: name,
      muscles: muscles,
      category: category,
      description: description,
    );
    if (!isClosed) {
      emit(state.copyWith(exercise: updated));
      // Zmiana nazwy zmienia dopasowanie treningów zapisanych po nazwie.
      unawaited(_loadStats());
    }
    return updated;
  }

  Future<void> delete() => _repository.delete(exerciseId);
}
