import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../library/data/exercise_image_uri.dart';
import '../../../../library/domain/models/exercise.dart';
import '../../../domain/models/training_history_models.dart';
import 'session_details_formatters.dart';

/// Karta pojedynczego ćwiczenia: miniatura po lewej, tożsamość ćwiczenia obok,
/// pod spodem pełnowymiarowa tabela serii.
///
/// Tabela pokazuje **wykonanie** jako liczbę główną, a odchyłkę od planu jako
/// mały znacznik przy ciężarze — dwie równorzędne kolumny „plan / wykonanie"
/// robiły z niej ścianę tekstu.
class SessionExerciseCard extends StatelessWidget {
  const SessionExerciseCard({
    super.key,
    required this.exercise,
    required this.index,
    this.isHighlighted = false,
  });

  final TrainingExerciseDetail exercise;
  final int index;

  /// Podświetlenie po skoku z osi czasu — wygasa samo.
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final topSet = exercise.topSet;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted
              ? AppColors.primary
              : AppColors.border.withValues(alpha: 0.8),
          width: isHighlighted ? 1.6 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ExerciseThumbnail(exercise: exercise),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${index + 1}.',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            exercise.exerciseName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (exercise.muscles.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        exercise.muscles
                            .map((m) => m.shortLabel)
                            .take(3)
                            .join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      [
                        '${exercise.completedSetsCount}/${exercise.sets.length} serii',
                        if (exercise.volumeKg > 0)
                          formatVolumeKg(exercise.volumeKg),
                      ].join('  ·  '),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (exercise.sets.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 8),
            const _SetTableHeader(),
            for (final set in exercise.sets) _SetRow(set: set),
          ],
          if (topSet != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  size: 14,
                  color: AppColors.strengthMedium,
                ),
                const SizedBox(width: 6),
                Text(
                  'Najcięższa seria: ${formatSetMetrics(topSet.actual)}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Miniatura ćwiczenia. Bez zdjęcia pokazuje ikonę dobraną po partii ciała,
/// żeby placeholder niósł choć trochę informacji zamiast być szarym kwadratem.
class _ExerciseThumbnail extends StatelessWidget {
  const _ExerciseThumbnail({required this.exercise});

  final TrainingExerciseDetail exercise;

  static const _size = 58.0;

  MuscleRegion? get _region => exercise.muscles.firstOrNull?.region;

  IconData get _icon => switch (_region) {
        MuscleRegion.back => Icons.rowing_rounded,
        MuscleRegion.legs => Icons.directions_run_rounded,
        MuscleRegion.shoulders => Icons.sports_gymnastics_rounded,
        MuscleRegion.core => Icons.self_improvement_rounded,
        MuscleRegion.arms => Icons.sports_martial_arts_rounded,
        _ => Icons.fitness_center_rounded,
      };

  Color get _accent => switch (_region) {
        MuscleRegion.chest => AppColors.primaryVariant,
        MuscleRegion.back => const Color(0xFF4DB6AC),
        MuscleRegion.legs => AppColors.success,
        MuscleRegion.shoulders => AppColors.strengthMedium,
        MuscleRegion.arms => const Color(0xFF6C8EFF),
        MuscleRegion.core => const Color(0xFF4DB6AC),
        null => AppColors.primary,
      };

  Widget _placeholder() {
    return Container(
      color: _accent.withValues(alpha: 0.10),
      alignment: Alignment.center,
      child: Icon(_icon, size: 25, color: _accent.withValues(alpha: 0.75)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resolved = exerciseImageResolvedUri(exercise.imageUrl);

    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      clipBehavior: Clip.antiAlias,
      child: resolved == null
          ? _placeholder()
          : Image.network(
              resolved.toString(),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _placeholder(),
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : _placeholder(),
            ),
    );
  }
}

class _SetTableHeader extends StatelessWidget {
  const _SetTableHeader();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: AppColors.textMuted,
      fontSize: 10.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
    );

    return const Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(width: 24, child: Text('#', style: style)),
          Expanded(flex: 4, child: Text('CIĘŻAR', style: style)),
          Expanded(flex: 3, child: Text('POWT.', style: style)),
          Expanded(flex: 2, child: Text('RIR', style: style)),
          SizedBox(width: 22),
        ],
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({required this.set});

  final TrainingExerciseSetDetail set;

  /// Różnica ciężaru wykonanego względem zaplanowanego — pokazywana tylko
  /// wtedy, gdy realnie odbiega od planu.
  double? get _weightDelta {
    final actual = set.actual?.weightKg;
    final planned = set.planned?.weightKg;
    if (actual == null || planned == null) return null;
    final delta = actual - planned;
    return delta.abs() < 0.01 ? null : delta;
  }

  @override
  Widget build(BuildContext context) {
    final metrics = set.actual ?? set.planned;
    final weight = metrics?.weightKg;
    final reps = metrics?.reps;
    final rir = metrics?.rir;
    final delta = _weightDelta;
    final dimmed = !set.completed;

    final valueStyle = TextStyle(
      color: dimmed ? AppColors.textMuted : Colors.white,
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '${set.setIndex}',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    weight == null ? '—' : '${formatWeight(weight)} kg',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: valueStyle,
                  ),
                ),
                if (delta != null) ...[
                  const SizedBox(width: 5),
                  Text(
                    '${delta > 0 ? '+' : '−'}${formatWeight(delta.abs())}',
                    style: TextStyle(
                      color: delta > 0
                          ? AppColors.success
                          : AppColors.strengthMedium,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(reps?.toString() ?? '—', style: valueStyle),
          ),
          Expanded(
            flex: 2,
            child: Text(rir?.toString() ?? '—', style: valueStyle),
          ),
          SizedBox(
            width: 22,
            child: Icon(
              set.completed
                  ? Icons.check_circle_rounded
                  : Icons.remove_circle_outline_rounded,
              size: 16,
              color: set.completed ? AppColors.success : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
