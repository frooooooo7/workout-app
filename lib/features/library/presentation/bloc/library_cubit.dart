import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/exercise_search.dart';
import '../../domain/models/exercise.dart';
import '../../domain/models/exercise_stats.dart';
import '../../domain/models/library_part.dart';
import '../../domain/models/library_sort.dart';
import '../../domain/repositories/exercise_repository.dart';

/// Dane ekranu startowego biblioteki: ile ćwiczeń ma każda partia i co ostatnio
/// robiłeś. Liczone z całej bazy, niezależnie od filtrów listy.
class LibraryOverview {
  const LibraryOverview({
    this.total = 0,
    this.partCounts = const {},
    this.recent = const [],
  });

  final int total;
  final Map<LibraryPart, int> partCounts;

  /// Ostatnio zrobione ćwiczenia, od najnowszego.
  final List<Exercise> recent;

  @override
  bool operator ==(Object other) =>
      other is LibraryOverview &&
      other.total == total &&
      mapEquals(other.partCounts, partCounts) &&
      listEquals(other.recent, recent);

  @override
  int get hashCode =>
      Object.hash(total, Object.hashAll(partCounts.entries.map((e) => (e.key, e.value))), Object.hashAll(recent));
}

class LibraryState {
  const LibraryState({
    this.filter = LibraryFilter.all,
    this.category = MuscleGroup.all,
    this.query = '',
    this.sort = LibrarySort.popular,
    this.types = const {},
    this.equipment = const {},
    this.muscles = const {},
    this.exercises = const [],
    this.loading = true,
    this.error,
    this.overview = const LibraryOverview(),
    this.usage = ExerciseUsage.empty,
  });

  final LibraryFilter filter;
  final MuscleGroup category;
  final String query;
  final LibrarySort sort;

  /// Filtr typu ćwiczenia (wielostaw, izolacja…); pusty zbiór — wszystkie.
  final Set<ExerciseCategory> types;

  /// Filtr sprzętu; pusty zbiór — każdy. Ćwiczenia bez znanego sprzętu znikają,
  /// gdy filtr jest włączony.
  final Set<ExerciseEquipment> equipment;

  /// Filtr mięśni z arkusza „Filtry” (dowolny z wybranych); pusty — wszystkie.
  final Set<MuscleGroup> muscles;

  /// Ile filtrów z arkusza jest włączonych (plakietka przy „Filtry”).
  int get activeFilterCount => types.length + equipment.length + muscles.length;

  final List<Exercise> exercises;
  final bool loading;
  final String? error;
  final LibraryOverview overview;

  /// Historia treningów — z niej wiersze listy biorą „ostatni wynik”.
  final ExerciseUsage usage;

  LibraryState copyWith({
    LibraryFilter? filter,
    MuscleGroup? category,
    String? query,
    LibrarySort? sort,
    Set<ExerciseCategory>? types,
    Set<ExerciseEquipment>? equipment,
    Set<MuscleGroup>? muscles,
    ExerciseUsage? usage,
    List<Exercise>? exercises,
    bool? loading,
    String? error,
    LibraryOverview? overview,
    bool clearError = false,
  }) {
    return LibraryState(
      filter: filter ?? this.filter,
      category: category ?? this.category,
      query: query ?? this.query,
      sort: sort ?? this.sort,
      types: types ?? this.types,
      equipment: equipment ?? this.equipment,
      muscles: muscles ?? this.muscles,
      usage: usage ?? this.usage,
      exercises: exercises ?? this.exercises,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      overview: overview ?? this.overview,
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
        setEquals(other.equipment, equipment) &&
        setEquals(other.muscles, muscles) &&
        identical(other.usage, usage) &&
        listEquals(other.exercises, exercises) &&
        other.loading == loading &&
        other.error == error &&
        other.overview == overview;
  }

  @override
  int get hashCode => Object.hash(
    filter,
    category,
    query,
    sort,
    Object.hashAllUnordered(types),
    Object.hashAllUnordered(equipment),
    Object.hashAllUnordered(muscles),
    usage,
    Object.hashAll(exercises),
    loading,
    error,
    overview,
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

  /// Cała baza ćwiczeń (bez filtrów) — do podglądu liczby wyników filtrów.
  List<Exercise> _all = const [];

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

  /// Numer ostatniego zapytania — spóźniona odpowiedź na poprzedni filtr nie
  /// może nadpisać listy.
  int _refreshSeq = 0;

  Future<void> refresh({bool showLoadingIndicator = true}) async {
    if (isClosed) return;
    final seq = ++_refreshSeq;
    final filter = state.filter;
    final query = state.query;
    if (showLoadingIndicator) {
      emit(state.copyWith(loading: true, clearError: true));
    }
    try {
      // „Ostatnio robione” liczymy z historii treningów, a nie z bazy, więc
      // repozytorium dostaje wtedy pełną listę.
      final recent = filter == LibraryFilter.recent;
      final result = await _repository.getAll(
        filter: recent ? LibraryFilter.all : filter,
        muscleGroup: state.category,
        query: query,
      );
      // Historia jest potrzebna też do „ostatniego wyniku” w wierszach.
      await _ensureUsage();
      if (isClosed || seq != _refreshSeq) return;
      _source = result;
      emit(
        state.copyWith(
          usage: _usage,
          exercises: _arrange(result),
          loading: false,
          clearError: true,
        ),
      );
      unawaited(_refreshOverview(seq));
    } catch (_) {
      if (isClosed || seq != _refreshSeq) return;
      emit(
        state.copyWith(
          loading: false,
          error: 'Nie można załadować ćwiczeń z pamięci telefonu.',
        ),
      );
    }
  }

  /// Przelicza dane ekranu startowego (liczby przy partiach, „Ostatnio robione”).
  /// Błąd tu nie psuje listy — ekran startowy po prostu zostaje bez zmian.
  Future<void> _refreshOverview(int seq) async {
    try {
      final all = await _repository.getAll(
        filter: LibraryFilter.all,
        muscleGroup: MuscleGroup.all,
        query: '',
      );
      await _ensureUsage();
      if (isClosed || seq != _refreshSeq) return;
      _all = all;
      final usage = _usage ?? ExerciseUsage.empty;
      final dated = [
        for (final e in all)
          if (usage.lastDoneFor(e) case final date?) (date, e),
      ]..sort((a, b) => b.$1.compareTo(a.$1));
      emit(
        state.copyWith(
          overview: LibraryOverview(
            total: all.length,
            partCounts: {
              for (final part in LibraryPart.values) part: part.countIn(all),
            },
            recent: [for (final item in dated.take(8)) item.$2],
          ),
        ),
      );
    } catch (_) {
      // Zostaje poprzedni stan ekranu startowego.
    }
  }

  Future<ExerciseUsage>? _usageLoad;

  Future<void> _ensureUsage() async {
    final load = _loadUsage;
    if (_usage != null || load == null) return;
    // Jedno wczytanie historii, nawet gdy kilka odświeżeń startuje naraz.
    _usageLoad ??= load();
    try {
      _usage = await _usageLoad;
    } catch (_) {
      // Bez historii „Popularne” zostawia kolejność bazy — to nie jest błąd
      // biblioteki.
      _usage = ExerciseUsage.empty;
    }
  }

  /// Filtry z arkusza „Filtry” (łączone „i”). Ćwiczenie bez podanego sprzętu
  /// liczy się jako „Inne”. Dokładny mięsień dopuszcza też ogólną grupę
  /// (starsze własne ćwiczenia mają tag „Plecy”, nie „Najszersze”).
  static List<Exercise> _applyFilters(
    List<Exercise> source, {
    required Set<ExerciseCategory> types,
    required Set<ExerciseEquipment> equipment,
    required Set<MuscleGroup> muscles,
  }) {
    final muscleMatches = {
      for (final m in muscles) ...[
        ...m.filterMatches,
        if (m.broadGroup.isCoarse) m.broadGroup,
      ],
    };
    return source.where((e) {
      if (types.isNotEmpty && !types.contains(e.category)) return false;
      if (equipment.isNotEmpty &&
          !equipment.contains(e.equipment ?? ExerciseEquipment.other)) {
        return false;
      }
      if (muscleMatches.isNotEmpty && !e.muscles.any(muscleMatches.contains)) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Ile ćwiczeń z całej bazy zostanie po takich filtrach — liczba na przycisku
  /// arkusza „Filtry”.
  int previewCount({
    Set<ExerciseCategory> types = const {},
    Set<ExerciseEquipment> equipment = const {},
    Set<MuscleGroup> muscles = const {},
  }) => _applyFilters(
    _all,
    types: types,
    equipment: equipment,
    muscles: muscles,
  ).length;

  List<Exercise> _arrange(
    List<Exercise> source, {
    Set<ExerciseCategory>? types,
    Set<ExerciseEquipment>? equipment,
    Set<MuscleGroup>? muscles,
    LibrarySort? sort,
  }) {
    final filtered = _applyFilters(
      source,
      types: types ?? state.types,
      equipment: equipment ?? state.equipment,
      muscles: muscles ?? state.muscles,
    );
    final usage = _usage ?? ExerciseUsage.empty;
    final activeSort = sort ?? state.sort;
    if (state.filter == LibraryFilter.recent) {
      // Tylko to, co było w ukończonym treningu, od ostatnio zrobionego.
      final dated = [
        for (final e in filtered)
          if (usage.lastDoneFor(e) case final date?) (date, e),
      ]..sort((a, b) => b.$1.compareTo(a.$1));
      return [for (final item in dated) item.$2];
    }
    // Przy wpisanym tekście domyślne „Popularne” zamienia się w trafność
    // (przy remisie to, co robisz częściej); wybrane przez Ciebie inne
    // sortowanie zostaje.
    if (state.query.trim().isNotEmpty && activeSort == LibrarySort.popular) {
      final scored =
          [
            for (final (i, e) in filtered.indexed)
              (
                ExerciseSearch.score(e, state.query) ?? 0,
                usage.countFor(e),
                i,
                e,
              ),
          ]..sort((a, b) {
            if (a.$1 != b.$1) return b.$1.compareTo(a.$1);
            if (a.$2 != b.$2) return b.$2.compareTo(a.$2);
            return a.$3.compareTo(b.$3);
          });
      return [for (final item in scored) item.$4];
    }
    return sortExercises(filtered, activeSort, usage: _usage);
  }

  Future<void> setSort(LibrarySort sort) async {
    if (sort == state.sort) return;
    emit(state.copyWith(sort: sort));
    if (sort == LibrarySort.popular) await _ensureUsage();
    if (isClosed) return;
    emit(state.copyWith(exercises: _arrange(_source)));
  }

  void setTypes(Set<ExerciseCategory> types) {
    setFilters(types: types);
  }

  /// Ustawia filtry z arkusza „Filtry”; pominięty argument zostaje bez zmian.
  void setFilters({
    Set<ExerciseCategory>? types,
    Set<ExerciseEquipment>? equipment,
    Set<MuscleGroup>? muscles,
  }) {
    final nextTypes = Set<ExerciseCategory>.unmodifiable(types ?? state.types);
    final nextEquipment = Set<ExerciseEquipment>.unmodifiable(
      equipment ?? state.equipment,
    );
    final nextMuscles = Set<MuscleGroup>.unmodifiable(
      muscles ?? state.muscles,
    );
    emit(
      state.copyWith(
        types: nextTypes,
        equipment: nextEquipment,
        muscles: nextMuscles,
        exercises: _arrange(
          _source,
          types: nextTypes,
          equipment: nextEquipment,
          muscles: nextMuscles,
        ),
      ),
    );
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
    ExerciseTracking tracking = ExerciseTracking.weightReps,
    DistanceUnit distanceUnit = DistanceUnit.km,
  }) async {
    final updated = await _repository.update(
      id: id,
      name: name,
      muscles: muscles,
      category: category,
      description: description,
      tracking: tracking,
      distanceUnit: distanceUnit,
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
    ExerciseTracking tracking = ExerciseTracking.weightReps,
    DistanceUnit distanceUnit = DistanceUnit.km,
  }) async {
    final created = await _repository.create(
      name: name,
      muscles: muscles,
      category: category,
      description: description,
      imageBytes: imageBytes,
      imageFilename: imageFilename,
      tracking: tracking,
      distanceUnit: distanceUnit,
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
