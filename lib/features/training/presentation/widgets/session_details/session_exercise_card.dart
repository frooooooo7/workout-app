import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/units/weight_unit.dart';
import '../../../../../core/utils/polish_plural.dart';
import '../../../../library/presentation/widgets/exercise_thumbnail.dart';
import '../../../../library/domain/models/exercise.dart';
import '../../../domain/models/training_history_models.dart';
import '../../../domain/services/cardio_insights.dart' show formatPacePerKm;
import '../set_type_badge.dart';
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
    this.hideRir = false,
  });

  /// Plan treningu ma wyłączony RIR (Ustawienia planu) — bez kolumny, nawet
  /// gdy stare serie mają wartości przepisane z planu.
  final bool hideRir;

  final TrainingExerciseDetail exercise;
  final int index;

  /// Podświetlenie po skoku z osi czasu — wygasa samo.
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final topSet = exercise.topSet;
    final tracking = exercise.tracking;
    final cardioSummary = formatCardioSummary(exercise);
    final bestPace = tracking.tracksDistance
        ? exercise.bestPaceSecondsPerKm
        : null;
    final note = exercise.note?.trim();
    // Kolumna RIR tylko wtedy, gdy któraś seria go ma — plan bez RIR-u
    // nie pokazuje pustej kolumny z kreskami.
    final showRir = !hideRir && exercise.sets.any(
      (set) => set.actual?.rir != null || set.planned?.rir != null,
    );
    final setLabels = setRowLabels(exercise.sets.map((set) => set.setType));

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
                        tracking.isCardio
                            ? '${exercise.completedSetsCount}/${exercise.workingSetsCount} '
                                  '${polishPlural(exercise.workingSetsCount, 'odcinek', 'odcinki', 'odcinków')}'
                            : '${exercise.completedSetsCount}/${exercise.workingSetsCount} serii',
                        ?cardioSummary,
                        if (cardioSummary == null && exercise.volumeKg > 0)
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
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ExerciseNote(text: note),
          ],
          if (exercise.sets.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 8),
            _SetTableHeader(tracking: tracking, showRir: showRir),
            for (var i = 0; i < exercise.sets.length; i++)
              tracking.isCardio
                  ? _CardioSetRow(
                      set: exercise.sets[i],
                      label: setLabels[i],
                      tracking: tracking,
                      unit: exercise.distanceUnit,
                    )
                  : _SetRow(
                      set: exercise.sets[i],
                      label: setLabels[i],
                      showWeight: tracking.tracksWeight,
                      showRir: showRir,
                    ),
          ],
          if (bestPace != null)
            _CardFooter(
              icon: Icons.speed_rounded,
              text:
                  'Najlepsze tempo: '
                  '${formatPacePerKm(bestPace, exercise.distanceUnit)}',
            )
          else if (topSet != null) ...[
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

  IconData get _icon => exercise.tracking.isCardio
      ? Icons.directions_run_rounded
      : switch (_region) {
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
    return ExerciseThumbnail(
      imageUrl: exercise.imageUrl,
      size: _size,
      borderColor: AppColors.border.withValues(alpha: 0.7),
      placeholder: _placeholder(),
    );
  }
}

class _SetTableHeader extends StatelessWidget {
  const _SetTableHeader({required this.tracking, required this.showRir});

  final ExerciseTracking tracking;
  final bool showRir;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: AppColors.textMuted,
      fontSize: 10.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: tracking.isCardio
            ? [
                const SizedBox(width: 24, child: Text('#', style: style)),
                const Expanded(flex: 4, child: Text('CZAS', style: style)),
                if (tracking.tracksDistance) ...const [
                  Expanded(flex: 3, child: Text('DYSTANS', style: style)),
                  Expanded(flex: 3, child: Text('TEMPO', style: style)),
                ],
                const SizedBox(width: 22),
              ]
            : [
                const SizedBox(width: 24, child: Text('#', style: style)),
                if (tracking.tracksWeight)
                  const Expanded(flex: 4, child: Text('CIĘŻAR', style: style)),
                const Expanded(flex: 3, child: Text('POWT.', style: style)),
                if (showRir)
                  const Expanded(flex: 2, child: Text('RIR', style: style)),
                const SizedBox(width: 22),
              ],
      ),
    );
  }
}

/// Stopka karty: najcięższa seria albo najlepsze tempo.
class _CardFooter extends StatelessWidget {
  const _CardFooter({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.statTeal),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Notatka do ćwiczenia zapisana podczas treningu.
class _ExerciseNote extends StatelessWidget {
  const _ExerciseNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.sticky_note_2_outlined,
              size: 15,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({
    required this.set,
    required this.label,
    this.showWeight = true,
    this.showRir = true,
  });

  final TrainingExerciseSetDetail set;

  /// Kolumna RIR (gdy któraś seria ćwiczenia go ma).
  final bool showRir;

  /// Ćwiczenie na same powtórzenia nie ma kolumny ciężaru.
  final bool showWeight;

  /// Numer serii roboczej albo litera rodzaju (W / F / D).
  final String label;

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
              label,
              style: TextStyle(
                color: setTypeColor(set.setType) ?? AppColors.textMuted,
                fontSize: 12,
                fontWeight: set.setType == SetType.normal
                    ? FontWeight.w600
                    : FontWeight.w800,
              ),
            ),
          ),
          if (showWeight)
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      weight == null
                          ? '—'
                          : '${formatWeight(weight)} ${WeightUnits.current.label}',
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
          if (showRir)
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

/// Odcinek kardio: czas, dystans i tempo.
class _CardioSetRow extends StatelessWidget {
  const _CardioSetRow({
    required this.set,
    required this.label,
    required this.tracking,
    required this.unit,
  });

  final TrainingExerciseSetDetail set;
  final String label;
  final ExerciseTracking tracking;
  final DistanceUnit unit;

  @override
  Widget build(BuildContext context) {
    final metrics = set.actual ?? set.planned;
    final seconds = metrics?.durationSeconds;
    final meters = metrics?.distanceM;
    final pace = set.actual?.paceSecondsPerKm;
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
              label,
              style: TextStyle(
                color: setTypeColor(set.setType) ?? AppColors.textMuted,
                fontSize: 12,
                fontWeight: set.setType == SetType.normal
                    ? FontWeight.w600
                    : FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              seconds == null ? '—' : formatSetDuration(seconds),
              style: valueStyle,
            ),
          ),
          if (tracking.tracksDistance) ...[
            Expanded(
              flex: 3,
              child: Text(
                meters == null ? '—' : unit.formatWithUnit(meters),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: valueStyle,
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                pace == null || dimmed
                    ? '—'
                    : formatSetDuration(
                        (pace * unit.paceMeters / 1000).round(),
                      ),
                style: valueStyle.copyWith(
                  color: dimmed ? AppColors.textMuted : AppColors.statTeal,
                ),
              ),
            ),
          ],
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
