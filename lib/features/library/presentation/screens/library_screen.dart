import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/exercise.dart';
import '../widgets/exercise_card.dart';
import '../widgets/library_category_tabs.dart';
import '../widgets/library_filter_chips.dart';
import '../widgets/library_header.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  LibraryFilter _filter = LibraryFilter.all;
  MuscleGroup _category = MuscleGroup.all;
  String _query = '';
  final _searchController = TextEditingController();

  final Set<String> _favouriteIds = {
    for (final e in mockExercises)
      if (e.isFavourite) e.id
  };

  List<Exercise> get _filtered {
    return mockExercises.where((e) {
      if (_filter == LibraryFilter.mine && !e.isMine) return false;
      if (_filter == LibraryFilter.favourite &&
          !_favouriteIds.contains(e.id)) {
        return false;
      }
      if (_filter == LibraryFilter.recent && !e.isMine && !e.isFavourite) {
        return false;
      }
      if (_category != MuscleGroup.all && !e.muscles.contains(_category)) {
        return false;
      }
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        final matchName = e.name.toLowerCase().contains(q);
        final matchMuscle =
            e.muscles.any((m) => m.label.toLowerCase().contains(q));
        if (!matchName && !matchMuscle) return false;
      }
      return true;
    }).toList();
  }

  void _toggleFavourite(Exercise exercise) {
    setState(() {
      if (_favouriteIds.contains(exercise.id)) {
        _favouriteIds.remove(exercise.id);
      } else {
        _favouriteIds.add(exercise.id);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exercises = _filtered;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Static top section (not scrolling)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LibraryHeader(
                    searchController: _searchController,
                    onSearchChanged: (q) => setState(() => _query = q),
                    onFilterTap: () {},
                    onAddTap: () {},
                  ),
                  const SizedBox(height: 14),
                  LibraryFilterChips(
                    selected: _filter,
                    onSelected: (f) => setState(() => _filter = f),
                  ),
                  const SizedBox(height: 14),
                  LibraryCategoryTabs(
                    selected: _category,
                    onSelected: (c) => setState(() => _category = c),
                  ),
                  const SizedBox(height: 14),
                  _ResultsBar(count: exercises.length),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Scrollable grid
            Expanded(
              child: exercises.isEmpty
                  ? const _EmptyState()
                  : _ExerciseGrid(
                      exercises: exercises,
                      favouriteIds: _favouriteIds,
                      onFavouriteTap: _toggleFavourite,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Results bar
// ──────────────────────────────────────────────

class _ResultsBar extends StatelessWidget {
  const _ResultsBar({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '${count.toString().padLeft(1)} ĆWICZEŃ',
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        GestureDetector(
          onTap: () {},
          child: Row(
            children: const [
              Text(
                'Sortuj: ',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'Popularne',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(width: 2),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.primary,
                size: 16,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────
// Grid
// ──────────────────────────────────────────────

class _ExerciseGrid extends StatelessWidget {
  const _ExerciseGrid({
    required this.exercises,
    required this.favouriteIds,
    required this.onFavouriteTap,
  });

  final List<Exercise> exercises;
  final Set<String> favouriteIds;
  final ValueChanged<Exercise> onFavouriteTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.86,
      ),
      itemCount: exercises.length,
      itemBuilder: (context, index) {
        final exercise = exercises[index];
        final isFav = favouriteIds.contains(exercise.id);
        final cardExercise = Exercise(
          id: exercise.id,
          name: exercise.name,
          muscles: exercise.muscles,
          category: exercise.category,
          isFavourite: isFav,
          isMine: exercise.isMine,
        );
        return ExerciseCard(
          exercise: cardExercise,
          onTap: () {},
          onFavouriteTap: () => onFavouriteTap(exercise),
        );
      },
    );
  }
}

// ──────────────────────────────────────────────
// Empty state
// ──────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.search_off_rounded,
              color: AppColors.textMuted,
              size: 30,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Brak wyników',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Spróbuj zmienić filtry lub wyszukaj inaczej.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
