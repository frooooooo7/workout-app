import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/units/weight_unit.dart';
import '../../../../../core/widgets/app_pressable.dart';
import '../../../domain/models/progression_settings.dart';
import '../../../domain/models/training_session.dart';
import '../../../domain/services/progression_engine.dart';

/// Kolor i ikona metody — te same na liście, w podglądzie i w treningu.
extension ProgressionMethodLook on ProgressionMethod {
  Color get color => switch (this) {
    ProgressionMethod.none => AppColors.textSubtle,
    ProgressionMethod.fixed => AppColors.primaryVariant,
    ProgressionMethod.percent => AppColors.statTeal,
    ProgressionMethod.doubleProgression => AppColors.planLegs,
    ProgressionMethod.rir => AppColors.statOrange,
  };

  IconData get icon => switch (this) {
    ProgressionMethod.none => Icons.block_rounded,
    ProgressionMethod.fixed => Icons.stairs_rounded,
    ProgressionMethod.percent => Icons.percent_rounded,
    ProgressionMethod.doubleProgression => Icons.stacked_line_chart_rounded,
    ProgressionMethod.rir => Icons.speed_rounded,
  };
}

/// Podgląd „ostatnio → następnym razem”, lista metod i ustawienia wybranej.
/// Wspólne dla Ustawienia → Progresja i arkusza w ustawieniach planu.
///
/// [settings] mogą być w innej jednostce niż aplikacja — pokazujemy je
/// przeliczone na [WeightUnits.current] i tak też zapisujemy zmiany.
class ProgressionPicker extends StatelessWidget {
  const ProgressionPicker({
    super.key,
    required this.settings,
    required this.onChanged,
    this.inheritLabel,
    this.inherits = false,
    this.onInherit,
  });

  final ProgressionSettings settings;
  final ValueChanged<ProgressionSettings> onChanged;

  /// Plan: opis metody z ustawień konta; pierwsza pozycja „Jak w
  /// ustawieniach” pojawia się tylko z [onInherit].
  final String? inheritLabel;
  final bool inherits;
  final VoidCallback? onInherit;

  @override
  Widget build(BuildContext context) {
    final unit = WeightUnits.current;
    final shown = settings.inUnit(unit);
    void change(ProgressionSettings next) {
      HapticFeedback.selectionClick();
      onChanged(next);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProgressionPreview(settings: inherits ? settings : shown),
        const SizedBox(height: 22),
        const Text('METODA', style: AppTextStyles.eyebrow),
        const SizedBox(height: 10),
        if (onInherit != null) ...[
          _MethodCard(
            key: const ValueKey('progression-method-inherit'),
            icon: Icons.settings_suggest_rounded,
            color: AppColors.primaryVariant,
            title: 'Jak w ustawieniach',
            subtitle: inheritLabel,
            selected: inherits,
            onTap: onInherit!,
          ),
          const SizedBox(height: 8),
        ],
        for (final method in ProgressionMethod.values) ...[
          _MethodCard(
            key: ValueKey('progression-method-${method.apiName}'),
            icon: method.icon,
            color: method.color,
            title: method.label,
            subtitle: shown.copyWith(method: method).description,
            selected: !inherits && shown.method == method,
            onTap: () => change(shown.copyWith(method: method)),
          ),
          if (!inherits && shown.method == method && method.usesStep) ...[
            const SizedBox(height: 8),
            _MethodOptions(settings: shown, onChanged: change),
          ],
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

/// Karta „Następnym razem”: przykład na wyciskaniu, liczony tą samą
/// funkcją co podpowiedź w treningu.
class ProgressionPreview extends StatelessWidget {
  const ProgressionPreview({super.key, required this.settings});

  final ProgressionSettings settings;

  @override
  Widget build(BuildContext context) {
    final unit = WeightUnits.current;
    final color = settings.method.color;
    // 60 kg / 135 lb — okrągły ciężar w obu jednostkach.
    final weightKg = unit.toKg(unit == WeightUnit.kg ? 60 : 135);
    final isDouble = settings.method == ProgressionMethod.doubleProgression;
    final lastReps = isDouble ? 10 : 8;
    final planned = isDouble ? '8-12' : '8';
    final last = TrainingSessionSet(
      plannedReps: planned,
      actualWeight: '$weightKg',
      actualReps: '$lastReps',
      actualRir: settings.method == ProgressionMethod.rir
          ? '${settings.rirThreshold + 1}'
          : null,
      completed: true,
    );
    final hint = progressionHintFor(
      TrainingSessionSet(plannedReps: planned),
      last,
      settings: settings.copyWith(sessionsToIncrease: 1, deload: false),
    );
    final nextWeight = hint?.weightKg ?? weightKg;
    final nextReps = hint?.reps ?? lastReps;
    final afterTop = isDouble ? nextWeightKg(weightKg, settings) : null;

    final String footnote = switch (settings.method) {
      ProgressionMethod.none =>
        'Ciężar zmieniasz sam, aplikacja przypomina ostatni wynik.',
      ProgressionMethod.fixed || ProgressionMethod.percent =>
        'Nie dobiłeś powtórzeń? Zostaje ${formatWeightWithUnit(weightKg)}.',
      ProgressionMethod.doubleProgression =>
        'Po 12 powt. we wszystkich seriach: '
            '${formatWeightWithUnit(afterTop!)} × 8.',
      ProgressionMethod.rir =>
        'RIR poniżej ${settings.rirThreshold}? Zostaje '
            '${formatWeightWithUnit(weightKg)}.',
    };

    return Container(
      key: const ValueKey('progression-preview'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topLeft,
          radius: 1.6,
          colors: [color.withValues(alpha: 0.16), AppColors.surface],
          stops: const [0, 0.6],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isDouble ? 'NASTĘPNYM RAZEM · ZAKRES 8–12' : 'NASTĘPNYM RAZEM',
            style: AppTextStyles.eyebrow.copyWith(color: color),
          ),
          const SizedBox(height: 6),
          const Text(
            'Wyciskanie sztangi na ławce',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _PreviewBox(
                  label: settings.method == ProgressionMethod.rir
                      ? 'Ostatnio · RIR ${settings.rirThreshold + 1}'
                      : 'Ostatnio ✓',
                  weightKg: weightKg,
                  reps: lastReps,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 20,
                  color: AppColors.textMuted,
                ),
              ),
              Expanded(
                child: _PreviewBox(
                  key: const ValueKey('progression-preview-next'),
                  label: 'Podpowiedź',
                  weightKg: nextWeight,
                  reps: nextReps,
                  tag: hint == null
                      ? null
                      : hint.isIncrease
                      ? '+${formatStepNumber(unit.fromKg(hint.deltaKg))}'
                      : hint.addsReps
                      ? '+${hint.repsDelta} powt.'
                      : null,
                  highlight: hint != null && (hint.isIncrease || hint.addsReps),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            footnote,
            style: AppTextStyles.caption.copyWith(color: AppColors.textSubtle),
          ),
        ],
      ),
    );
  }
}

class _PreviewBox extends StatelessWidget {
  const _PreviewBox({
    super.key,
    required this.label,
    required this.weightKg,
    required this.reps,
    this.tag,
    this.highlight = false,
  });

  final String label;
  final double weightKg;
  final int reps;
  final String? tag;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.success.withValues(alpha: 0.07)
            : AppColors.background.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight
              ? AppColors.success.withValues(alpha: 0.45)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (tag != null) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF12301F),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    tag!,
                    style: const TextStyle(
                      color: AppColors.success,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: formatStepNumber(
                      WeightUnits.current.fromKg(weightKg),
                    ),
                    style: AppTextStyles.number(
                      size: 28,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  TextSpan(
                    text: ' ${WeightUnits.current.label} ',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text: '× $reps',
                    style: AppTextStyles.number(
                      size: 22,
                      color: AppColors.textSecondary,
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

class _MethodCard extends StatelessWidget {
  const _MethodCard({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: AppPressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(
                    colors: [
                      color.withValues(alpha: 0.14),
                      color.withValues(alpha: 0.03),
                    ],
                  )
                : null,
            color: selected ? null : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: selected ? color : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: _titleStyle),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: AppTextStyles.caption),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? AppColors.onPrimary : Colors.transparent,
                  border: Border.all(
                    color: selected ? color : AppColors.borderStrong,
                    width: selected ? 6 : 2,
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

const _titleStyle = TextStyle(
  color: AppColors.textPrimary,
  fontSize: 14.5,
  fontWeight: FontWeight.w800,
);

/// Ustawienia wybranej metody: krok, procent, próg RIR, nogi, „zwiększaj po”
/// i deload.
class _MethodOptions extends StatelessWidget {
  const _MethodOptions({required this.settings, required this.onChanged});

  final ProgressionSettings settings;
  final ValueChanged<ProgressionSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = settings;
    final unit = s.unit;
    final color = s.method.color;
    final isPercent = s.method == ProgressionMethod.percent;
    final showLegs =
        s.method == ProgressionMethod.fixed ||
        s.method == ProgressionMethod.rir;

    return Container(
      key: const ValueKey('progression-options'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isPercent) ...[
            const _OptionTitle(
              title: 'Zwyżka',
              subtitle: 'procent ostatniego ciężaru',
            ),
            _ChipRow(
              keyPrefix: 'progression-percent',
              values: ProgressionSettings.percentPresets,
              selected: s.percent,
              suffix: ' %',
              color: color,
              customTitle: 'Zwyżka w %',
              max: 20,
              onSelected: (v) => onChanged(s.copyWith(percent: v)),
            ),
            const _Divider(),
          ],
          _OptionTitle(
            title: isPercent ? 'Zaokrąglaj do' : 'Krok ciężaru',
            subtitle: isPercent
                ? 'najmniejszej pary krążków'
                : s.method == ProgressionMethod.doubleProgression
                ? 'po dojściu do górnej granicy zakresu'
                : 'najmniejsza para krążków na Twojej siłowni',
          ),
          _ChipRow(
            keyPrefix: 'progression-step',
            values: ProgressionSettings.stepPresets(unit),
            selected: s.step,
            suffix: ' ${unit.label}',
            color: color,
            customTitle: 'Krok w ${unit.label}',
            max: 50,
            onSelected: (v) => onChanged(s.copyWith(step: v)),
          ),
          if (s.method == ProgressionMethod.rir) ...[
            const _Divider(),
            const _OptionTitle(
              title: 'Zwyżka od RIR',
              subtitle: 'tyle powtórzeń zapasu w serii',
            ),
            _ChipRow(
              keyPrefix: 'progression-rir',
              values: const [1, 2, 3],
              selected: s.rirThreshold.toDouble(),
              prefix: '≥ ',
              color: color,
              onSelected: (v) => onChanged(s.copyWith(rirThreshold: v.round())),
            ),
          ],
          if (showLegs) ...[
            const _Divider(),
            _SwitchRow(
              key: const ValueKey('progression-leg-switch'),
              title: 'Większy krok dla nóg',
              subtitle: 'przysiad, martwy ciąg, wypychanie',
              value: s.legStep != null,
              color: color,
              onChanged: (on) => onChanged(
                on
                    ? s.copyWith(
                        legStep: ProgressionSettings.defaultLegStep(unit),
                      )
                    : s.copyWith(clearLegStep: true),
              ),
            ),
            if (s.legStep != null)
              _ChipRow(
                keyPrefix: 'progression-leg-step',
                values: ProgressionSettings.legStepPresets(unit),
                selected: s.legStep!,
                suffix: ' ${unit.label}',
                color: color,
                customTitle: 'Krok nóg w ${unit.label}',
                max: 50,
                onSelected: (v) => onChanged(s.copyWith(legStep: v)),
              ),
          ],
          const _Divider(),
          const _OptionTitle(title: 'Zwiększaj po'),
          const SizedBox(height: 10),
          _Segmented(
            labels: const ['1 udanym treningu', '2 z rzędu'],
            selected: s.sessionsToIncrease >= 2 ? 1 : 0,
            onChanged: (i) => onChanged(s.copyWith(sessionsToIncrease: i + 1)),
          ),
          const _Divider(),
          _SwitchRow(
            key: const ValueKey('progression-deload-switch'),
            title: 'Deload',
            subtitle: 'po 3 nieudanych treningach z rzędu −10 %',
            value: s.deload,
            color: color,
            onChanged: (v) => onChanged(s.copyWith(deload: v)),
          ),
          if (s.method == ProgressionMethod.doubleProgression) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.tile,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Zakres bierzemy z planu (np. 8–12). Ćwiczenie z samą liczbą '
                '„8” rośnie jak przy stałym kroku.',
                style: AppTextStyles.caption,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OptionTitle extends StatelessWidget {
  const _OptionTitle({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: _titleStyle),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle!, style: AppTextStyles.caption),
        ],
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 28, thickness: 1, color: AppColors.border);
}

/// Gotowe wartości jako chipy + „Inny…” z własną liczbą.
class _ChipRow extends StatelessWidget {
  const _ChipRow({
    required this.keyPrefix,
    required this.values,
    required this.selected,
    required this.color,
    required this.onSelected,
    this.suffix = '',
    this.prefix = '',
    this.customTitle,
    this.max = 50,
  });

  final String keyPrefix;
  final List<num> values;
  final double selected;
  final Color color;
  final ValueChanged<double> onSelected;
  final String suffix;
  final String prefix;

  /// `null` — bez „Inny…”.
  final String? customTitle;
  final double max;

  @override
  Widget build(BuildContext context) {
    final isPreset = values.any((v) => (v - selected).abs() < 1e-6);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final value in values)
            _Chip(
              key: ValueKey('$keyPrefix-${formatStepNumber(value.toDouble())}'),
              label: '$prefix${formatStepNumber(value.toDouble())}',
              semanticLabel:
                  '$prefix${formatStepNumber(value.toDouble())}$suffix',
              selected: (value - selected).abs() < 1e-6,
              color: color,
              onTap: () => onSelected(value.toDouble()),
            ),
          if (customTitle != null)
            _Chip(
              key: ValueKey('$keyPrefix-custom'),
              label: isPreset
                  ? 'Inny…'
                  : '${formatStepNumber(selected)}$suffix',
              semanticLabel: 'Inna wartość',
              selected: !isPreset,
              ghost: isPreset,
              color: color,
              onTap: () async {
                final value = await _askNumber(
                  context,
                  title: customTitle!,
                  initial: selected,
                  max: max,
                );
                if (value != null) onSelected(value);
              },
            ),
        ],
      ),
    );
  }
}

Future<double?> _askNumber(
  BuildContext context, {
  required String title,
  required double initial,
  required double max,
}) {
  return showDialog<double>(
    context: context,
    builder: (_) => _NumberDialog(title: title, initial: initial, max: max),
  );
}

class _NumberDialog extends StatefulWidget {
  const _NumberDialog({
    required this.title,
    required this.initial,
    required this.max,
  });

  final String title;
  final double initial;
  final double max;

  @override
  State<_NumberDialog> createState() => _NumberDialogState();
}

class _NumberDialogState extends State<_NumberDialog> {
  late final _controller = TextEditingController(
    text: formatStepNumber(widget.initial),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = parseWeightNumber(_controller.text);
    if (value == null || value <= 0 || value > widget.max) return;
    Navigator.of(context).pop((value * 100).round() / 100);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(widget.title),
      content: TextField(
        key: const ValueKey('progression-custom-field'),
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        ],
        onSubmitted: (_) => _submit(),
        style: AppTextStyles.number(size: 24, color: AppColors.textPrimary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Anuluj'),
        ),
        TextButton(
          key: const ValueKey('progression-custom-ok'),
          onPressed: _submit,
          child: const Text('Zapisz'),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    super.key,
    required this.label,
    required this.semanticLabel,
    required this.selected,
    required this.color,
    required this.onTap,
    this.ghost = false,
  });

  final String label;
  final String semanticLabel;
  final bool selected;
  final bool ghost;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 36,
          constraints: const BoxConstraints(minWidth: 46),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? color : AppColors.tile,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: selected
                  ? color
                  : ghost
                  ? AppColors.primaryVariant.withValues(alpha: 0.4)
                  : AppColors.borderStrong,
            ),
          ),
          // Center z widthFactor: 1 — chip ma szerokość tekstu, nie wiersza.
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              style: ghost
                  ? const TextStyle(
                      color: AppColors.primaryVariant,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    )
                  : AppTextStyles.number(
                      size: 17,
                      color: selected
                          ? (color.computeLuminance() > 0.45
                                ? AppColors.background
                                : AppColors.onPrimary)
                          : AppColors.textSubtle,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.tile,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == selected,
                child: GestureDetector(
                  key: ValueKey('progression-sessions-${i + 1}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == selected
                          ? AppColors.surfaceVariant
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      labels[i],
                      style: TextStyle(
                        color: i == selected
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
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
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: Row(
          children: [
            Expanded(
              child: _OptionTitle(title: title, subtitle: subtitle),
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
      ),
    );
  }
}
