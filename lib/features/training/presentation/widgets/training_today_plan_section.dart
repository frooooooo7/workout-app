import 'package:flutter/material.dart';

import '../../../../core/services/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/plan_colors.dart';
import '../../../../core/utils/polish_plural.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../library/domain/models/exercise.dart';
import '../../domain/models/custom_training_plan.dart';
import '../../domain/models/progression_settings.dart';
import '../../domain/models/training_home_insights.dart';
import 'training_day_status.dart';
import 'training_plan_exercises_table.dart';
import 'training_record_to_beat.dart';

/// Karta planu wybranego dnia (domyślnie dziś): nazwa planu, partie,
/// ćwiczenia z ostatnimi wynikami, rekord do pobicia i „Rozpocznij”.
/// W dzień wolny i bez planów — ta sama karta z odpowiednią akcją.
class TrainingTodayPlanSection extends StatelessWidget {
  const TrainingTodayPlanSection({
    super.key,
    required this.selectedDay,
    required this.plans,
    required this.isLoading,
    required this.onOpenPlan,
    required this.onStartPlan,
    required this.onCreatePlanForDay,
    required this.onStartCustom,
    this.insights = TrainingHomeInsights.empty,
    this.today,
    this.sessionInProgress = false,
  });

  /// 1 = poniedziałek … 7 = niedziela.
  final int selectedDay;
  final List<CustomTrainingPlan> plans;
  final bool isLoading;
  final ValueChanged<CustomTrainingPlan> onOpenPlan;
  final Future<void> Function(CustomTrainingPlan plan) onStartPlan;
  final ValueChanged<int> onCreatePlanForDay;

  /// Trening bez planu (wybór rodzaju aktywności).
  final VoidCallback onStartCustom;
  final TrainingHomeInsights insights;

  /// Test seam; domyślnie [DateTime.now].
  final DateTime? today;

  /// Trwa już trening — „Rozpocznij” jest wyszarzony (wraca się do niego
  /// paskiem „Trwa trening” nad kartą).
  final bool sessionInProgress;

  @override
  Widget build(BuildContext context) {
    if (isLoading && plans.isEmpty) return const _PlanCardSkeleton();

    final now = today ?? DateTime.now();
    final date = startOfWeekContaining(
      now,
    ).add(Duration(days: selectedDay - 1));
    final badge = _dayBadge(date, now);
    final caption = 'Plan na ${_weekdayAccusative[selectedDay - 1]}';
    final scheduled = [
      for (final plan in plans)
        if (plan.selectedDays.contains(selectedDay)) plan,
    ];

    final customItem = _MenuItem(
      'Trening bez planu',
      onStartCustom,
      enabled: !sessionInProgress,
    );

    if (scheduled.isEmpty) {
      final hasPlans = plans.isNotEmpty;
      return _PlanCardShell(
        key: const ValueKey('plan-card-rest'),
        badge: badge,
        caption: caption,
        menu: [customItem],
        child: hasPlans
            ? _RestDayContent(
                nextWorkout: _nextWorkout(plans, selectedDay),
                onCreatePlan: () => onCreatePlanForDay(selectedDay),
              )
            : _NoPlansContent(
                onCreatePlan: () => onCreatePlanForDay(selectedDay),
              ),
      );
    }

    final plan = scheduled.first;
    return _PlanCardShell(
      key: ValueKey('plan-card-${plan.id}'),
      badge: badge,
      caption: caption,
      color: PlanColors.of(plan.name),
      menu: [
        _MenuItem('Szczegóły planu', () => onOpenPlan(plan)),
        for (final other in scheduled.skip(1))
          _MenuItem(
            'Rozpocznij ${other.name}',
            () => onStartPlan(other),
            enabled: !sessionInProgress,
          ),
        customItem,
      ],
      // „Do pobicia” zależy od metody progresji z ustawień.
      child: ValueListenableBuilder<ProgressionSettings>(
        valueListenable: ServiceLocator.progressionSettings.notifier,
        builder: (context, _, _) => _PlanContent(
          plan: plan,
          insights: insights,
          onOpen: () => onOpenPlan(plan),
          onStart: sessionInProgress ? null : () => onStartPlan(plan),
        ),
      ),
    );
  }

  static const _weekdayAccusative = [
    'poniedziałek',
    'wtorek',
    'środę',
    'czwartek',
    'piątek',
    'sobotę',
    'niedzielę',
  ];

  static String _dayBadge(DateTime date, DateTime now) {
    final days = calendarDateOnly(date).difference(calendarDateOnly(now));
    return switch (days.inDays) {
      0 => 'DZIŚ',
      -1 => 'WCZORAJ',
      1 => 'JUTRO',
      _ => kTrainingWeekdayFullNames[date.weekday - 1].toUpperCase(),
    };
  }

  /// Najbliższy zaplanowany trening po [day] (z zawinięciem tygodnia).
  static String? _nextWorkout(List<CustomTrainingPlan> plans, int day) {
    for (var offset = 1; offset <= 7; offset++) {
      final weekday = (day - 1 + offset) % 7 + 1;
      for (final plan in plans) {
        if (plan.selectedDays.contains(weekday)) {
          final dayName = kTrainingWeekdayFullNames[weekday - 1].toLowerCase();
          return '${plan.name} · $dayName';
        }
      }
    }
    return null;
  }
}

class _MenuItem {
  const _MenuItem(this.label, this.onSelected, {this.enabled = true});

  final String label;
  final VoidCallback onSelected;
  final bool enabled;
}

/// Wspólna rama karty: poświata w kolorze planu, plakietka dnia i menu.
class _PlanCardShell extends StatelessWidget {
  const _PlanCardShell({
    super.key,
    required this.badge,
    required this.caption,
    required this.menu,
    required this.child,
    this.color,
  });

  final String badge;
  final String caption;
  final List<_MenuItem> menu;
  final Widget child;

  /// Kolor planu; `null` — karta bez planu (neutralna).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppColors.primaryVariant;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: color?.withValues(alpha: 0.30) ?? AppColors.border,
        ),
      ),
      child: Stack(
        children: [
          if (color != null)
            Positioned(
              right: -70,
              top: -90,
              width: 250,
              height: 250,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        color!.withValues(alpha: 0.20),
                        color!.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          color: Color.lerp(accent, Colors.white, 0.35),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.88,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _MoreMenu(items: menu),
                  ],
                ),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreMenu extends StatelessWidget {
  const _MoreMenu({required this.items});

  final List<_MenuItem> items;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 36,
      child: PopupMenuButton<int>(
        key: const ValueKey('plan-card-menu'),
        tooltip: 'Więcej opcji planu',
        padding: EdgeInsets.zero,
        icon: const Icon(
          Icons.more_horiz_rounded,
          size: 22,
          color: AppColors.textSecondary,
        ),
        color: AppColors.surfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        onSelected: (index) => items[index].onSelected(),
        itemBuilder: (context) => [
          for (var i = 0; i < items.length; i++)
            PopupMenuItem<int>(
              value: i,
              enabled: items[i].enabled,
              child: Text(items[i].label),
            ),
        ],
      ),
    );
  }
}

class _PlanContent extends StatelessWidget {
  const _PlanContent({
    required this.plan,
    required this.insights,
    required this.onOpen,
    required this.onStart,
  });

  final CustomTrainingPlan plan;
  final TrainingHomeInsights insights;
  final VoidCallback onOpen;

  /// `null` — trwa inny trening, przycisk wyszarzony.
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final color = PlanColors.of(plan.name);
    final muscles = _muscleSummary(plan.exercises);
    final setsCount = plan.exercises.fold<int>(0, (s, e) => s + e.sets.length);
    final durationSec = insights.durationFor(plan.name);
    final record = recordToBeatFor(
      plan.exercises,
      insights.bests,
      settings:
          plan.planProgression ?? ServiceLocator.progressionSettings.current,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          hint: 'Szczegóły planu',
          child: GestureDetector(
            onTap: onOpen,
            behavior: HitTestBehavior.opaque,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  plan.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 30,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
                if (muscles.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    muscles,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSubtle,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            _PlanStat(
              icon: Icons.fitness_center_rounded,
              color: color,
              label:
                  '${plan.exercises.length} ${polishPlural(plan.exercises.length, 'ćwiczenie', 'ćwiczenia', 'ćwiczeń')}',
            ),
            _PlanStat(
              icon: Icons.layers_outlined,
              color: color,
              label:
                  '$setsCount ${polishPlural(setsCount, 'seria', 'serie', 'serii')}',
            ),
            if (durationSec != null)
              _PlanStat(
                icon: Icons.schedule_rounded,
                color: color,
                label: '~${_roundedMinutes(durationSec)} min',
              ),
          ],
        ),
        if (plan.exercises.isNotEmpty) ...[
          const SizedBox(height: 12),
          TrainingPlanExercisesTable(
            exercises: plan.exercises,
            lastResults: insights.lastResults,
          ),
        ],
        if (record != null) ...[
          const SizedBox(height: 10),
          TrainingRecordToBeat(record: record),
        ],
        const SizedBox(height: 12),
        _CardButton(
          key: const ValueKey('start-workout-button'),
          label: 'Rozpocznij ${plan.name}',
          icon: Icons.play_arrow_rounded,
          onTap: onStart,
        ),
        if (onStart == null) ...[
          const SizedBox(height: 8),
          const Text(
            'Trwa trening — dokończ go, zanim zaczniesz kolejny.',
            key: ValueKey('start-disabled-hint'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSubtle,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  /// Czas w pełnych 5 minutach, co najmniej 5.
  static int _roundedMinutes(int seconds) {
    final minutes = (seconds / 60 / 5).round() * 5;
    return minutes < 5 ? 5 : minutes;
  }

  /// „Klatka · Barki · Triceps” — główna partia każdego ćwiczenia, bez
  /// powtórzeń, najwyżej cztery.
  static String _muscleSummary(List<PlanExercise> exercises) {
    final labels = <String>{};
    for (final exercise in exercises) {
      final muscles = exercise.exercise.muscles.where(
        (m) => m != MuscleGroup.all,
      );
      if (muscles.isEmpty) continue;
      labels.add(muscles.first.shortLabel);
      if (labels.length == 4) break;
    }
    return labels.join(' · ');
  }
}

class _PlanStat extends StatelessWidget {
  const _PlanStat({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.iconOnTile,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _RestDayContent extends StatelessWidget {
  const _RestDayContent({
    required this.nextWorkout,
    required this.onCreatePlan,
  });

  /// „Pull · piątek”; `null`, gdy żaden plan nie ma przypisanych dni.
  final String? nextWorkout;
  final VoidCallback onCreatePlan;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  const Text('Dzień wolny', style: _titleStyle),
                  const SizedBox(height: 4),
                  Text(
                    nextWorkout == null
                        ? 'Regeneracja to też część planu.'
                        : 'Następny trening: $nextWorkout',
                    style: _subtitleStyle,
                  ),
                ],
              ),
            ),
            Image.asset(
              'assets/images/monk_rest.webp',
              key: const ValueKey('monk-rest-icon'),
              height: 64,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ],
        ),
        const SizedBox(height: 14),
        _CardButton(
          key: const ValueKey('plan-day-button'),
          label: 'Zaplanuj trening na ten dzień',
          icon: Icons.add_rounded,
          secondary: true,
          onTap: onCreatePlan,
        ),
      ],
    );
  }
}

class _NoPlansContent extends StatelessWidget {
  const _NoPlansContent({required this.onCreatePlan});

  final VoidCallback onCreatePlan;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        const Text('Brak planu', style: _titleStyle),
        const SizedBox(height: 4),
        const Text(
          'Utwórz plan treningowy, a tutaj zobaczysz trening na dziś.',
          style: _subtitleStyle,
        ),
        const SizedBox(height: 14),
        _CardButton(
          key: const ValueKey('create-plan-button'),
          label: 'Utwórz plan',
          icon: Icons.add_rounded,
          onTap: onCreatePlan,
        ),
      ],
    );
  }
}

const _titleStyle = TextStyle(
  color: AppColors.textPrimary,
  fontSize: 26,
  height: 1.1,
  fontWeight: FontWeight.w800,
  letterSpacing: -0.5,
);

const _subtitleStyle = TextStyle(
  color: AppColors.textSecondary,
  fontSize: 14,
  fontWeight: FontWeight.w600,
);

/// Główny przycisk karty (niebieski z poświatą) albo drugorzędny (kafelek).
class _CardButton extends StatelessWidget {
  const _CardButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.secondary = false,
  });

  final String label;
  final IconData icon;

  /// `null` — przycisk wyszarzony i nieaktywny.
  final VoidCallback? onTap;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final foreground = disabled
        ? AppColors.textMuted
        : (secondary ? AppColors.iconOnTile : AppColors.onPrimary);
    return Semantics(
      button: true,
      enabled: !disabled,
      label: label,
      excludeSemantics: true,
      child: AppPressable(
        onTap: onTap,
        enabled: !disabled,
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: disabled
                ? AppColors.tile
                : (secondary ? AppColors.tile : AppColors.primary),
            borderRadius: BorderRadius.circular(16),
            border: secondary || disabled
                ? Border.all(color: AppColors.borderStrong)
                : null,
            boxShadow: secondary || disabled
                ? null
                : [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: foreground),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: secondary ? 15 : 16,
                    fontWeight: secondary ? FontWeight.w700 : FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanCardSkeleton extends StatelessWidget {
  const _PlanCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      label: 'Ładowanie planu',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBlock(width: 120, height: 22, radius: 999),
            SizedBox(height: 14),
            SkeletonBlock(width: 140, height: 30),
            SizedBox(height: 10),
            SkeletonBlock(width: 200, height: 14),
            SizedBox(height: 16),
            SkeletonBlock(height: 120, radius: 16),
            SizedBox(height: 12),
            SkeletonBlock(height: 50, radius: 16),
          ],
        ),
      ),
    );
  }
}
