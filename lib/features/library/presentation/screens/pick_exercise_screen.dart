import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../bloc/library_cubit.dart';
import '../widgets/library_category_tabs.dart';
import '../widgets/library_empty_state.dart';
import '../widgets/library_error_state.dart';
import '../widgets/library_filter_chips.dart';
import '../widgets/library_loading_state.dart';
import '../widgets/library_results_bar.dart';

class PickExerciseScreen extends StatefulWidget {
  const PickExerciseScreen({super.key});

  @override
  State<PickExerciseScreen> createState() => _PickExerciseScreenState();
}

class _PickExerciseScreenState extends State<PickExerciseScreen> {
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
            appBar: AppBar(
              backgroundColor: AppColors.background,
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white),
              title: const Text(
                'Wybierz ćwiczenie',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            body: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _searchController,
                          onChanged: cubit.setQuery,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Szukaj ćwiczeń...',
                            hintStyle: const TextStyle(color: AppColors.textMuted),
                            prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                            filled: true,
                            fillColor: AppColors.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
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
                                : ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                                    itemCount: state.exercises.length,
                                    itemBuilder: (context, index) {
                                      final exercise = state.exercises[index];
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: InkWell(
                                          onTap: () {
                                            Navigator.of(context).pop(exercise);
                                          },
                                          borderRadius: BorderRadius.circular(16),
                                          child: Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: AppColors.surface,
                                              borderRadius: BorderRadius.circular(16),
                                              border: Border.all(color: AppColors.border),
                                            ),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 56,
                                                  height: 56,
                                                  decoration: BoxDecoration(
                                                    color: AppColors.surfaceVariant,
                                                    borderRadius: BorderRadius.circular(12),
                                                    image: exercise.imageUrl != null
                                                        ? DecorationImage(
                                                            image: NetworkImage(exercise.imageUrl!),
                                                            fit: BoxFit.cover,
                                                          )
                                                        : null,
                                                  ),
                                                  child: exercise.imageUrl == null
                                                      ? const Icon(Icons.fitness_center, color: AppColors.textMuted)
                                                      : null,
                                                ),
                                                const SizedBox(width: 16),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        exercise.name,
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 16,
                                                          fontWeight: FontWeight.w700,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        exercise.muscles.map((m) => m.label).join(', '),
                                                        style: const TextStyle(
                                                          color: AppColors.textSecondary,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
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
