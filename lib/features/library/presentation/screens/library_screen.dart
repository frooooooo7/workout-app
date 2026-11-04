import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_tab_header.dart';
import '../../domain/models/exercise.dart';
import '../../domain/models/exercise_stats.dart';
import '../../domain/models/library_part.dart';
import '../bloc/library_cubit.dart';
import '../widgets/exercise_actions_sheet.dart';
import '../widgets/exercise_card_illustration.dart';
import '../widgets/library_add_exercise_sheet.dart';
import '../widgets/library_category_tabs.dart';
import '../widgets/library_empty_state.dart';
import '../widgets/library_error_state.dart';
import '../widgets/library_exercise_list.dart';
import '../widgets/library_start_view.dart';
import '../widgets/library_filter_chips.dart';
import '../widgets/library_filters_sheet.dart';
import '../widgets/library_header.dart';
import '../widgets/library_loading_state.dart';
import '../widgets/library_results_bar.dart';
import '../widgets/library_sort_sheet.dart';
import 'exercise_details_screen.dart';

class LibraryScreen extends StatefulWidget {
  /// [pickMode] — wybór ćwiczeń do planu albo treningu: stuknięcie zaznacza
  /// (wielokrotny wybór), na dole pojawia się „Dodaj N ćwiczeń”, a ekran
  /// zwraca `List<Exercise>`. Szczegóły ćwiczenia: przytrzymanie wiersza.
  const LibraryScreen({
    super.key,
    this.pickMode = false,
    this.pickTitle = 'Wybierz ćwiczenia',
    this.pickSubtitle,
    this.existingIds = const {},
    this.existingLabel = 'W planie',
  });

  final bool pickMode;
  final String pickTitle;
  final String? pickSubtitle;

  /// Tryb wyboru: id ćwiczeń już dodanych (plakietka „W planie”).
  final Set<String> existingIds;

  /// Tekst plakietki przy takich ćwiczeniach („W planie”, „W treningu”).
  final String existingLabel;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _searchController = TextEditingController();

  /// `true` po wybraniu partii albo „Wszystkie” — pokazujemy listę zamiast
  /// ekranu startowego (wpisanie tekstu też ją pokazuje).
  bool _browsing = false;

  /// Zaznaczone ćwiczenia w kolejności wyboru; zostają przy zmianie filtrów.
  final Map<String, Exercise> _selected = {};

  void _toggleSelected(Exercise exercise) {
    setState(() {
      if (_selected.remove(exercise.id) == null) {
        _selected[exercise.id] = exercise;
      }
    });
  }

  /// Zaznaczone ćwiczenie mogło zostać zmienione albo usunięte w karcie lub
  /// menu: podmieniamy je na aktualne dane albo wyrzucamy z wyboru.
  void _refreshSelectedFrom(Exercise? updated, {String? removedId}) {
    if (!widget.pickMode) return;
    setState(() {
      if (removedId != null) _selected.remove(removedId);
      if (updated != null && _selected.containsKey(updated.id)) {
        _selected[updated.id] = updated;
      }
    });
  }

  /// Wyjście z wyboru z zaznaczeniem pytamy o potwierdzenie, żeby nie zgubić
  /// wyboru jednym gestem „wstecz”.
  Future<void> _confirmDiscardSelection() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Porzucić wybór?'),
        content: Text(
          'Masz zaznaczone: ${exerciseCountLabel(_selected.length)}. '
          'Wyjście bez dodawania je odrzuci.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Zostań'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Porzuć'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      setState(_selected.clear);
      Navigator.of(context).pop();
    }
  }

  void _tapExercise(BuildContext context, Exercise exercise) {
    if (widget.pickMode) {
      _toggleSelected(exercise);
    } else {
      _openDetails(context, exercise);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Czy widać ekran startowy: nic nie wybrano i nic nie wpisano.
  bool get _atStartScreen => !_browsing && _searchController.text.trim().isEmpty;

  /// Z listy albo wyników szukania wracamy krok wstecz do ekranu startowego
  /// i czyścimy filtry, żeby liczby przy partiach zgadzały się z listą.
  void _backToStart(LibraryCubit cubit) {
    _searchController.clear();
    cubit.setQuery('');
    cubit.setCategory(MuscleGroup.all);
    cubit.setFilter(LibraryFilter.all);
    cubit.setFilters(
      types: const {},
      equipment: const {},
      muscles: const {},
    );
    setState(() => _browsing = false);
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _toggleFavourite(BuildContext context, Exercise exercise) async {
    try {
      await context.read<LibraryCubit>().toggleFavourite(exercise);
    } catch (_) {
      if (!context.mounted) return;
      _showMessage(context, 'Nie udało się zaktualizować ulubionych.');
    }
  }

  Future<void> _openDetails(BuildContext context, Exercise exercise) async {
    final cubit = context.read<LibraryCubit>();
    final result = await openExerciseDetails(context, exercise);
    if (!context.mounted) return;
    // Karta mogła zmienić gwiazdkę, nazwę albo usunąć ćwiczenie.
    await cubit.refresh(showLoadingIndicator: false);
    if (!context.mounted) return;
    if (result == ExerciseDetailsResult.deleted) {
      _refreshSelectedFrom(null, removedId: exercise.id);
    } else if (widget.pickMode && _selected.containsKey(exercise.id)) {
      // Karta mogła zmienić nazwę — bierzemy aktualną wersję z bazy.
      try {
        final all = await ServiceLocator.exerciseRepository.getAll();
        final fresh = all.where((e) => e.id == exercise.id);
        if (fresh.isNotEmpty) _refreshSelectedFrom(fresh.first);
      } catch (_) {}
      if (!context.mounted) return;
    }
    if (result == ExerciseDetailsResult.deleted) {
      _showMessage(context, 'Usunięto ćwiczenie.');
    }
  }

  Future<void> _editExercise(BuildContext context, Exercise exercise) async {
    final cubit = context.read<LibraryCubit>();
    final existing = await cubit.allExercises();
    if (!context.mounted) return;
    final updated = await showLibraryEditExerciseSheet(
      context,
      exercise: exercise,
      existing: existing,
      onSubmit:
          ({
            required String name,
            required List<MuscleGroup> muscles,
            required ExerciseCategory category,
            required String description,
            required ExerciseTracking tracking,
            required DistanceUnit distanceUnit,
            required ExerciseExtras extras,
          }) => cubit.updateExercise(
            id: exercise.id,
            name: name,
            muscles: muscles,
            category: category,
            description: description,
            tracking: tracking,
            distanceUnit: distanceUnit,
            extras: extras,
          ),
    );
    if (updated != null) _refreshSelectedFrom(updated);
    if (updated != null && context.mounted) {
      _showMessage(context, 'Zapisano zmiany.');
    }
  }

  Future<void> _deleteExercise(BuildContext context, Exercise exercise) async {
    final cubit = context.read<LibraryCubit>();
    final confirmed = await confirmDeleteExercise(context, exercise);
    if (!confirmed || !context.mounted) return;
    try {
      await cubit.deleteExercise(exercise);
      _refreshSelectedFrom(null, removedId: exercise.id);
      if (context.mounted) _showMessage(context, 'Usunięto ćwiczenie.');
    } catch (_) {
      if (context.mounted) {
        _showMessage(context, 'Nie udało się usunąć ćwiczenia.');
      }
    }
  }

  Future<void> _showActions(BuildContext context, Exercise exercise) async {
    final action = await showExerciseActionsSheet(context, exercise: exercise);
    if (!context.mounted || action == null) return;
    switch (action) {
      case ExerciseAction.details:
        await _openDetails(context, exercise);
      case ExerciseAction.favourite:
        await _toggleFavourite(context, exercise);
      case ExerciseAction.edit:
        await _editExercise(context, exercise);
      case ExerciseAction.delete:
        await _deleteExercise(context, exercise);
    }
  }

  Future<void> _pickSort(BuildContext context) async {
    final cubit = context.read<LibraryCubit>();
    final sort = await showLibrarySortSheet(context, current: cubit.state.sort);
    if (sort != null) await cubit.setSort(sort);
  }

  Future<void> _pickFilters(BuildContext context) async {
    final cubit = context.read<LibraryCubit>();
    final state = cubit.state;
    final selection = await showLibraryFiltersSheet(
      context,
      selected: LibraryFilterSelection(
        muscles: state.muscles,
        equipment: state.equipment,
        types: state.types,
        sort: state.sort,
      ),
      countFor: (selection) => cubit.previewCount(
        types: selection.types,
        equipment: selection.equipment,
        muscles: selection.muscles,
      ),
    );
    if (selection == null) return;
    cubit.setFilters(
      types: selection.types,
      equipment: selection.equipment,
      muscles: selection.muscles,
    );
    await cubit.setSort(selection.sort);
    final any = selection.types.isNotEmpty ||
        selection.equipment.isNotEmpty ||
        selection.muscles.isNotEmpty;
    // Filtry z arkusza działają na całej bazie, więc kafelek partii nie może
    // ich dodatkowo zawężać; z ekranu startowego idziemy od razu do wyników.
    if (any) {
      cubit.setCategory(MuscleGroup.all);
      if (mounted) setState(() => _browsing = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LibraryCubit(
        ServiceLocator.exerciseRepository,
        dataChanges: ServiceLocator.exerciseDataChanges,
        loadUsage: () async => ExerciseStats.usage(
          await ServiceLocator.trainingStatsRepository.completedSessionsSince(
            DateTime(2000),
          ),
        ),
      )..refresh(),
      child: Builder(
        builder: (context) {
          final cubit = context.read<LibraryCubit>();

          return PopScope(
            // Systemowy „wstecz” z listy lub wyników szukania wraca na ekran
            // startowy, dopiero stamtąd zamyka bibliotekę.
            canPop:
                _atStartScreen && !(widget.pickMode && _selected.isNotEmpty),
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) return;
              if (_atStartScreen) {
                _confirmDiscardSelection();
              } else {
                _backToStart(cubit);
              }
            },
            child: Scaffold(
            backgroundColor: AppColors.background,
            bottomNavigationBar: widget.pickMode && _selected.isNotEmpty
                ? SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: SizedBox(
                        height: 52,
                        child: Row(
                          children: [
                            _SelectedThumbs(
                              exercises: _selected.values.toList(),
                            ),
                            Expanded(child: ElevatedButton(
                          onPressed: () => Navigator.of(
                            context,
                          ).pop(_selected.values.toList()),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            'Dodaj ${exerciseCountLabel(_selected.length)}',
                          ),
                        )),
                          ],
                        ),
                      ),
                    ),
                  )
                : null,
            body: AppTabBackground(
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          BlocBuilder<LibraryCubit, LibraryState>(
                            buildWhen: (previous, current) =>
                                previous.activeFilterCount !=
                                current.activeFilterCount,
                            builder: (context, state) => LibraryHeader(
                              title: widget.pickMode
                                  ? widget.pickTitle
                                  : 'Biblioteka',
                              subtitle:
                                  widget.pickMode ? widget.pickSubtitle : null,
                              searchController: _searchController,
                              onSearchChanged: (query) {
                                cubit.setQuery(query);
                                // Odświeża `PopScope` i wybór ekranu: z
                                // tekstem „wstecz” czyści wyniki.
                                setState(() {});
                              },
                              activeFilterCount: state.activeFilterCount,
                              onFilterTap: () => _pickFilters(context),
                              onBackTap: () {
                                if (_atStartScreen) {
                                  if (widget.pickMode) {
                                    Navigator.of(context).maybePop();
                                    return;
                                  }
                                  if (context.canPop()) {
                                    context.pop();
                                    return;
                                  }
                                  context.go('/app/training');
                                  return;
                                }
                                _backToStart(cubit);
                              },
                              onAddTap: () async {
                                final existing = await cubit.allExercises();
                                if (!context.mounted) return;
                                final created =
                                    await showLibraryAddExerciseSheet(
                                      context,
                                      existing: existing,
                                      // Podobne ćwiczenie już jest: w trybie
                                      // wyboru zaznaczamy je, w bibliotece
                                      // otwieramy jego kartę.
                                      onUseSimilar: (exercise) {
                                        if (widget.pickMode) {
                                          setState(
                                            () => _selected[exercise.id] =
                                                exercise,
                                          );
                                        } else {
                                          _openDetails(context, exercise);
                                        }
                                      },
                                      onSubmit:
                                          ({
                                            required String name,
                                            required List<MuscleGroup> muscles,
                                            required ExerciseCategory category,
                                            required String description,
                                            required ExerciseTracking tracking,
                                            required DistanceUnit distanceUnit,
                                            required ExerciseExtras extras,
                                            Uint8List? imageBytes,
                                            String? imageFilename,
                                          }) => cubit.createExercise(
                                            name: name,
                                            muscles: muscles,
                                            category: category,
                                            description: description,
                                            tracking: tracking,
                                            distanceUnit: distanceUnit,
                                            extras: extras,
                                            imageBytes: imageBytes,
                                            imageFilename: imageFilename,
                                          ),
                                    );
                                if (!context.mounted) return;
                                if (created != null && widget.pickMode) {
                                  // Nowe ćwiczenie od razu trafia do wyboru.
                                  setState(
                                    () => _selected[created.id] = created,
                                  );
                                }
                                if (created != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        created.isPendingSync
                                            ? 'Dodano ćwiczenie. Synchronizacja w toku…'
                                            : 'Dodano ćwiczenie do biblioteki.',
                                      ),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: BlocBuilder<LibraryCubit, LibraryState>(
                        buildWhen: (previous, current) =>
                            previous.query.trim().isEmpty !=
                                current.query.trim().isEmpty ||
                            previous.overview != current.overview ||
                            previous.loading != current.loading,
                        builder: (context, state) {
                          if (!_browsing && state.query.trim().isEmpty) {
                            return LibraryStartView(
                              overview: state.overview,
                              onPartTap: (part) {
                                setState(() => _browsing = true);
                                cubit.setCategory(part.group);
                              },
                              onShowAll: () {
                                setState(() => _browsing = true);
                                cubit.setCategory(MuscleGroup.all);
                              },
                              selectedIds: _selected.keys.toSet(),
                              selectionOrder: _selected.keys.toList(),
                              onExerciseTap: (exercise) =>
                                  _tapExercise(context, exercise),
                            );
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                          BlocBuilder<LibraryCubit, LibraryState>(
                            buildWhen: (previous, current) =>
                                previous.filter != current.filter ||
                                previous.category != current.category,
                            builder: (context, state) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  LibraryFilterChips(
                                    selected: state.filter,
                                    onSelected: cubit.setFilter,
                                  ),
                                  const SizedBox(height: 14),
                                  LibraryCategoryTabs(
                                    selected: state.category,
                                    onSelected: cubit.setCategory,
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 14),
                          BlocBuilder<LibraryCubit, LibraryState>(
                            buildWhen: (previous, current) =>
                                previous.activeFilterCount != current.activeFilterCount,
                            builder: (context, state) {
                              if (state.activeFilterCount == 0) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Aktywne filtry: ${state.activeFilterCount}',
                                        style: const TextStyle(
                                          color: AppColors.primaryVariant,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => cubit.setFilters(
                                        types: const {},
                                        equipment: const {},
                                        muscles: const {},
                                      ),
                                      behavior: HitTestBehavior.opaque,
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 4),
                                        child: Text(
                                          'Wyczyść filtry',
                                          style: TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          BlocBuilder<LibraryCubit, LibraryState>(
                            buildWhen: (previous, current) =>
                                previous.exercises != current.exercises ||
                                previous.loading != current.loading ||
                                previous.error != current.error ||
                                previous.sort != current.sort,
                            builder: (context, state) {
                              return LibraryResultsBar(
                                count: state.exercises.length,
                                sort: state.sort,
                                onSortTap: () => _pickSort(context),
                              );
                            },
                          ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              const AppTabScrollEdge(),
                              Expanded(
                      child: BlocBuilder<LibraryCubit, LibraryState>(
                        buildWhen: (previous, current) =>
                            previous.exercises != current.exercises ||
                            previous.loading != current.loading ||
                            previous.error != current.error ||
                            !identical(previous.usage, current.usage),
                        builder: (context, state) {
                          if (state.loading) {
                            return const LibraryLoadingState();
                          }
                          if (state.error != null) {
                            return LibraryErrorState(message: state.error!);
                          }
                          if (state.exercises.isEmpty) {
                            return LibraryEmptyState(
                              message: state.filter == LibraryFilter.recent && state.query.isEmpty
                                  ? 'Ta lista zapełni się po Twoim pierwszym treningu.'
                                  : null,
                            );
                          }
                          return LibraryExerciseList(
                            exercises: state.exercises,
                            usage: state.usage,
                            onFavouriteTap: (exercise) =>
                                _toggleFavourite(context, exercise),
                            selectedIds: widget.pickMode
                                ? _selected.keys.toSet()
                                : null,
                            selectionOrder: _selected.keys.toList(),
                            existingIds: widget.existingIds,
                            existingLabel: widget.existingLabel,
                            onExerciseTap: (exercise) =>
                                _tapExercise(context, exercise),
                            onMoreTap: (exercise) =>
                                _showActions(context, exercise),
                          );
                        },
                      ),
                    ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ),
          );
        },
      ),
    );
  }
}

/// Pasek na dole w trybie wyboru: miniatury ostatnich zaznaczonych ćwiczeń.
class _SelectedThumbs extends StatelessWidget {
  const _SelectedThumbs({required this.exercises});

  final List<Exercise> exercises;

  @override
  Widget build(BuildContext context) {
    final shown = exercises.reversed.take(3).toList().reversed.toList();
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final exercise in shown)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: ExerciseCardIllustration(exercise: exercise),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
