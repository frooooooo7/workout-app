import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_tab_header.dart';
import '../../domain/models/exercise.dart';
import '../../domain/models/exercise_stats.dart';
import '../bloc/library_cubit.dart';
import '../widgets/exercise_actions_sheet.dart';
import '../widgets/library_add_exercise_sheet.dart';
import '../widgets/library_category_tabs.dart';
import '../widgets/library_empty_state.dart';
import '../widgets/library_error_state.dart';
import '../widgets/library_exercise_grid.dart';
import '../widgets/library_filter_chips.dart';
import '../widgets/library_header.dart';
import '../widgets/library_loading_state.dart';
import '../widgets/library_results_bar.dart';
import '../widgets/library_sort_sheet.dart';
import '../widgets/library_type_filter_sheet.dart';
import 'exercise_details_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      _showMessage(context, 'Usunięto ćwiczenie.');
    }
  }

  Future<void> _editExercise(BuildContext context, Exercise exercise) async {
    final cubit = context.read<LibraryCubit>();
    final updated = await showLibraryEditExerciseSheet(
      context,
      exercise: exercise,
      onSubmit:
          ({
            required String name,
            required List<MuscleGroup> muscles,
            required ExerciseCategory category,
            required String description,
          }) => cubit.updateExercise(
            id: exercise.id,
            name: name,
            muscles: muscles,
            category: category,
            description: description,
          ),
    );
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

  Future<void> _pickTypes(BuildContext context) async {
    final cubit = context.read<LibraryCubit>();
    final types = await showLibraryTypeFilterSheet(
      context,
      selected: cubit.state.types,
    );
    if (types != null) cubit.setTypes(types);
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

          return Scaffold(
            backgroundColor: AppColors.background,
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
                                previous.types != current.types,
                            builder: (context, state) => LibraryHeader(
                              searchController: _searchController,
                              onSearchChanged: cubit.setQuery,
                              activeFilterCount: state.types.length,
                              onFilterTap: () => _pickTypes(context),
                              onBackTap: () {
                                if (context.canPop()) {
                                  context.pop();
                                  return;
                                }
                                context.go('/app/training');
                              },
                              onAddTap: () async {
                                final created =
                                    await showLibraryAddExerciseSheet(
                                      context,
                                      onSubmit:
                                          ({
                                            required String name,
                                            required List<MuscleGroup> muscles,
                                            required ExerciseCategory category,
                                            required String description,
                                            Uint8List? imageBytes,
                                            String? imageFilename,
                                          }) => cubit.createExercise(
                                            name: name,
                                            muscles: muscles,
                                            category: category,
                                            description: description,
                                            imageBytes: imageBytes,
                                            imageFilename: imageFilename,
                                          ),
                                    );
                                if (!context.mounted) return;
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
                          const SizedBox(height: 14),
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
                            previous.error != current.error,
                        builder: (context, state) {
                          if (state.loading) {
                            return const LibraryLoadingState();
                          }
                          if (state.error != null) {
                            return LibraryErrorState(message: state.error!);
                          }
                          if (state.exercises.isEmpty) {
                            return const LibraryEmptyState();
                          }
                          return LibraryExerciseGrid(
                            exercises: state.exercises,
                            onFavouriteTap: (exercise) =>
                                _toggleFavourite(context, exercise),
                            onExerciseTap: (exercise) =>
                                _openDetails(context, exercise),
                            onMoreTap: (exercise) =>
                                _showActions(context, exercise),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
