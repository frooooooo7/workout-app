import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../body_highlighter/adapters/muscle_group_adapter.dart';
import '../../../../body_highlighter/models/body_highlighter_style.dart';
import '../../../../body_highlighter/models/body_view.dart';
import '../../../../body_highlighter/models/muscle_highlight.dart';
import '../../../../body_highlighter/widgets/muscle_body_highlighter.dart';
import '../../../domain/models/exercise.dart';

/// Kolory manekina zgodne z ilustracjami ćwiczeń: mięsień główny świeci
/// niebieskim akcentem aplikacji, wspomagające — jaśniejszym błękitem.
const exercisePrimaryMuscleColor = AppColors.primary;
const exerciseSecondaryMuscleColor = Color(0xFF38BDF8);

const _style = BodyHighlighterStyle.dark(
  highColor: exercisePrimaryMuscleColor,
  lowColor: exerciseSecondaryMuscleColor,
);

/// Manekin z przodu i z tyłu z podświetlonymi mięśniami ćwiczenia oraz
/// legendą „główne / wspomagające”.
class ExerciseMuscleMap extends StatelessWidget {
  const ExerciseMuscleMap({super.key, required this.muscles});

  /// Mięśnie ćwiczenia; pierwszy to mięsień główny.
  final List<MuscleGroup> muscles;

  Set<MuscleHighlight> get _highlights {
    final intensities = <MuscleGroup, double>{};
    for (final (index, muscle) in muscles.indexed) {
      final intensity = index == 0 ? 1.0 : 0.3;
      for (final expanded in muscle.expanded) {
        final current = intensities[expanded] ?? 0;
        if (intensity > current) intensities[expanded] = intensity;
      }
    }
    return toMuscleHighlights(intensities);
  }

  @override
  Widget build(BuildContext context) {
    if (muscles.isEmpty) {
      return const Text(
        'To ćwiczenie nie ma przypisanych partii mięśniowych.',
        style: TextStyle(color: AppColors.textMuted, fontSize: 13),
      );
    }

    final highlights = _highlights;
    final figures = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Figure(view: BodyView.front, label: 'Przód', highlights: highlights),
        const SizedBox(width: 4),
        _Figure(view: BodyView.back, label: 'Tył', highlights: highlights),
      ],
    );
    final legend = _MuscleLegend(
      primary: muscles.first,
      secondary: muscles.skip(1).toList(growable: false),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 330) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: figures),
              const SizedBox(height: 16),
              legend,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            figures,
            const SizedBox(width: 16),
            Expanded(child: legend),
          ],
        );
      },
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.view,
    required this.label,
    required this.highlights,
  });

  final BodyView view;
  final String label;
  final Set<MuscleHighlight> highlights;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 86,
          height: 194,
          child: MuscleBodyHighlighter(
            view: view,
            highlights: highlights,
            style: _style,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

class _MuscleLegend extends StatelessWidget {
  const _MuscleLegend({required this.primary, required this.secondary});

  final MuscleGroup primary;
  final List<MuscleGroup> secondary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _LegendLabel(label: 'Główny', color: exercisePrimaryMuscleColor),
        const SizedBox(height: 8),
        _MuscleChip(muscle: primary, color: exercisePrimaryMuscleColor),
        if (secondary.isNotEmpty) ...[
          const SizedBox(height: 16),
          const _LegendLabel(
            label: 'Wspomagające',
            color: exerciseSecondaryMuscleColor,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final muscle in secondary)
                _MuscleChip(
                  muscle: muscle,
                  color: exerciseSecondaryMuscleColor,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _LegendLabel extends StatelessWidget {
  const _LegendLabel({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6),
            ],
          ),
        ),
        const SizedBox(width: 7),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }
}

class _MuscleChip extends StatelessWidget {
  const _MuscleChip({required this.muscle, required this.color});

  final MuscleGroup muscle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        muscle.label,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
