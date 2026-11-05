import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/plan_colors.dart';
import '../../../../core/theme/plan_icons.dart';
import '../../../../core/units/weight_unit.dart';
import '../../../../core/utils/polish_plural.dart';
import '../../data/warmup_stores.dart';
import '../../domain/models/custom_training_plan.dart';
import '../../domain/models/warmup.dart';
import '../../domain/services/plan_exercise_summary.dart';
import '../../domain/services/warmup_goal_scheduler.dart';
import '../utils/warmup_gate.dart';

const warmupStartButtonKey = ValueKey('warmup-start');
const warmupTimerKey = ValueKey('warmup-timer');
const warmupGoalChipKey = ValueKey('warmup-goal-chip');
const warmupCancelMenuKey = ValueKey('warmup-cancel');
const warmupHideKey = ValueKey('warmup-hide');

/// Argumenty trasy [kWarmupRoute]. Panel zamyka się wynikiem `true`
/// („Rozpocznij trening”) albo `null` (schowany / przerwany).
class WarmupArgs {
  const WarmupArgs({
    required this.request,
    required this.session,
    required this.scheduler,
    this.clock,
  });

  final WarmupRequest request;
  final WarmupSessionStore session;
  final WarmupGoalScheduler scheduler;
  final DateTime Function()? clock;
}

/// Panel rozgrzewki: stoper liczący do celu, informacja i przycisk
/// „Rozpocznij trening” na dole. Aplikacja nie podpowiada ćwiczeń —
/// użytkownik rozgrzewa się po swojemu.
class WarmupScreen extends StatefulWidget {
  const WarmupScreen({super.key, required this.args});

  final WarmupArgs? args;

  @override
  State<WarmupScreen> createState() => _WarmupScreenState();
}

class _WarmupScreenState extends State<WarmupScreen> {
  late final DateTime Function() _clock;
  Timer? _ticker;
  bool _goalFeedbackDone = false;
  bool _starting = false;

  WarmupArgs get _args => widget.args!;

  @override
  void initState() {
    super.initState();
    final args = widget.args;
    if (args == null) {
      // Odświeżenie przeglądarki na trasie panelu: nie ma czego pokazać.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/app/training');
      });
      return;
    }
    _clock = args.clock ?? DateTime.now;
    final running = args.session.current;
    // Panel otwarty po osiągnięciu celu nie wibruje drugi raz.
    _goalFeedbackDone = running != null && running.isGoalReached(_clock());
    _ticker = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => _onTick(),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _onTick() {
    if (!mounted) return;
    final running = _args.session.current;
    if (running == null) return;
    final reached = running.isGoalReached(_clock());
    if (reached && !_goalFeedbackDone) {
      _goalFeedbackDone = true;
      unawaited(HapticFeedback.heavyImpact());
    } else if (!reached) {
      _goalFeedbackDone = false;
    }
    setState(() {});
  }

  Future<void> _start() async {
    if (_starting) return;
    _starting = true;
    final running = _args.session.current;
    final seconds = running == null
        ? null
        : warmupSecondsToSave(running.elapsed(_clock()));
    unawaited(_args.scheduler.cancelGoalReached().catchError((_) {}));
    unawaited(_args.session.clear());
    context.pop(WarmupGateResult.go(seconds: seconds));
  }

  Future<void> _abort() async {
    unawaited(_args.scheduler.cancelGoalReached().catchError((_) {}));
    unawaited(_args.session.clear());
    context.pop();
  }

  /// Zmiana celu tylko na dziś — ustawienia konta zostają.
  void _setGoal(WarmupInProgress running, int minutes) {
    if (minutes == running.targetMinutes) return;
    unawaited(_args.session.setTargetMinutes(minutes));
    final updated = _args.session.current;
    if (updated == null) return;
    // Powiadomienie ma przyjść w nowym celu; cel już minięty — bez niego.
    final left = updated.targetDuration - updated.elapsed(_clock());
    unawaited(
      left > Duration.zero
          ? _args.scheduler.scheduleGoalReached(after: left).catchError((_) {})
          : _args.scheduler.cancelGoalReached().catchError((_) {}),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (widget.args == null) {
      return const Scaffold(backgroundColor: AppColors.background);
    }
    final request = _args.request;
    final running = _args.session.current;
    final now = _clock();
    final reached = running?.isGoalReached(now) ?? false;
    final accent = reached ? AppColors.success : AppColors.primary;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.55),
            radius: 1.1,
            colors: [
              Color.lerp(AppColors.background, accent, 0.22)!,
              AppColors.background,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _TopBar(
                target: request.target,
                onHide: () => context.pop(),
                onAbort: _abort,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.pageGutter,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 20),
                      Center(
                        child: _Ring(
                          elapsed: running?.elapsed(now) ?? Duration.zero,
                          target:
                              running?.targetDuration ??
                              const Duration(
                                minutes: kWarmupDefaultTargetMinutes,
                              ),
                          reached: reached,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: _GoalSelector(
                            selected:
                                running?.targetMinutes ??
                                kWarmupDefaultTargetMinutes,
                            onSelected: running == null
                                ? null
                                : (minutes) => _setGoal(running, minutes),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        reached
                            ? 'Zacznij trening, kiedy chcesz'
                            : 'Rozgrzej się po swojemu. Stoper mierzy czas, '
                                  'zapiszemy go przy treningu osobno. '
                                  'Zegar treningu ruszy po starcie.',
                        key: const ValueKey('warmup-hint'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: reached
                              ? AppColors.success
                              : AppColors.textSecondary,
                          fontSize: 13.5,
                          height: 1.4,
                          fontWeight: reached
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      if (request.plan != null) ...[
                        const SizedBox(height: 28),
                        _AfterWarmupCard(plan: request.plan!),
                      ],
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageGutter,
                  8,
                  AppSpacing.pageGutter,
                  AppSpacing.md,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(
                          alpha: reached ? 0.55 : 0.3,
                        ),
                        blurRadius: reached ? 30 : 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: FilledButton(
                      key: warmupStartButtonKey,
                      onPressed: _start,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              'Rozpocznij trening',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, size: 22),
                        ],
                      ),
                    ),
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

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.target,
    required this.onHide,
    required this.onAbort,
  });

  final WarmupTarget target;
  final VoidCallback onHide;
  final VoidCallback onAbort;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          IconButton(
            key: warmupHideKey,
            tooltip: 'Schowaj rozgrzewkę',
            onPressed: onHide,
            iconSize: 30,
            color: AppColors.textSubtle,
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
          ),
          Expanded(
            child: Column(
              children: [
                const Text(
                  'ROZGRZEWKA',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'przed: ${target.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<void>(
            tooltip: 'Więcej',
            color: AppColors.surfaceVariant,
            iconColor: AppColors.textSubtle,
            iconSize: 24,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            itemBuilder: (_) => [
              PopupMenuItem<void>(
                key: warmupCancelMenuKey,
                onTap: onAbort,
                child: const Text(
                  'Przerwij rozgrzewkę',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Pierścień ze stoperem: cienki, ze światłem, liczy w górę do celu.
/// Po celu świeci na zielono i pokazuje „Cel osiągnięty”.
class _Ring extends StatelessWidget {
  const _Ring({
    required this.elapsed,
    required this.target,
    required this.reached,
  });

  final Duration elapsed;
  final Duration target;
  final bool reached;

  @override
  Widget build(BuildContext context) {
    final progress = target.inMilliseconds == 0
        ? 1.0
        : (elapsed.inMilliseconds / target.inMilliseconds).clamp(0.0, 1.0);
    final color = reached ? AppColors.success : AppColors.primaryVariant;
    return Semantics(
      label:
          'Rozgrzewka ${formatWarmupClock(elapsed)} z '
          '${formatWarmupClock(target)}',
      child: SizedBox(
        width: 272,
        height: 272,
        child: CustomPaint(
          painter: _RingPainter(progress: progress, color: color),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatWarmupClock(elapsed),
                  key: warmupTimerKey,
                  style: AppTextStyles.number(
                    size: 88,
                    weight: FontWeight.w600,
                    color: reached ? AppColors.success : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  reached ? 'CEL OSIĄGNIĘTY' : 'z ${_targetLabel(target)} min',
                  style: reached
                      ? const TextStyle(
                          color: AppColors.success,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.6,
                        )
                      : const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14.5,
                        ),
                ),
                if (reached) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'stoper liczy dalej',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _targetLabel(Duration target) {
    final minutes = target.inMinutes;
    final seconds = target.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 7.0;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke * 2);
    canvas.drawArc(
      arcRect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = Colors.white.withValues(alpha: 0.07),
    );
    if (progress <= 0) return;

    final sweep = math.pi * 2 * progress;
    // Miękka poświata pod łukiem.
    canvas.drawArc(
      arcRect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke + 6
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    if (progress >= 1) {
      arc.color = color;
    } else {
      arc.shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
        colors: [color.withValues(alpha: 0.5), color],
      ).createShader(rect);
    }
    canvas.drawArc(arcRect, -math.pi / 2, sweep, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}

/// Cel czasu na dziś: przełącznik segmentowy, bez dodatkowego arkusza.
class _GoalSelector extends StatelessWidget {
  const _GoalSelector({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int>? onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: warmupGoalChipKey,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final minutes in kWarmupTargetChoices)
            GestureDetector(
              key: ValueKey('warmup-goal-$minutes'),
              behavior: HitTestBehavior.opaque,
              onTap: onSelected == null ? null : () => onSelected!(minutes),
              child: Semantics(
                button: true,
                selected: minutes == selected,
                label: 'Cel $minutes min',
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: minutes == selected
                        ? Colors.white.withValues(alpha: 0.14)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$minutes min',
                    style: TextStyle(
                      color: minutes == selected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: minutes == selected
                          ? FontWeight.w800
                          : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// „Po rozgrzewce”: co czeka w planie — nazwa, liczby, partie i pierwsze
/// ćwiczenie.
class _AfterWarmupCard extends StatelessWidget {
  const _AfterWarmupCard({required this.plan});

  final CustomTrainingPlan plan;

  /// Krótko, żeby nazwa ćwiczenia miała miejsce: „3 × 60 kg”; bez ciężaru
  /// (kardio, własny ciężar) — zwykły skrót ćwiczenia.
  static String _startHint(PlanExercise exercise) {
    final weight = exercise.sets.isEmpty ? null : exercise.sets.first.weight;
    if (exercise.exercise.tracking.tracksWeight &&
        weight != null &&
        weight.trim().isNotEmpty) {
      return '${exercise.sets.length} × ${weightTextForInput(weight)} '
          '${WeightUnits.current.label}';
    }
    return planExerciseSummary(
      exercise,
      formatWeight: (raw) => weightTextForInput(raw),
      weightUnitLabel: WeightUnits.current.label,
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = PlanColors.of(plan.name, colorKey: plan.colorKey);
    final exercises = plan.exercises;
    final setsCount = exercises.fold<int>(0, (s, e) => s + e.sets.length);
    final muscles = planMuscleSummary(exercises);
    final counts = [
      '${exercises.length} '
          '${polishPlural(exercises.length, 'ćwiczenie', 'ćwiczenia', 'ćwiczeń')}',
      '$setsCount ${polishPlural(setsCount, 'seria', 'serie', 'serii')}',
      if (muscles.isNotEmpty) muscles,
    ].join(' · ');
    final first = exercises.isEmpty ? null : exercises.first;

    return Container(
      key: const ValueKey('warmup-after-card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Po rozgrzewce',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              PlanBadge(
                name: plan.name,
                color: color,
                iconKey: plan.iconKey,
                size: 42,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      counts,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (first != null) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: AppColors.border),
            ),
            Row(
              children: [
                const Text(
                  'Na start',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    first.exercise.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _startHint(first),
                  maxLines: 1,
                  style: AppTextStyles.number(
                    size: 17,
                    color: AppColors.textSubtle,
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
