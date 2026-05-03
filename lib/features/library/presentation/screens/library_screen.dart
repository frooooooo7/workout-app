import 'package:flutter/material.dart';
import '../../../../core/services/service_locator.dart';
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
  final _repo = ServiceLocator.exerciseRepository;

  LibraryFilter _filter = LibraryFilter.all;
  MuscleGroup _category = MuscleGroup.all;
  String _query = '';
  final _searchController = TextEditingController();

  List<Exercise> _exercises = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);

    final result = await _repo.getAll(
      filter: _filter,
      muscleGroup: _category,
      query: _query,
    );

    if (!mounted) return;
    setState(() {
      _exercises = result;
      _loading = false;
    });
  }

  Future<void> _toggleFavourite(Exercise exercise) async {
    await _repo.setFavourite(exercise.id, isFavourite: !exercise.isFavourite);
    await _load();
  }

  void _onFilterChanged(LibraryFilter f) {
    setState(() => _filter = f);
    _load();
  }

  void _onCategoryChanged(MuscleGroup c) {
    setState(() => _category = c);
    _load();
  }

  void _onQueryChanged(String q) {
    setState(() => _query = q);
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                    onSearchChanged: _onQueryChanged,
                    onFilterTap: () {},
                    onAddTap: () {},
                  ),
                  const SizedBox(height: 14),
                  LibraryFilterChips(
                    selected: _filter,
                    onSelected: _onFilterChanged,
                  ),
                  const SizedBox(height: 14),
                  LibraryCategoryTabs(
                    selected: _category,
                    onSelected: _onCategoryChanged,
                  ),
                  const SizedBox(height: 14),
                  _ResultsBar(count: _exercises.length),
                ],
              ),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: _loading
                  ? const _LoadingState()
                  : _exercises.isEmpty
                      ? const _EmptyState()
                      : _ExerciseGrid(
                          exercises: _exercises,
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
          '$count ĆWICZEŃ',
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        GestureDetector(
          onTap: () {},
          child: const Row(
            children: [
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
    required this.onFavouriteTap,
  });

  final List<Exercise> exercises;
  final Future<void> Function(Exercise) onFavouriteTap;

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
        return ExerciseCard(
          exercise: exercise,
          onTap: () {},
          onFavouriteTap: () => onFavouriteTap(exercise),
        );
      },
    );
  }
}

// ──────────────────────────────────────────────
// States
// ──────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: AppColors.primary,
        strokeWidth: 2.5,
      ),
    );
  }
}

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
