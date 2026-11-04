import 'package:flutter/material.dart';

import '../../../../core/services/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_header.dart';
import '../../domain/exercise_search.dart';
import '../../domain/exercise_similarity.dart';
import '../../domain/models/exercise.dart';
import '../widgets/exercise_row.dart';

/// Zamiana ćwiczenia w trakcie treningu: na górze podobne (ten sam ruch lub
/// mięsień), niżej szukanie po całej bibliotece. Stuknięcie ćwiczenia zwraca
/// je jako zamiennik; wyjście bez wyboru zwraca `null`.
class SwapExerciseScreen extends StatefulWidget {
  const SwapExerciseScreen({
    super.key,
    required this.replacing,
    this.exercises,
  });

  /// Ćwiczenie z treningu, które zastępujemy (snapshot z sesji).
  final TrainingSessionExerciseSummary replacing;

  /// Biblioteka do przeszukania; domyślnie z repozytorium (testy podają własną).
  final List<Exercise>? exercises;

  @override
  State<SwapExerciseScreen> createState() => _SwapExerciseScreenState();
}

/// To, co ekran zamiany musi wiedzieć o zastępowanym ćwiczeniu.
class TrainingSessionExerciseSummary {
  const TrainingSessionExerciseSummary({
    required this.exerciseId,
    required this.name,
    required this.tracking,
  });

  final String exerciseId;
  final String name;
  final ExerciseTracking tracking;
}

class _SwapExerciseScreenState extends State<SwapExerciseScreen> {
  final _searchController = TextEditingController();
  List<Exercise> _all = const [];
  Exercise? _current;
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final all =
          widget.exercises ?? await ServiceLocator.exerciseRepository.getAll();
      // Zastępowane ćwiczenie w bibliotece (po id lub nazwie) — z niego
      // liczymy podobieństwo.
      final name = widget.replacing.name.trim().toLowerCase();
      final id = widget.replacing.exerciseId;
      final current = all
          .where((e) => e.id == id || e.serverId == id)
          .followedBy(all.where((e) => e.name.trim().toLowerCase() == name))
          .firstOrNull;
      if (!mounted) return;
      setState(() {
        _all = all;
        _current = current;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isReplaced(Exercise e) =>
      e.id == widget.replacing.exerciseId ||
      e.serverId == widget.replacing.exerciseId ||
      e.name.trim().toLowerCase() == widget.replacing.name.trim().toLowerCase();

  Widget _row(Exercise exercise) => ExerciseRow(
    exercise: exercise,
    trailing: const Icon(
      Icons.swap_horiz_rounded,
      color: AppColors.primaryVariant,
    ),
    onTap: () => Navigator.of(context).pop(exercise),
  );

  @override
  Widget build(BuildContext context) {
    final query = _query.trim();
    final candidates = [
      for (final e in _all)
        if (!_isReplaced(e)) e,
    ];
    final similar = _current == null
        ? const <Exercise>[]
        : ExerciseSimilarity.substitutes(_current!, candidates, limit: 12);
    final searching = query.isNotEmpty;
    final results = searching
        ? ExerciseSearch.rank(candidates, query)
        : const <Exercise>[];
    final similarIds = {for (final e in similar) e.id};
    final others = [
      for (final e in candidates)
        if (!similarIds.contains(e.id)) e,
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppHeader(
              title: 'Zamień ćwiczenie',
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'zamiast: ${widget.replacing.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                style: const TextStyle(color: Colors.white, fontSize: 15),
                cursorColor: AppColors.primary,
                decoration: InputDecoration(
                  hintText: 'Szukaj: nazwa, mięsień, sprzęt',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.textMuted,
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : ListView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(16, 0, 8, 24),
                      children: [
                        if (searching) ...[
                          if (results.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 32),
                              child: Center(
                                child: Text(
                                  'Brak ćwiczeń pasujących do wyszukiwania.',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                            ),
                          for (final e in results) _row(e),
                        ] else ...[
                          if (similar.isNotEmpty) ...[
                            const _SectionLabel('Podobne'),
                            for (final e in similar) _row(e),
                          ],
                          if (others.isNotEmpty) ...[
                            _SectionLabel(
                              similar.isEmpty ? 'Wszystkie' : 'Pozostałe',
                            ),
                            for (final e in others) _row(e),
                          ],
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
