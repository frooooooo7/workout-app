import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/widgets/app_pressable.dart';
import '../../../domain/services/rest_history.dart';
import '../ongoing_workout/rest_timer_controls.dart' show formatRestRemaining;

/// Wynik arkusza przerwy: `seconds == null` — wróć do przerwy domyślnej
/// planu; [asPlanDefault] — ta przerwa ma się stać domyślną planu.
typedef PlanRestChoice = ({int? seconds, bool asPlanDefault});

/// Średnia przerwa z historii i z ilu treningów ją policzono.
typedef RestAverage = ({int seconds, int sessions});

const _presets = [60, 90, 120, 180, 240, 300];
const _step = 15;
const _maxSeconds = 1800;

/// Arkusz „Przerwa po serii” z makiety: duży czas, ±15 s, gotowe wartości,
/// podpowiedź z historii i „Ustaw jako domyślną przerwę planu”.
Future<PlanRestChoice?> showPlanRestSheet(
  BuildContext context, {
  required String title,
  required String subtitle,
  required int initialSeconds,
  required bool showDefaultButton,
  Widget? leading,
  Future<RestAverage?>? average,
}) {
  return showModalBottomSheet<PlanRestChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => _PlanRestSheet(
      title: title,
      subtitle: subtitle,
      initialSeconds: initialSeconds,
      showDefaultButton: showDefaultButton,
      leading: leading,
      average: average,
    ),
  );
}

class _PlanRestSheet extends StatefulWidget {
  const _PlanRestSheet({
    required this.title,
    required this.subtitle,
    required this.initialSeconds,
    required this.showDefaultButton,
    required this.leading,
    required this.average,
  });

  final String title;
  final String subtitle;
  final int initialSeconds;
  final bool showDefaultButton;
  final Widget? leading;
  final Future<RestAverage?>? average;

  @override
  State<_PlanRestSheet> createState() => _PlanRestSheetState();
}

class _PlanRestSheetState extends State<_PlanRestSheet> {
  late int _seconds = widget.initialSeconds.clamp(0, _maxSeconds);
  bool _asPlanDefault = false;

  void _set(int seconds) {
    final next = seconds.clamp(0, _maxSeconds);
    if (next == _seconds) return;
    HapticFeedback.selectionClick();
    setState(() => _seconds = next);
  }

  @override
  Widget build(BuildContext context) {
    final label = formatRestRemaining(Duration(seconds: _seconds));
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                if (widget.leading != null) ...[
                  widget.leading!,
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                _StepButton(
                  key: const ValueKey('rest-sheet-minus'),
                  label: '−15',
                  onTap: () => _set(_seconds - _step),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          label,
                          key: const ValueKey('rest-sheet-value'),
                          style: AppTextStyles.number(
                            size: 76,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _seconds < 60 ? 'sekundy' : 'minuty',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
                _StepButton(
                  key: const ValueKey('rest-sheet-plus'),
                  label: '+15',
                  onTap: () => _set(_seconds + _step),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                for (final (i, preset) in _presets.indexed) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: _PresetButton(
                      seconds: preset,
                      selected: preset == _seconds,
                      onTap: () => _set(preset),
                    ),
                  ),
                ],
              ],
            ),
            if (widget.average != null)
              FutureBuilder<RestAverage?>(
                future: widget.average,
                builder: (context, snapshot) {
                  final average = snapshot.data;
                  return AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: average == null
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: _AverageHint(
                              average: average,
                              onApply: _set,
                            ),
                          ),
                  );
                },
              ),
            const SizedBox(height: 14),
            _DefaultCheckbox(
              value: _asPlanDefault,
              onChanged: (value) => setState(() => _asPlanDefault = value),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                if (widget.showDefaultButton) ...[
                  SizedBox(
                    height: 52,
                    child: TextButton(
                      key: const ValueKey('rest-sheet-default'),
                      onPressed: () => Navigator.of(
                        context,
                      ).pop((seconds: null, asPlanDefault: false)),
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.surfaceVariant,
                        foregroundColor: AppColors.textPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      child: const Text('Domyślna'),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: FilledButton(
                      key: const ValueKey('rest-sheet-save'),
                      onPressed: () => Navigator.of(
                        context,
                      ).pop((seconds: _seconds, asPlanDefault: _asPlanDefault)),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      child: Text('Zapisz $label'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label == '+15' ? 'Dodaj 15 sekund' : 'Odejmij 15 sekund',
      excludeSemantics: true,
      child: AppPressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: AppTextStyles.number(size: 19, color: AppColors.iconOnTile),
          ),
        ),
      ),
    );
  }
}

class _PresetButton extends StatelessWidget {
  const _PresetButton({
    required this.seconds,
    required this.selected,
    required this.onTap,
  });

  final int seconds;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = formatRestRemaining(Duration(seconds: seconds));
    return Semantics(
      button: true,
      selected: selected,
      label: 'Przerwa $label',
      excludeSemantics: true,
      child: AppPressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: AppTextStyles.number(
              size: 17,
              color: selected ? AppColors.onPrimary : AppColors.iconOnTile,
            ),
          ),
        ),
      ),
    );
  }
}

class _AverageHint extends StatelessWidget {
  const _AverageHint({required this.average, required this.onApply});

  final RestAverage average;
  final ValueChanged<int> onApply;

  @override
  Widget build(BuildContext context) {
    final suggestion = RestHistory.suggestion(average.seconds);
    final averageLabel = formatRestRemaining(
      Duration(seconds: average.seconds),
    );
    final suggestionLabel = formatRestRemaining(Duration(seconds: suggestion));
    final sessions = average.sessions;
    final scope = sessions == 1
        ? 'Na ostatnim treningu'
        : 'Na ostatnich $sessions treningach';
    return Container(
      key: const ValueKey('rest-sheet-average'),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.show_chart_rounded,
              size: 18,
              color: AppColors.primaryVariant,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onApply(suggestion),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '$scope Twoja przerwa wynosiła tu średnio '),
                    TextSpan(
                      text: averageLabel,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const TextSpan(text: '. '),
                    TextSpan(
                      text: 'Ustaw $suggestionLabel',
                      style: const TextStyle(
                        color: AppColors.primaryVariant,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                style: const TextStyle(
                  color: AppColors.textSubtle,
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DefaultCheckbox extends StatelessWidget {
  const _DefaultCheckbox({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: value,
      label: 'Ustaw jako domyślną przerwę planu',
      excludeSemantics: true,
      child: GestureDetector(
        key: const ValueKey('rest-sheet-as-default'),
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: value ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: value ? AppColors.primary : AppColors.textMuted,
                    width: 2,
                  ),
                ),
                child: value
                    ? const Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: AppColors.onPrimary,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Ustaw jako domyślną przerwę planu',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
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
