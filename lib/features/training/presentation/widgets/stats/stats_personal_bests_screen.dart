import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/polish_plural.dart';
import '../../../../../core/widgets/app_tab_header.dart';
import '../../../domain/models/training_stats.dart';
import 'stats_format.dart';
import 'stats_navigation.dart';

enum _BestsSort {
  recent('Najnowsze', 'Ostatnio poprawione'),
  alphabetical('Alfabetycznie', 'Alfabetycznie'),
  heaviest('Najcięższe', 'Najcięższe');

  const _BestsSort(this.label, this.semanticLabel);

  final String label;
  final String semanticLabel;
}

/// Najlepsze wyniki wszystkich ćwiczeń z całej historii — z wyszukiwarką
/// i sortowaniem.
class PersonalBestsScreen extends StatefulWidget {
  const PersonalBestsScreen({super.key, required this.bests});

  final List<ExerciseBest> bests;

  @override
  State<PersonalBestsScreen> createState() => _PersonalBestsScreenState();
}

class _PersonalBestsScreenState extends State<PersonalBestsScreen> {
  final _search = TextEditingController();
  _BestsSort _sort = _BestsSort.recent;
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<ExerciseBest> _visible() {
    final q = _query.trim().toLowerCase();
    final list = [
      for (final b in widget.bests)
        if (q.isEmpty || b.exerciseName.toLowerCase().contains(q)) b,
    ];
    switch (_sort) {
      case _BestsSort.recent:
        list.sort((a, b) => b.lastImprovedAt.compareTo(a.lastImprovedAt));
      case _BestsSort.alphabetical:
        list.sort(
          (a, b) => a.exerciseName.toLowerCase().compareTo(
            b.exerciseName.toLowerCase(),
          ),
        );
      case _BestsSort.heaviest:
        // Ćwiczenia bez ciężaru na końcu, między sobą alfabetycznie.
        list.sort((a, b) {
          final byWeight = (b.bestWeightKg ?? -1).compareTo(
            a.bestWeightKg ?? -1,
          );
          if (byWeight != 0) return byWeight;
          return a.exerciseName.toLowerCase().compareTo(
            b.exerciseName.toLowerCase(),
          );
        });
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AppTabBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTabHeader(
                title: 'Rekordy',
                showSync: false,
                leading: AppTabHeaderButton.back(
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageGutter,
                  AppSpacing.xxs,
                  AppSpacing.pageGutter,
                  AppSpacing.sm,
                ),
                child: _SearchField(
                  controller: _search,
                  onChanged: (v) => setState(() => _query = v),
                  onClear: () {
                    _search.clear();
                    setState(() => _query = '');
                  },
                ),
              ),
              // Trzy równe segmenty — mieszczą się na 360 px bez przewijania.
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pageGutter,
                ),
                child: SizedBox(
                  height: 34,
                  child: Row(
                    children: [
                      for (final sort in _BestsSort.values) ...[
                        if (sort.index > 0)
                          const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: _SortPill(
                            label: sort.label,
                            semanticLabel: sort.semanticLabel,
                            selected: sort == _sort,
                            onTap: () => setState(() => _sort = sort),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              const AppTabScrollEdge(),
              Expanded(
                child: visible.isEmpty
                    ? _EmptyResults(
                        query: _query.trim(),
                        hasAny: widget.bests.isNotEmpty,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.pageGutter,
                          AppSpacing.sm,
                          AppSpacing.pageGutter,
                          AppSpacing.xxl,
                        ),
                        itemCount: visible.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.xs),
                        itemBuilder: (context, i) =>
                            _BestTile(best: visible[i]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: const BorderSide(color: AppColors.border),
    );
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      cursorColor: AppColors.primaryVariant,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: AppColors.surface,
        hintText: 'Szukaj ćwiczenia',
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        prefixIcon: const Icon(
          Icons.search_rounded,
          size: 20,
          color: AppColors.textMuted,
        ),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'Wyczyść',
                  onPressed: onClear,
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                ),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: AppColors.primaryVariant),
        ),
      ),
    );
  }
}

class _SortPill extends StatelessWidget {
  const _SortPill({
    required this.label,
    required this.semanticLabel,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String semanticLabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Sortuj: $semanticLabel',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.18)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected
                  ? AppColors.primaryVariant.withValues(alpha: 0.7)
                  : AppColors.border,
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? AppColors.textPrimary : AppColors.textSecondary,
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _BestTile extends StatelessWidget {
  const _BestTile({required this.best});

  final ExerciseBest best;

  @override
  Widget build(BuildContext context) {
    final b = best;
    final canOpen = canOpenStatsExercise(b.exerciseId);
    final metrics = <({String label, String value})>[
      if (b.bestWeightKg != null)
        (
          label: 'Ciężar',
          value: b.bestWeightReps == null
              ? formatStatsWeight(b.bestWeightKg!)
              : '${formatStatsWeight(b.bestWeightKg!)} × ${b.bestWeightReps}',
        ),
      if (b.bestOneRepMaxKg != null)
        (
          label: 'e1RM',
          value: formatStatsWeight(b.bestOneRepMaxKg!, digits: 0),
        ),
      if (b.maxReps != null)
        (label: 'Bez ciężaru', value: '${b.maxReps} powt.'),
    ];

    final content = Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  b.exerciseName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (canOpen)
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.textMuted,
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'ostatnio poprawiony: ${formatStatsLongDate(b.lastImprovedAt.toLocal())}'
            ' · ${b.sessions} ${polishPlural(b.sessions, 'trening', 'treningi', 'treningów')}',
            maxLines: 2,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
          if (metrics.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final m in metrics)
                  _Metric(label: m.label, value: m.value),
              ],
            ),
          ],
        ],
      ),
    );

    if (!canOpen) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => openStatsExercise(context, b.exerciseId),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: content,
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({required this.query, required this.hasAny});

  final String query;
  final bool hasAny;

  @override
  Widget build(BuildContext context) {
    final text = !hasAny
        ? 'Brak zapisanych wyników. Ukończ trening, a rekordy pojawią się tutaj.'
        : 'Brak ćwiczeń pasujących do „$query”.';
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.xl),
          const Icon(
            Icons.search_off_rounded,
            size: 28,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
