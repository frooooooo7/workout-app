import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/models/training_session.dart';
import '../../domain/repositories/training_session_repository.dart';
import '../../domain/services/workout_edit.dart';

enum EditWorkoutStatus { loading, ready, loadFailed, saving, saved }

class EditWorkoutState {
  const EditWorkoutState({
    this.status = EditWorkoutStatus.loading,
    this.original,
    this.draft,
    this.error,
    this.dirty = false,
  });

  final EditWorkoutStatus status;
  final TrainingSession? original;
  final WorkoutEditDraft? draft;

  /// Błąd walidacji albo zapisu (po polsku) do pokazania pod formularzem.
  final String? error;
  final bool dirty;

  EditWorkoutState copyWith({
    EditWorkoutStatus? status,
    TrainingSession? original,
    WorkoutEditDraft? draft,
    String? error,
    bool clearError = false,
    bool? dirty,
  }) {
    return EditWorkoutState(
      status: status ?? this.status,
      original: original ?? this.original,
      draft: draft ?? this.draft,
      error: clearError ? null : (error ?? this.error),
      dirty: dirty ?? this.dirty,
    );
  }
}

/// Edycja zakończonego treningu: formularz w pamięci, zapis offline-first
/// przez [TrainingSessionRepository.save] (`pending_op = update` → `PUT`).
class EditWorkoutCubit extends Cubit<EditWorkoutState> {
  EditWorkoutCubit(
    this._repository, {
    required this.sessionId,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       super(const EditWorkoutState());

  final TrainingSessionRepository _repository;
  final String sessionId;
  final DateTime Function() _clock;

  Future<void> load() async {
    emit(const EditWorkoutState());
    try {
      final session = await _repository.loadForEdit(sessionId);
      if (isClosed) return;
      if (session == null) {
        emit(
          const EditWorkoutState(
            status: EditWorkoutStatus.loadFailed,
            error:
                'Nie udało się wczytać treningu. Sprawdź połączenie i spróbuj ponownie.',
          ),
        );
        return;
      }
      emit(
        EditWorkoutState(
          status: EditWorkoutStatus.ready,
          original: session,
          draft: WorkoutEditDraft.fromSession(session),
        ),
      );
    } catch (_) {
      if (isClosed) return;
      emit(
        const EditWorkoutState(
          status: EditWorkoutStatus.loadFailed,
          error: 'Nie udało się wczytać treningu.',
        ),
      );
    }
  }

  void _update(WorkoutEditDraft Function(WorkoutEditDraft draft) change) {
    final draft = state.draft;
    if (draft == null || state.status != EditWorkoutStatus.ready) return;
    emit(state.copyWith(draft: change(draft), dirty: true, clearError: true));
  }

  void _updateExercises(
    List<TrainingSessionExercise> Function(List<TrainingSessionExercise>)
    change,
  ) {
    _update(
      (draft) => draft.copyWith(
        exercises: change(List<TrainingSessionExercise>.of(draft.exercises)),
      ),
    );
  }

  void _updateSet(
    int exerciseIndex,
    int setIndex,
    TrainingSessionSet Function(TrainingSessionSet set) change,
  ) {
    _updateExercises((exercises) {
      if (exerciseIndex >= exercises.length) return exercises;
      final exercise = exercises[exerciseIndex];
      if (setIndex >= exercise.sets.length) return exercises;
      final sets = List<TrainingSessionSet>.of(exercise.sets);
      sets[setIndex] = change(sets[setIndex]);
      exercises[exerciseIndex] = exercise.copyWith(sets: sets);
      return exercises;
    });
  }

  void setName(String value) => _update((d) => d.copyWith(name: value));

  void setNote(String value) => _update((d) => d.copyWith(note: value));

  void setDurationMinutes(String value) =>
      _update((d) => d.copyWith(durationMinutes: value));

  /// Data z kalendarza — godzina rozpoczęcia zostaje.
  void setStartDate(DateTime date) => _update((d) {
    final current = d.startedAt;
    return d.copyWith(
      startedAt: DateTime(
        date.year,
        date.month,
        date.day,
        current.hour,
        current.minute,
      ),
    );
  });

  void setStartTime(int hour, int minute) => _update((d) {
    final current = d.startedAt;
    return d.copyWith(
      startedAt: DateTime(
        current.year,
        current.month,
        current.day,
        hour,
        minute,
      ),
    );
  });

  void setWeight(int exerciseIndex, int setIndex, String value) => _updateSet(
    exerciseIndex,
    setIndex,
    (set) => value.trim().isEmpty
        ? set.copyWith(clearActualWeight: true)
        : set.copyWith(actualWeight: value),
  );

  void setReps(int exerciseIndex, int setIndex, String value) => _updateSet(
    exerciseIndex,
    setIndex,
    (set) => value.trim().isEmpty
        ? set.copyWith(clearActualReps: true)
        : set.copyWith(actualReps: value),
  );

  void setRir(int exerciseIndex, int setIndex, String value) => _updateSet(
    exerciseIndex,
    setIndex,
    (set) => value.trim().isEmpty
        ? set.copyWith(clearActualRir: true)
        : set.copyWith(actualRir: value),
  );

  void toggleCompleted(int exerciseIndex, int setIndex) => _updateSet(
    exerciseIndex,
    setIndex,
    (set) => set.completed
        ? set.copyWith(completed: false, clearCompletedAt: true)
        : set.copyWith(completed: true),
  );

  /// Nowa seria z wartościami poprzedniej, jeszcze nieukończona.
  void addSet(int exerciseIndex) => _updateExercises((exercises) {
    if (exerciseIndex >= exercises.length) return exercises;
    final exercise = exercises[exerciseIndex];
    final last = exercise.sets.isEmpty ? null : exercise.sets.last;
    exercises[exerciseIndex] = exercise.copyWith(
      sets: [
        ...exercise.sets,
        TrainingSessionSet(
          plannedWeight: last?.plannedWeight,
          plannedReps: last?.plannedReps ?? '',
          plannedRir: last?.plannedRir,
          plannedTempo: last?.plannedTempo,
          actualWeight: last?.actualWeight,
          actualReps: last?.actualReps,
          actualRir: last?.actualRir,
        ),
      ],
    );
    return exercises;
  });

  void removeSet(int exerciseIndex, int setIndex) =>
      _updateExercises((exercises) {
        if (exerciseIndex >= exercises.length) return exercises;
        final exercise = exercises[exerciseIndex];
        if (setIndex >= exercise.sets.length) return exercises;
        exercises[exerciseIndex] = exercise.copyWith(
          sets: List<TrainingSessionSet>.of(exercise.sets)..removeAt(setIndex),
        );
        return exercises;
      });

  void removeExercise(int exerciseIndex) => _updateExercises((exercises) {
    if (exerciseIndex < exercises.length) exercises.removeAt(exerciseIndex);
    return exercises;
  });

  void addExercise(TrainingSessionExercise exercise) =>
      _updateExercises((exercises) => exercises..add(exercise));

  /// Waliduje i zapisuje. Zwraca zapisaną sesję albo `null` (błąd w
  /// [EditWorkoutState.error]).
  Future<TrainingSession?> save() async {
    final original = state.original;
    final draft = state.draft;
    if (original == null ||
        draft == null ||
        state.status != EditWorkoutStatus.ready) {
      return null;
    }
    final error = validateWorkoutEdit(draft, now: _clock());
    if (error != null) {
      emit(state.copyWith(error: error));
      return null;
    }
    emit(state.copyWith(status: EditWorkoutStatus.saving, clearError: true));
    try {
      final saved = await _repository.save(applyWorkoutEdit(original, draft));
      if (!isClosed) {
        emit(
          state.copyWith(
            status: EditWorkoutStatus.saved,
            original: saved,
            dirty: false,
          ),
        );
      }
      return saved;
    } on TrainingSessionDeletedException {
      if (!isClosed) {
        emit(
          state.copyWith(
            status: EditWorkoutStatus.ready,
            error: 'Ten trening został usunięty — nie można go zapisać.',
          ),
        );
      }
      return null;
    } catch (_) {
      if (!isClosed) {
        emit(
          state.copyWith(
            status: EditWorkoutStatus.ready,
            error: 'Nie udało się zapisać zmian. Spróbuj ponownie.',
          ),
        );
      }
      return null;
    }
  }
}
