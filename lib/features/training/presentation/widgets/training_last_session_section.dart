import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../core/services/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/training_history_models.dart';
import '../bloc/training_history_cubit.dart';

/// Sekcja „Ostatni trening” łącząca podsumowanie sesji oraz listę ćwiczeń
/// w jeden spójny, elegancki komponent.
class TrainingLastSessionSection extends StatelessWidget {
  const TrainingLastSessionSection({
    super.key,
    required this.state,
    required this.onOpenDetails,
    required this.onRepeat,
    this.onOpenExerciseDetails,
  });

  final TrainingHistoryState state;
  final ValueChanged<TrainingSessionListItem> onOpenDetails;
  final ValueChanged<TrainingSessionListItem> onRepeat;
  final ValueChanged<TrainingExerciseDetail>? onOpenExerciseDetails;

  @override
  Widget build(BuildContext context) {
    final item = state.items.isEmpty ? null : state.items.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Tytuł sekcji (Hierarchia: poziom 1)
        Row(
          children: [
            const Text(
              'Ostatni trening',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            const Spacer(),
            if (item != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Ukończony',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // 2. Stan ładowania / błędu / pusta lista lub Karta Treningu
        if (state.loading && item == null)
          const _LastSessionSkeleton()
        else if (state.error != null && item == null)
          const _LastSessionMessage(
            icon: Icons.wifi_off_rounded,
            message: 'Nie udało się załadować ostatniego treningu.',
          )
        else if (item == null)
          const _LastSessionMessage(
            icon: Icons.emoji_events_outlined,
            message: 'Ukończ pierwszy trening, a tutaj go zobaczysz.',
          )
        else
          UnifiedLastSessionCard(
            item: item,
            onOpenDetails: () => onOpenDetails(item),
            onOpenExerciseDetails: onOpenExerciseDetails,
            onRepeat: () => onRepeat(item),
          ),
      ],
    );
  }
}

/// Jednolita karta Ostatniego Treningu zawierająca podsumowanie i zintegrowaną listę ćwiczeń.
class UnifiedLastSessionCard extends StatefulWidget {
  const UnifiedLastSessionCard({
    super.key,
    required this.item,
    this.exercises,
    required this.onOpenDetails,
    this.onOpenExerciseDetails,
    required this.onRepeat,
  });

  final TrainingSessionListItem item;
  final List<TrainingExerciseDetail>? exercises;
  final VoidCallback onOpenDetails;
  final ValueChanged<TrainingExerciseDetail>? onOpenExerciseDetails;
  final VoidCallback onRepeat;

  @override
  State<UnifiedLastSessionCard> createState() => _UnifiedLastSessionCardState();
}

class _UnifiedLastSessionCardState extends State<UnifiedLastSessionCard> {
  List<TrainingExerciseDetail>? _loadedExercises;
  bool _isLoadingExercises = false;

  @override
  void initState() {
    super.initState();
    _resolveExercises();
  }

  @override
  void didUpdateWidget(covariant UnifiedLastSessionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id ||
        oldWidget.exercises != widget.exercises) {
      _resolveExercises();
    }
  }

  Future<void> _resolveExercises() async {
    if (widget.exercises != null) {
      setState(() {
        _loadedExercises = widget.exercises;
        _isLoadingExercises = false;
      });
      return;
    }

    setState(() => _isLoadingExercises = true);
    try {
      final repo = ServiceLocator.trainingHistoryRepository;
      final detail = await repo.getSessionDetail(widget.item.id);
      if (!mounted) return;
      setState(() {
        _loadedExercises = detail.exercises;
        _isLoadingExercises = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadedExercises = const [];
        _isLoadingExercises = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final exercises = _loadedExercises ?? const [];
    final targetMuscles = _resolveTargetMuscles(item);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.8),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // A. Górne podsumowanie sesji
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row (ikona z niebieską obwódką, tytuł/plan/data, przyciski)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Okrągła ikona treningu z niebieską obwódką i subtelną poświatą
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                        border: Border.all(color: AppColors.primary, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.fitness_center_rounded,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Dane treningu: nazwa planu, data, czas
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ostatni Trening',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.plan.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _formatDateString(item.startedAt),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Przyciski akcji (Powtórz + Zobacz szczegóły)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _AnimatedPressable(
                          child: InkWell(
                            key: const ValueKey('last-session-repeat'),
                            onTap: widget.onRepeat,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceVariant.withValues(
                                  alpha: 0.6,
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.border.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ),
                              child: const Icon(
                                Icons.replay_rounded,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _AnimatedPressable(
                          child: InkWell(
                            key: const ValueKey('last-session-details'),
                            onTap: widget.onOpenDetails,
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Szczegóły',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(width: 3),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    color: AppColors.primary,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Statystyki (Czas, Ćwiczenia, Serie, Partie)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 360;
                    if (isNarrow) {
                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatTile(
                                  icon: Icons.access_time_rounded,
                                  value: _formatDigitalDuration(
                                    item.durationSec,
                                  ),
                                  label: 'Czas',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildStatTile(
                                  icon: Icons.fitness_center_rounded,
                                  value: '${item.exercisesCount}',
                                  label: 'Ćwiczenia',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatTile(
                                  icon: Icons.layers_rounded,
                                  value: '${item.completedSetsCount}',
                                  label: 'Serie',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildStatTile(
                                  icon: Icons.accessibility_new_rounded,
                                  value: targetMuscles.isNotEmpty
                                      ? targetMuscles.first
                                      : 'Klatka',
                                  label: 'Partie',
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    }

                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 10,
                            child: _buildStatItem(
                              icon: Icons.access_time_rounded,
                              value: _formatDigitalDuration(item.durationSec),
                              label: 'Czas',
                            ),
                          ),
                          _buildStatDivider(),
                          Expanded(
                            flex: 9,
                            child: _buildStatItem(
                              icon: Icons.fitness_center_rounded,
                              value: '${item.exercisesCount}',
                              label: 'Ćwiczenia',
                            ),
                          ),
                          _buildStatDivider(),
                          Expanded(
                            flex: 8,
                            child: _buildStatItem(
                              icon: Icons.layers_rounded,
                              value: '${item.completedSetsCount}',
                              label: 'Serie',
                            ),
                          ),
                          _buildStatDivider(),
                          Expanded(
                            flex: 14,
                            child: _buildStatItem(
                              icon: Icons.accessibility_new_rounded,
                              value: targetMuscles.isNotEmpty
                                  ? targetMuscles.first
                                  : 'Klatka',
                              label: targetMuscles.length > 1
                                  ? targetMuscles.skip(1).join(', ')
                                  : 'Góra ciała',
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Subtelna linia podziału (spójny kontener bez odrębnego panelu)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Divider(
              height: 1,
              thickness: 1,
              color: AppColors.border.withValues(alpha: 0.35),
            ),
          ),

          // B. Nagłówek sekcji ćwiczeń
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                const Text(
                  'ĆWICZENIA',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${item.exercisesCount} ${_exercisesCountLabel(item.exercisesCount)}',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // C. Lista ćwiczeń (naturalne rozwinięcie tej samej karty)
          if (_isLoadingExercises)
            const Padding(
              padding: EdgeInsets.all(18),
              child: _ExerciseListSkeleton(),
            )
          else if (exercises.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Center(
                child: Text(
                  'Brak szczegółowej listy ćwiczeń.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: exercises.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                indent: 64,
                endIndent: 18,
                color: AppColors.border.withValues(alpha: 0.25),
              ),
              itemBuilder: (context, index) {
                final exercise = exercises[index];
                return _ExerciseRowItem(
                  exercise: exercise,
                  onTap: () {
                    if (widget.onOpenExerciseDetails != null) {
                      widget.onOpenExerciseDetails!(exercise);
                    } else {
                      widget.onOpenDetails();
                    }
                  },
                );
              },
            ),

          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(vertical: 2),
      color: AppColors.border.withValues(alpha: 0.35),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _exercisesCountLabel(int count) {
    if (count == 1) return 'ćwiczenie';
    if (count >= 2 && count <= 4) return 'ćwiczenia';
    return 'ćwiczeń';
  }
}

class _ExerciseRowItem extends StatelessWidget {
  const _ExerciseRowItem({required this.exercise, required this.onTap});

  final TrainingExerciseDetail exercise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final setsCount = exercise.completedSetsCount;
    final setsText = '$setsCount ${_setsLabel(setsCount)}';

    return _AnimatedPressable(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Row(
            children: [
              // Miniatura / ikona ćwiczenia
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.border.withValues(alpha: 0.5),
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.fitness_center_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Nazwa ćwiczenia (zawija do 2 linii przy długich nazwach)
              Expanded(
                child: Text(
                  exercise.exerciseName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Liczba serii
              Text(
                setsText,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),

              // Strzałka do szczegółów ćwiczenia
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _setsLabel(int count) {
    if (count == 1) return 'seria';
    final lastDigit = count % 10;
    final lastTwo = count % 100;
    final isFew =
        lastDigit >= 2 && lastDigit <= 4 && !(lastTwo >= 12 && lastTwo <= 14);
    return isFew ? 'serie' : 'serii';
  }
}

String relativeTrainingDayLabel(DateTime startedAt, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final today = DateTime(reference.year, reference.month, reference.day);
  final local = startedAt.toLocal();
  final day = DateTime(local.year, local.month, local.day);
  final diff = today.difference(day).inDays;
  if (diff <= 0) return 'Dzisiaj';
  if (diff == 1) return 'Wczoraj';
  if (diff < 7) return '$diff dni temu';
  return '${local.day}.${local.month.toString().padLeft(2, '0')}';
}

String _formatDigitalDuration(int seconds) {
  final d = Duration(seconds: seconds);
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (h > 0) {
    return '$h:$m:$s';
  }
  return '$m:$s';
}

String _formatDateString(DateTime startedAt) {
  final local = startedAt.toLocal();
  final day = local.day;
  const weekdays = ['Pn', 'Wt', 'Śr', 'Czw', 'Pt', 'Sob', 'Niedz'];
  final weekday = weekdays[(local.weekday - 1) % 7];
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day $weekday, $hour:$minute';
}

List<String> _resolveTargetMuscles(TrainingSessionListItem item) {
  if (item.targetMuscles != null && item.targetMuscles!.isNotEmpty) {
    return item.targetMuscles!;
  }
  final nameLower = item.plan.name.toLowerCase();
  if (nameLower.contains('push')) {
    return const ['Klatka', 'Barki', 'Triceps'];
  } else if (nameLower.contains('pull')) {
    return const ['Plecy', 'Biceps', 'Tył barków'];
  } else if (nameLower.contains('leg') || nameLower.contains('nogi')) {
    return const ['Czworogłowe', 'Dwugłowe', 'Łydki'];
  } else if (nameLower.contains('fbw') || nameLower.contains('full')) {
    return const ['Całe ciało', 'Core'];
  }
  return const ['Klatka piersiowa', 'Barki', 'Triceps'];
}

class _AnimatedPressable extends StatefulWidget {
  const _AnimatedPressable({required this.child});

  final Widget child;

  @override
  State<_AnimatedPressable> createState() => _AnimatedPressableState();
}

class _AnimatedPressableState extends State<_AnimatedPressable>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.96,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _controller.forward(),
      onPointerUp: (_) => _controller.reverse(),
      onPointerCancel: (_) => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: widget.child,
      ),
    );
  }
}

class _LastSessionSkeleton extends StatefulWidget {
  const _LastSessionSkeleton();

  @override
  State<_LastSessionSkeleton> createState() => _LastSessionSkeletonState();
}

class _LastSessionSkeletonState extends State<_LastSessionSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _animation = Tween<double>(
      begin: 0.4,
      end: 0.8,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Container(
            height: 240,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.border),
            ),
          ),
        );
      },
    );
  }
}

class _ExerciseListSkeleton extends StatelessWidget {
  const _ExerciseListSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (index) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 140,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 80,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LastSessionMessage extends StatelessWidget {
  const _LastSessionMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13.5,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
