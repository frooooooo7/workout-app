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
    unawaited(_args.scheduler.cancelGoalReached().catchError((_) {}));
    unawaited(_args.session.clear());
    context.pop(true);
  }

  Future<void> _abort() async {
    unawaited(_args.scheduler.cancelGoalReached().catchError((_) {}));
    unawaited(_args.session.clear());
    context.pop();
  }

  Future<void> _pickGoal(WarmupInProgress running) async {
    final minutes = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cel czasu na dziś',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Stały cel zmienisz w Ustawieniach.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final choice in kWarmupTargetChoices)
                    ChoiceChip(
                      key: ValueKey('warmup-goal-$choice'),
                      label: Text('$choice min'),
                      selected: choice == running.targetMinutes,
                      onSelected: (_) => Navigator.of(sheetContext).pop(choice),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (minutes == null || minutes == running.targetMinutes) return;
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
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(AppColors.background, accent, 0.18)!,
              AppColors.background,
            ],
            stops: const [0, 0.55],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _TopBar(
                target: request.target,
                planColor: request.plan == null
                    ? null
                    : PlanColors.of(
                        request.plan!.name,
                        colorKey: request.plan!.colorKey,
                      ),
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
                      const SizedBox(height: 24),
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
                      const SizedBox(height: 16),
                      Center(
                        child: _GoalChip(
                          reached: reached,
                          minutes:
                              running?.targetMinutes ??
                              kWarmupDefaultTargetMinutes,
                          onTap: running == null
                              ? null
                              : () => _pickGoal(running),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const _InfoCard(),
                      if (request.plan != null) ...[
                        const SizedBox(height: 12),
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(
                              alpha: reached ? 0.55 : 0.28,
                            ),
                            blurRadius: reached ? 28 : 18,
                          ),
                        ],
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton.icon(
                          key: warmupStartButtonKey,
                          onPressed: _start,
                          icon: const Icon(Icons.play_arrow_rounded, size: 26),
                          label: const Text('Rozpocznij trening'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.xl),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Zegar treningu ruszy od zera po stuknięciu.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
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

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.target,
    required this.planColor,
    required this.onHide,
    required this.onAbort,
  });

  final WarmupTarget target;
  final Color? planColor;
  final VoidCallback onHide;
  final VoidCallback onAbort;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageGutter,
        8,
        AppSpacing.pageGutter,
        0,
      ),
      child: Row(
        children: [
          _RoundIconButton(
            key: warmupHideKey,
            icon: Icons.keyboard_arrow_down_rounded,
            tooltip: 'Schowaj rozgrzewkę',
            onTap: onHide,
          ),
          Expanded(
            child: Column(
              children: [
                const Text(
                  'Rozgrzewka',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: planColor ?? AppColors.primaryVariant,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'przed: ${target.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<void>(
            tooltip: 'Więcej',
            color: AppColors.surfaceVariant,
            offset: const Offset(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const _RoundIconButton(
              icon: Icons.more_vert_rounded,
              tooltip: null,
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

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    super.key,
    required this.icon,
    this.tooltip,
    this.onTap,
  });

  final IconData icon;
  final String? tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.tile),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.tile),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: AppColors.textPrimary, size: 24),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Pierścień ze stoperem: liczy w górę do celu, po celu świeci na zielono.
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
    final color = reached ? AppColors.success : AppColors.primary;
    return Semantics(
      label:
          'Rozgrzewka ${formatWarmupClock(elapsed)} z '
          '${formatWarmupClock(target)}',
      child: SizedBox(
        width: 256,
        height: 256,
        child: CustomPaint(
          painter: _RingPainter(progress: progress, color: color),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  reached ? 'CEL OSIĄGNIĘTY' : 'ROZGRZEWKA',
                  style: TextStyle(
                    color: reached
                        ? AppColors.success
                        : AppColors.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  formatWarmupClock(elapsed),
                  key: warmupTimerKey,
                  style: AppTextStyles.number(
                    size: 84,
                    weight: FontWeight.w700,
                    color: reached ? AppColors.success : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  reached
                      ? 'stoper liczy dalej'
                      : 'z ${_targetLabel(target)} min',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14.5,
                  ),
                ),
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
    const stroke = 14.0;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = AppColors.chartTrack;
    canvas.drawArc(arcRect, 0, math.pi * 2, false, track);
    if (progress <= 0) return;

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    if (progress >= 1) {
      // Pełny pierścień bez przejścia, żeby nie było widać szwu.
      arc.color = color;
    } else {
      arc.shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
        colors: [color.withValues(alpha: 0.55), color],
      ).createShader(rect);
    }
    canvas.drawArc(arcRect, -math.pi / 2, math.pi * 2 * progress, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}

class _GoalChip extends StatelessWidget {
  const _GoalChip({
    required this.reached,
    required this.minutes,
    required this.onTap,
  });

  final bool reached;
  final int minutes;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = reached ? AppColors.success : AppColors.primaryVariant;
    return Material(
      key: warmupGoalChipKey,
      color: color.withValues(alpha: 0.10),
      shape: StadiumBorder(
        side: BorderSide(color: color.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: reached ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                reached ? Icons.check_circle_rounded : Icons.flag_outlined,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  reached
                      ? 'Zacznij trening, kiedy chcesz'
                      : 'Cel $minutes min',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (!reached) ...[
                const SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down_rounded, color: color, size: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.directions_run_rounded,
            color: AppColors.primaryVariant,
            size: 26,
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rozgrzej się po swojemu',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Stoper mierzy czas rozgrzewki. Zegar treningu ruszy '
                  'dopiero po „Rozpocznij trening”.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
              ],
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PO ROZGRZEWCE',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.3,
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
