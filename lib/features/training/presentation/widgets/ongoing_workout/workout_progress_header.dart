import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../domain/models/training_session.dart';
import 'workout_colors.dart';

/// Postęp treningu: „Ćwiczenie 1 z 5” (dotknięcie otwiera listę ćwiczeń),
/// licznik serii i pasek z segmentem na każde ćwiczenie. Rozgrzewki nie
/// liczą się do postępu.
class WorkoutProgressHeader extends StatelessWidget {
  const WorkoutProgressHeader({
    super.key,
    required this.exercises,
    required this.currentIndex,
    required this.accent,
    required this.onShowList,
    required this.onSelectExercise,
    this.onLongPressExercise,
  });

  final List<TrainingSessionExercise> exercises;
  final int currentIndex;

  /// Kolor planu — wypełnienie segmentów.
  final Color accent;
  final VoidCallback onShowList;
  final ValueChanged<int> onSelectExercise;

  /// Przytrzymanie segmentu — menu kolejności ćwiczeń.
  final ValueChanged<int>? onLongPressExercise;

  @override
  Widget build(BuildContext context) {
    final progress = WorkoutSetProgress.of(exercises);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              Semantics(
                button: true,
                hint: 'Lista ćwiczeń',
                child: InkWell(
                  key: const Key('exercise-list-button'),
                  onTap: onShowList,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      'Ćwiczenie ${currentIndex + 1} z ${exercises.length}',
                      style: _labelStyle,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${progress.done}',
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                    TextSpan(text: ' z ${progress.total} serii'),
                  ],
                ),
                key: const Key('workout-sets-counter'),
                style: _labelStyle,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Semantics(
            label: 'Postęp treningu',
            value: '${progress.done} z ${progress.total} serii',
            child: Row(
              children: [
                for (var i = 0; i < exercises.length; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                    child: _Segment(
                      key: ValueKey('progress-segment-$i'),
                      fraction: progress.fractions[i],
                      current: i == currentIndex,
                      accent: accent,
                      onTap: () => onSelectExercise(i),
                      onLongPress: onLongPressExercise == null
                          ? null
                          : () => onLongPressExercise!(i),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const _labelStyle = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 12,
    fontWeight: FontWeight.w700,
  );
}

/// Zrobione i wszystkie serie robocze treningu oraz wypełnienie segmentu
/// każdego ćwiczenia (0–1).
class WorkoutSetProgress {
  const WorkoutSetProgress._(this.done, this.total, this.fractions);

  factory WorkoutSetProgress.of(List<TrainingSessionExercise> exercises) {
    var done = 0;
    var total = 0;
    final fractions = <double>[];
    for (final exercise in exercises) {
      final working = exercise.sets.where((set) => set.countsTowardStats);
      final workingDone = working.where((set) => set.completed).length;
      done += workingDone;
      total += working.length;
      if (working.isEmpty) {
        // Same rozgrzewki: segment pełny dopiero, gdy wszystkie są zrobione.
        final allDone = exercise.sets.every((set) => set.completed);
        fractions.add(allDone && exercise.sets.isNotEmpty ? 1 : 0);
      } else {
        fractions.add(workingDone / working.length);
      }
    }
    return WorkoutSetProgress._(done, total, fractions);
  }

  final int done;
  final int total;
  final List<double> fractions;
}

class _Segment extends StatelessWidget {
  const _Segment({
    super.key,
    required this.fraction,
    required this.current,
    required this.accent,
    required this.onTap,
    this.onLongPress,
  });

  final double fraction;
  final bool current;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 450);
    // Wyższy obszar dotyku niż sam 6-pikselowy pasek.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: AnimatedContainer(
            duration: duration,
            height: 6,
            color: current
                ? WorkoutColors.segmentTrackCurrent
                : WorkoutColors.segmentTrack,
            alignment: Alignment.centerLeft,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: fraction.clamp(0, 1)),
              duration: duration,
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => FractionallySizedBox(
                widthFactor: value,
                heightFactor: 1,
                child: ColoredBox(color: accent),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
