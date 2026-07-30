import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../library/domain/models/exercise.dart';
import '../../../domain/models/training_history_models.dart';
import 'session_details_formatters.dart';
import 'session_section_card.dart';

/// Oś czasu treningu: karta daty po lewej, dalej jedna ciągła linia
/// przebiegająca za równomiernie rozstawionymi węzłami ćwiczeń.
///
/// Pełni też rolę spisu treści: dotknięcie węzła przewija ekran do właściwej
/// karty ćwiczenia. Nie powtarza sum sesji — pokazuje wyłącznie przebieg.
class SessionTimeline extends StatelessWidget {
  const SessionTimeline({
    super.key,
    required this.detail,
    required this.onExerciseTap,
  });

  final TrainingSessionDetail detail;
  final ValueChanged<int> onExerciseTap;

  /// Odstęp między węzłami — stały, żeby oś czytała się jako jeden rytm
  /// niezależnie od realnych przerw między ćwiczeniami.
  static const _nodeGap = 30.0;

  /// Odstęp między kartą daty a kropką rozpoczynającą oś — luka celowo
  /// oddziela je wizualnie, żeby linia nie wychodziła wprost z kalendarza.
  static const _dateToStartGap = 16.0;

  /// Pionowa pozycja linii = środek okręgu węzła (patrz `_TimelineNode`).
  static const _lineY = 30.0;

  /// Linia zaczyna się w środku kropki startowej, nie na krawędzi karty daty.
  static const _lineLeadingInset =
      _DateBadge.width + _dateToStartGap + _StartDot.width / 2;

  /// Odsuwa koniec linii od prawej krawędzi treści o pół szerokości węzła,
  /// żeby kończyła się w jego środku, a nie za nim.
  static const _lineTrailingInset = _TimelineNode.width / 2;

  @override
  Widget build(BuildContext context) {
    final exercises = detail.exercises;
    if (exercises.isEmpty) return const SizedBox.shrink();

    final hasClock = detail.hasSetTimestamps;

    return SessionSectionCard(
      icon: Icons.timeline_rounded,
      title: 'Oś czasu treningu',
      padding: const EdgeInsets.fromLTRB(16, 14, 0, 16),
      child: ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Colors.white, Colors.white, Colors.transparent],
          stops: [0.0, 0.92, 1.0],
        ).createShader(bounds),
        blendMode: BlendMode.dstIn,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(right: 20),
          physics: const BouncingScrollPhysics(),
          child: Stack(
            children: [
              Positioned(
                top: _lineY,
                left: _lineLeadingInset,
                right: _lineTrailingInset,
                child: Container(
                  height: 1.5,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DateBadge(date: detail.startedAt),
                  const SizedBox(width: _dateToStartGap),
                  const _StartDot(),
                  for (var i = 0; i < exercises.length; i++) ...[
                    const SizedBox(width: _nodeGap),
                    _TimelineNode(
                      exercise: exercises[i],
                      showClock: hasClock,
                      onTap: () => onExerciseTap(i),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Karta daty i godziny rozpoczęcia — wyraźnie oddzielona od reszty osi
/// granatowym tłem z niebieskim gradientem i delikatną poświatą.
class _DateBadge extends StatelessWidget {
  const _DateBadge({required this.date});

  final DateTime date;

  static const width = 80.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      margin: const EdgeInsets.only(top: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceVariant,
            AppColors.primary.withValues(alpha: 0.22),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.22),
            blurRadius: 16,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_today_rounded,
            size: 13,
            color: AppColors.primaryVariant.withValues(alpha: 0.9),
          ),
          const SizedBox(height: 7),
          Text(
            formatDayNumber(date),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            formatWeekdayShort(date),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 1,
            color: AppColors.primary.withValues(alpha: 0.25),
          ),
          const SizedBox(height: 7),
          Text(
            formatClock(date),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Kropka rozpoczynająca oś czasu — celowo odsunięta od karty daty, żeby
/// linia miała czytelny, osobny punkt startowy zamiast wychodzić wprost
/// z kalendarza.
class _StartDot extends StatelessWidget {
  const _StartDot();

  static const width = 20.0;
  static const _dotSize = 9.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.only(
          top: SessionTimeline._lineY - _dotSize / 2,
        ),
        child: Center(
          child: Container(
            width: _dotSize,
            height: _dotSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.5),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimelineNode extends StatelessWidget {
  const _TimelineNode({
    required this.exercise,
    required this.showClock,
    required this.onTap,
  });

  final TrainingExerciseDetail exercise;
  final bool showClock;
  final VoidCallback onTap;

  static const width = 92.0;
  static const _circleSize = 52.0;

  /// Ikona dobrana po regionie ciała — ten sam język wizualny co w bibliotece.
  IconData get _icon => switch (exercise.muscles.firstOrNull?.region) {
        MuscleRegion.back => Icons.rowing_rounded,
        MuscleRegion.legs => Icons.directions_run_rounded,
        MuscleRegion.shoulders => Icons.sports_gymnastics_rounded,
        MuscleRegion.core => Icons.self_improvement_rounded,
        MuscleRegion.arms => Icons.sports_martial_arts_rounded,
        _ => Icons.fitness_center_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final startedAt = exercise.startedAt;

    return SizedBox(
      width: width,
      child: Semantics(
        button: true,
        label: '${exercise.exerciseName}, '
            '${exercise.completedSetsCount} ukończonych serii. '
            'Dotknij, aby przejść do szczegółów ćwiczenia.',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: _circleSize,
                  height: _circleSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.background,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.85),
                      width: 1.3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.28),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Icon(_icon, size: 20, color: AppColors.primaryVariant),
                ),
                const SizedBox(height: 8),
                Text(
                  exercise.exerciseName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  showClock && startedAt != null
                      ? formatClock(startedAt)
                      : '${exercise.completedSetsCount} serie',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
