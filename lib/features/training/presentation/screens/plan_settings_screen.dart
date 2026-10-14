import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/plan_colors.dart';
import '../../../../core/units/weight_unit.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../domain/models/custom_training_plan.dart';
import '../widgets/ongoing_workout/rest_timer_controls.dart'
    show formatRestRemaining;

/// Ustawienia planu zwracane do edycji planu.
typedef PlanSettingsResult = ({
  PlanGoal? goal,
  double? progressionStepKg,
  bool highlightPlanColor,
  bool showRir,
  bool showTempo,
  bool isPublic,
});

/// Cel, krok progresji i wygląd ekranu treningu dla jednego planu.
class PlanSettingsScreen extends StatefulWidget {
  const PlanSettingsScreen({super.key, required this.plan});

  /// Szkic planu z edycji (nazwa i kolor do podglądu, bieżące ustawienia).
  final CustomTrainingPlan plan;

  @override
  State<PlanSettingsScreen> createState() => _PlanSettingsScreenState();
}

class _PlanSettingsScreenState extends State<PlanSettingsScreen> {
  static const _steps = [1.25, 2.5, 5.0];

  late PlanGoal? _goal = widget.plan.goal;
  late double? _step = widget.plan.progressionStepKg;
  late bool _highlight = widget.plan.highlightPlanColor;
  late bool _showRir = widget.plan.showRir;
  late bool _showTempo = widget.plan.showTempo;
  late bool _isPublic = widget.plan.isPublic;

  Color get _color =>
      PlanColors.choices[widget.plan.colorKey] ??
      PlanColors.automatic(widget.plan.name);

  void _done() {
    Navigator.of(context).pop((
      goal: _goal,
      progressionStepKg: _step,
      highlightPlanColor: _highlight,
      showRir: _showRir,
      showTempo: _showTempo,
      isPublic: _isPublic,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return PopScope(
      canPop: false,
      // Wstecz zapisuje wybór — ustawienia nie mają osobnego „Zapisz”.
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _done();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              AppHeader(title: 'Ustawienia planu', onBack: _done),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
                  children: [
                    const Text('CEL', style: AppTextStyles.eyebrow),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        for (final (i, goal) in PlanGoal.values.indexed) ...[
                          if (i > 0) const SizedBox(width: 8),
                          Expanded(
                            child: _GoalCard(
                              goal: goal,
                              selected: _goal == goal,
                              color: color,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(
                                  () => _goal = _goal == goal ? null : goal,
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Nowe ćwiczenia w planie dostają te powtórzenia, a plan '
                      'tę przerwę. Każde da się zmienić.',
                      style: AppTextStyles.caption,
                    ),
                    const SizedBox(height: 24),
                    const Text('PROGRESJA', style: AppTextStyles.eyebrow),
                    const SizedBox(height: 10),
                    _Card(
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text('Krok ciężaru', style: _titleStyle),
                            ),
                            _Segmented(
                              values: [
                                for (final step in _steps) _formatKg(step),
                              ],
                              selected: _steps.indexOf(_step ?? 2.5),
                              lastSuffix: ' kg',
                              onChanged: (i) =>
                                  setState(() => _step = _steps[i]),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _ProgressionPreview(stepKg: _step ?? 2.5),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'W TRAKCIE TRENINGU',
                      style: AppTextStyles.eyebrow,
                    ),
                    const SizedBox(height: 10),
                    _Card(
                      children: [
                        _SwitchRow(
                          key: const ValueKey('plan-setting-highlight'),
                          title: 'Zaznaczenie w kolorze planu',
                          subtitle:
                              'aktywna seria, check i przerwa zamiast niebieskiego',
                          value: _highlight,
                          color: color,
                          onChanged: (v) => setState(() => _highlight = v),
                        ),
                        const SizedBox(height: 10),
                        _HighlightPreview(
                          color: _highlight ? color : AppColors.primaryVariant,
                          fill: _highlight ? color : AppColors.primary,
                          onFill: _highlight
                              ? PlanColors.onAccent(color)
                              : AppColors.onPrimary,
                        ),
                        const _Divider(),
                        _SwitchRow(
                          key: const ValueKey('plan-setting-rir'),
                          title: 'Kolumna RIR',
                          subtitle: 'gdy seria ma zapisany RIR',
                          value: _showRir,
                          color: color,
                          onChanged: (v) => setState(() => _showRir = v),
                        ),
                        const _Divider(),
                        _SwitchRow(
                          key: const ValueKey('plan-setting-tempo'),
                          title: 'Kolumna tempo',
                          subtitle: 'gdy seria ma zapisane tempo',
                          value: _showTempo,
                          color: color,
                          onChanged: (v) => setState(() => _showTempo = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text('UDOSTĘPNIANIE', style: AppTextStyles.eyebrow),
                    const SizedBox(height: 10),
                    _Card(
                      children: [
                        _SwitchRow(
                          key: const ValueKey('plan-setting-public'),
                          title: 'Widoczny na profilu',
                          subtitle:
                              'inni zobaczą i skopiują plan, bez Twoich ciężarów',
                          value: _isPublic,
                          color: color,
                          onChanged: (v) => setState(() => _isPublic = v),
                        ),
                      ],
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

const _titleStyle = TextStyle(
  color: AppColors.textPrimary,
  fontSize: 15,
  fontWeight: FontWeight.w800,
);

String _formatKg(double kg) {
  final text = kg == kg.roundToDouble() ? kg.toStringAsFixed(0) : kg.toString();
  return text.replaceAll('.', ',');
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 24, thickness: 1, color: AppColors.border);
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final PlanGoal goal;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rest = formatRestRemaining(Duration(seconds: goal.restSeconds));
    return Semantics(
      button: true,
      selected: selected,
      label: 'Cel: ${goal.label}, ${goal.repRange} powtórzeń, przerwa $rest',
      excludeSemantics: true,
      child: AppPressable(
        key: ValueKey('plan-goal-${goal.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.12) : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: selected ? color : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(goal.label, style: _titleStyle),
              const SizedBox(height: 4),
              Text(
                '${goal.repRange} powt. · $rest',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(fontSize: 11.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.values,
    required this.selected,
    required this.onChanged,
    this.lastSuffix = '',
  });

  final List<String> values;
  final int selected;
  final ValueChanged<int> onChanged;
  final String lastSuffix;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.tile,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < values.length; i++)
            Semantics(
              button: true,
              selected: i == selected,
              child: GestureDetector(
                key: ValueKey('plan-step-$i'),
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == selected
                        ? AppColors.surfaceVariant
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    i == values.length - 1
                        ? '${values[i]}$lastSuffix'
                        : values[i],
                    style: AppTextStyles.number(
                      size: 16,
                      color: i == selected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
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

/// „W trakcie treningu 92,5 → +2,5” — jak krok zmieni podpowiedź.
class _ProgressionPreview extends StatelessWidget {
  const _ProgressionPreview({required this.stepKg});

  final double stepKg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text('W trakcie treningu', style: AppTextStyles.caption),
          ),
          Text(
            '${formatWeightNumber(92.5)} → ',
            style: AppTextStyles.number(size: 16),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Container(
              key: ValueKey(stepKg),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF12301F),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '+${_formatKg(stepKg)}',
                style: AppTextStyles.number(size: 14, color: AppColors.success),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Wiersz aktywnej serii w wybranym kolorze zaznaczenia.
class _HighlightPreview extends StatelessWidget {
  const _HighlightPreview({
    required this.color,
    required this.fill,
    required this.onFill,
  });

  final Color color;
  final Color fill;
  final Color onFill;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: color),
        duration: const Duration(milliseconds: 250),
        builder: (context, c, _) {
          final accent = c ?? color;
          return Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: accent.withValues(alpha: 0.55),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: fill,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    '2',
                    style: TextStyle(
                      color: onFill,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${formatWeightNumber(92.5)} × 8',
                    style: AppTextStyles.caption,
                  ),
                ),
                Text('95', style: AppTextStyles.number(size: 18)),
                const SizedBox(width: 28),
                Text('8', style: AppTextStyles.number(size: 18)),
                const SizedBox(width: 22),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: accent, width: 2),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final Color color;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _titleStyle),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.caption),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.onPrimary,
            activeTrackColor: color,
          ),
        ],
      ),
    );
  }
}
