import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/exercise.dart';
import '../bloc/library_cubit.dart';
import '../widgets/library_add_exercise_sheet.dart';
import '../widgets/library_category_tabs.dart';
import '../widgets/library_empty_state.dart';
import '../widgets/library_error_state.dart';
import '../widgets/library_exercise_grid.dart';
import '../widgets/library_filter_chips.dart';
import '../widgets/library_header.dart';
import '../widgets/library_loading_state.dart';
import '../widgets/library_results_bar.dart';

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

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          LibraryCubit(ServiceLocator.exerciseRepository)..refresh(),
      child: BlocBuilder<LibraryCubit, LibraryState>(
        builder: (context, state) {
          final cubit = context.read<LibraryCubit>();

          return Scaffold(
            backgroundColor: AppColors.background,
            body: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LibraryHeader(
                          searchController: _searchController,
                          onSearchChanged: cubit.setQuery,
                          onFilterTap: () {},
                          onBackTap: () {
                            if (context.canPop()) {
                              context.pop();
                              return;
                            }
                            context.go('/app/training');
                          },
                          onAddTap: () async {
                            final created = await showLibraryAddExerciseSheet(
                              context,
                              onSubmit: ({
                                required String name,
                                required List<MuscleGroup> muscles,
                                required ExerciseCategory category,
                                required String description,
                                Uint8List? imageBytes,
                                String? imageFilename,
                              }) =>
                                  cubit.createExercise(
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
                        const SizedBox(height: 14),
                        LibraryFilterChips(
                          selected: state.filter,
                          onSelected: cubit.setFilter,
                        ),
                        const SizedBox(height: 14),
                        LibraryCategoryTabs(
                          selected: state.category,
                          onSelected: cubit.setCategory,
                        ),
                        const SizedBox(height: 14),
                        LibraryResultsBar(count: state.exercises.length),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: state.loading
                        ? const LibraryLoadingState()
                        : state.error != null
                            ? LibraryErrorState(message: state.error!)
                            : state.exercises.isEmpty
                                ? const LibraryEmptyState()
                                : LibraryExerciseGrid(
                                    exercises: state.exercises,
                                    onFavouriteTap: (exercise) async {
                                      try {
                                        await cubit.toggleFavourite(
                                          exercise,
                                        );
                                      } catch (_) {
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Nie udało się zaktualizować ulubionych.',
                                            ),
                                            behavior:
                                                SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    },
                                  ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
