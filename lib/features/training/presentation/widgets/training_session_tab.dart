import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import 'training_activity_summary.dart';

// ──────────────────────────────────────────────
// Models
// ──────────────────────────────────────────────

class _DayPlan {
  const _DayPlan({
    required this.name,
    required this.type,
    required this.dayLabel,
    required this.exerciseCount,
    required this.durationMin,
    required this.muscles,
  });

  final String name;
  final String type;
  final String dayLabel;
  final int exerciseCount;
  final int durationMin;
  final String muscles;
}

// ──────────────────────────────────────────────
// Data
// ──────────────────────────────────────────────

const _plans = <int, _DayPlan>{
  1: _DayPlan(
    name: 'Push Day',
    type: 'Push',
    dayLabel: 'Dzień 1 z 3',
    exerciseCount: 6,
    durationMin: 70,
    muscles: 'Klatka, barki, triceps',
  ),
  3: _DayPlan(
    name: 'Pull Day',
    type: 'Pull',
    dayLabel: 'Dzień 2 z 3',
    exerciseCount: 5,
    durationMin: 60,
    muscles: 'Plecy, biceps',
  ),
  5: _DayPlan(
    name: 'Leg Day',
    type: 'Nogi',
    dayLabel: 'Dzień 3 z 3',
    exerciseCount: 7,
    durationMin: 80,
    muscles: 'Nogi, pośladki',
  ),
};

// ──────────────────────────────────────────────
// Tab
// ──────────────────────────────────────────────

class TrainingSessionTab extends StatefulWidget {
  const TrainingSessionTab({super.key});

  @override
  State<TrainingSessionTab> createState() => _TrainingSessionTabState();
}

class _TrainingSessionTabState extends State<TrainingSessionTab> {
  late int _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now().weekday;
  }

  @override
  Widget build(BuildContext context) {

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TodayPlanSection(
            selectedDay: _selectedDay,
            onDaySelected: (day) => setState(() => _selectedDay = day),
          ),
          const SizedBox(height: 24),
          const TrainingActivitySummary(),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Plan na dziś
// ──────────────────────────────────────────────

class _TodayPlanSection extends StatelessWidget {
  const _TodayPlanSection({
    required this.selectedDay,
    required this.onDaySelected,
  });

  final int selectedDay;
  final ValueChanged<int> onDaySelected;

  static const _workoutDays = {1, 3, 5};

  @override
  Widget build(BuildContext context) {
    final plan = _plans[selectedDay];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Twój plan na dziś',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            GestureDetector(
              onTap: () {},
              child: const Row(
                children: [
                  Text(
                    'Zobacz plan',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: plan != null
              ? _PlanCard(key: ValueKey(selectedDay), plan: plan)
              : _RestDayCard(key: ValueKey(selectedDay)),
        ),
        const SizedBox(height: 12),
        _WeekStrip(
          selectedDay: selectedDay,
          workoutDays: _workoutDays,
          onDaySelected: onDaySelected,
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────
// Plan card
// ──────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  const _PlanCard({super.key, required this.plan});

  final _DayPlan plan;

  @override
  Widget build(BuildContext context) {
    final dayIndex =
        _plans.keys.toList().indexOf(
              _plans.entries.firstWhere((e) => e.value == plan).key,
            ) +
            1;
    final progress = dayIndex / 3;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.fitness_center_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${plan.dayLabel}  •  ${plan.type}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 3,
                    backgroundColor: AppColors.surfaceVariant,
                    valueColor:
                        const AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 0,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _DetailChip(label: '${plan.exerciseCount} ćwiczeń'),
                    const _Dot(),
                    _DetailChip(label: '~${plan.durationMin} min'),
                    const _Dot(),
                    const Icon(
                      Icons.local_fire_department_rounded,
                      color: AppColors.textSecondary,
                      size: 13,
                    ),
                    const SizedBox(width: 3),
                    _DetailChip(label: plan.muscles),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () {},
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 20),
                  SizedBox(height: 2),
                  Text(
                    'Start',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Rest day card
// ──────────────────────────────────────────────

class _RestDayCard extends StatelessWidget {
  const _RestDayCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          Icon(Icons.self_improvement_rounded,
              color: AppColors.textMuted, size: 28),
          SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dzień odpoczynku',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Regeneracja to część treningu.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 5),
      child: Text(
        '•',
        style: TextStyle(color: AppColors.textMuted, fontSize: 11),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Week strip
// ──────────────────────────────────────────────

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.selectedDay,
    required this.workoutDays,
    required this.onDaySelected,
  });

  final int selectedDay;
  final Set<int> workoutDays;
  final ValueChanged<int> onDaySelected;

  static const _labels = ['Pon', 'Wt', 'Śr', 'Czw', 'Pt', 'Sob', 'Ndz'];

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().weekday;
    final startOfWeek = DateTime.now().subtract(Duration(days: today - 1));

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(7, (i) {
          final weekday = i + 1;
          final date = startOfWeek.add(Duration(days: i));
          final isToday = weekday == today;
          final isSelected = weekday == selectedDay;
          final hasWorkout = workoutDays.contains(weekday);

          return _WeekDay(
            label: _labels[i],
            day: date.day,
            isToday: isToday,
            isSelected: isSelected,
            hasWorkout: hasWorkout,
            onTap: () => onDaySelected(weekday),
          );
        }),
      ),
    );
  }
}

class _WeekDay extends StatelessWidget {
  const _WeekDay({
    required this.label,
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.hasWorkout,
    required this.onTap,
  });

  final String label;
  final int day;
  final bool isToday;
  final bool isSelected;
  final bool hasWorkout;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final highlighted = isSelected || isToday;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: highlighted ? Colors.white : AppColors.textSecondary,
              fontSize: 11,
              fontWeight: highlighted ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          const SizedBox(height: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary
                  : isToday
                      ? AppColors.primary.withValues(alpha: 0.2)
                      : Colors.transparent,
              shape: BoxShape.circle,
              border: isToday && !isSelected
                  ? Border.all(
                      color: AppColors.primary.withValues(alpha: 0.5),
                      width: 1.5,
                    )
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              '$day',
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : highlighted
                        ? AppColors.primary
                        : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: highlighted ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 5),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: hasWorkout
                  ? (isSelected ? Colors.white : AppColors.primary)
                  : Colors.transparent,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}
