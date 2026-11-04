import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../body_highlighter/models/body_highlighter_style.dart';
import '../../../body_highlighter/models/body_view.dart';
import '../../../body_highlighter/models/muscle_highlight.dart';
import '../../../body_highlighter/models/muscle_intensity.dart';
import '../../../body_highlighter/widgets/muscle_body_highlighter.dart';
import '../../domain/models/exercise.dart';
import '../../domain/models/library_part.dart';
import '../bloc/library_cubit.dart';
import 'exercise_card_illustration.dart';

/// Ekran startowy biblioteki („Start od partii”): ostatnio robione, manekin
/// z przodu i z tyłu oraz kafelki partii z liczbą ćwiczeń.
class LibraryStartView extends StatelessWidget {
  const LibraryStartView({
    super.key,
    required this.overview,
    required this.onPartTap,
    required this.onShowAll,
    required this.onExerciseTap,
  });

  final LibraryOverview overview;
  final ValueChanged<LibraryPart> onPartTap;
  final VoidCallback onShowAll;
  final ValueChanged<Exercise> onExerciseTap;

  static final _highlights = {
    for (final part in LibraryPart.values)
      for (final slug in part.slugs)
        MuscleHighlight(muscle: slug, intensity: MuscleIntensity.high),
  };

  static const _style = BodyHighlighterStyle.dark(
    highColor: AppColors.primary,
    lowColor: AppColors.primaryVariant,
  );

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        if (overview.recent.isNotEmpty) ...[
          const _SectionLabel('Ostatnio robione'),
          const SizedBox(height: 10),
          SizedBox(
            height: 128,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: overview.recent.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) => _RecentCard(
                exercise: overview.recent[index],
                onTap: () => onExerciseTap(overview.recent[index]),
              ),
            ),
          ),
          const SizedBox(height: 22),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Flexible(child: _SectionLabel('Wybierz partię')),
            const SizedBox(width: 12),
            Flexible(
              child: GestureDetector(
              onTap: onShowAll,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  'Wszystkie (${overview.total})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.primaryVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final view in BodyView.values) ...[
              SizedBox(
                width: 96,
                height: 216,
                child: MuscleBodyHighlighter(
                  view: view,
                  highlights: _highlights,
                  style: _style,
                  onMuscleTap: (region) {
                    final part = LibraryPart.fromSlug(region.slug);
                    if (part != null) onPartTap(part);
                  },
                ),
              ),
              if (view != BodyView.values.last) const SizedBox(width: 24),
            ],
          ],
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          mainAxisExtent: 64 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0),
          children: [
            for (final part in LibraryPart.values)
              _PartTile(
                part: part,
                count: overview.partCounts[part] ?? 0,
                onTap: () => onPartTap(part),
              ),
          ],
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: AppColors.textLabel,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.exercise, required this.onTap});

  final Exercise exercise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      pressedScale: 0.97,
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: double.infinity,
                height: 62,
                child: ExerciseCardIllustration(exercise: exercise),
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                exercise.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PartTile extends StatelessWidget {
  const _PartTile({
    required this.part,
    required this.count,
    required this.onTap,
  });

  final LibraryPart part;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      pressedScale: 0.97,
      child: Semantics(
        button: true,
        label: '${part.label}, ${exerciseCountLabel(count)}',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                part.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                exerciseCountLabel(count),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
