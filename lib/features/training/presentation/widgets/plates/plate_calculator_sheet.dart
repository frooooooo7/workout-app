import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/units/weight_unit.dart';
import '../../../../profile/presentation/widgets/ruler_picker.dart';
import '../../../data/plate_settings_store.dart';
import '../../../domain/models/plate_equipment.dart';
import '../../../domain/services/plate_calculator.dart';
import '../../screens/plate_equipment_screen.dart';
import '../ongoing_workout/workout_colors.dart';
import 'plate_visuals.dart';

const plateSheetApplyKey = Key('plate-sheet-apply');
const plateSheetSettingsKey = Key('plate-sheet-settings');
const plateSheetWeightKey = Key('plate-sheet-weight');
const plateSheetLowerKey = Key('plate-sheet-lower');
const plateSheetUpperKey = Key('plate-sheet-upper');

/// Najcięższy ciężar na linijce.
double _rulerMax(WeightUnit unit) => unit == WeightUnit.kg ? 400 : 900;

/// Arkusz kalkulatora talerzy. [initialWeight] i wynik są w aktualnej
/// jednostce. [setLabel] (`seria 2`) trafia do podtytułu. Z [applyLabel]
/// (`serii 2` — dopełniacz do „Wpisz … do”) arkusz wpisuje ciężar do serii
/// i zwraca go; bez — działa jako zwykły kalkulator i zwraca `null`.
Future<double?> showPlateCalculatorSheet(
  BuildContext context, {
  required String exerciseName,
  double? initialWeight,
  String? setLabel,
  String? applyLabel,
}) {
  return showModalBottomSheet<double>(
    context: context,
    backgroundColor: AppColors.surface,
    barrierColor: Colors.black54,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
    ),
    builder: (_) => PlateCalculatorSheet(
      exerciseName: exerciseName,
      initialWeight: initialWeight,
      setLabel: setLabel,
      applyLabel: applyLabel,
    ),
  );
}

class PlateCalculatorSheet extends StatefulWidget {
  const PlateCalculatorSheet({
    super.key,
    required this.exerciseName,
    this.initialWeight,
    this.setLabel,
    this.applyLabel,
  });

  final String exerciseName;
  final double? initialWeight;
  final String? setLabel;
  final String? applyLabel;

  @override
  State<PlateCalculatorSheet> createState() => _PlateCalculatorSheetState();
}

class _PlateCalculatorSheetState extends State<PlateCalculatorSheet> {
  late double _weight = _initialWeight();

  double _initialWeight() {
    final unit = WeightUnits.current;
    final bar = PlateSettingsStore.current.equipmentFor(unit).barWeight;
    final initial = widget.initialWeight;
    // Bez ciężaru w serii — sam gryf plus para największych talerzy to zbyt
    // dużo zgadywania; zaczynamy od gryfu.
    if (initial == null || initial <= 0) return bar;
    return initial.clamp(0, _rulerMax(unit)).toDouble();
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PlateEquipmentScreen()),
    );
    if (!mounted) return;
    // Lżejszy gryf niż wybrany ciężar jest OK; cięższy — podnosimy ciężar.
    final bar = PlateSettingsStore.current
        .equipmentFor(WeightUnits.current)
        .barWeight;
    if (_weight < bar) setState(() => _weight = bar);
  }

  void _setWeight(double value) {
    if (value == _weight) return;
    setState(() => _weight = value);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PlateSettings>(
      valueListenable: PlateSettingsStore.notifier,
      builder: (context, settings, _) {
        final unit = WeightUnits.current;
        final equipment = settings.equipmentFor(unit);
        final calculation = PlateCalculator.calculate(
          target: _weight,
          barWeight: equipment.barWeight,
          plates: equipment.enabledPlates,
        );
        return _buildContent(context, unit, equipment, calculation);
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    WeightUnit unit,
    PlateEquipment equipment,
    PlateCalculation calculation,
  ) {
    final shown = calculation.shown;
    final applied = calculation.isExact
        ? calculation.exact!.total
        : (calculation.lower?.total ?? equipment.barWeight);
    final step = equipment.weightStep(
      fallback: unit == WeightUnit.kg ? 2.5 : 5,
    );
    final subtitle = [widget.exerciseName, ?widget.setLabel].join(' · ');

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Kalkulator talerzy',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
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
                const SizedBox(width: AppSpacing.sm),
                _SquareButton(
                  key: plateSheetSettingsKey,
                  icon: Icons.tune_rounded,
                  semanticLabel: 'Twój sprzęt',
                  onTap: _openSettings,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Center(
              child: Text.rich(
                key: plateSheetWeightKey,
                TextSpan(
                  children: [
                    TextSpan(
                      text: formatPlateNumber(_weight),
                      style: AppTextStyles.number(size: 56),
                    ),
                    TextSpan(
                      text: ' ${unit.label}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            RulerPicker(
              // Inny gryf albo krok to inna linijka.
              key: ValueKey('plate-ruler-${equipment.barWeight}-$step-$unit'),
              min: equipment.barWeight,
              max: _rulerMax(unit),
              step: step,
              majorEvery: 4,
              tickGap: 12,
              initial: _weight,
              value: _weight,
              semanticsLabel: 'Ciężar na gryfie',
              formatValue: (v) => '${formatPlateNumber(v)} ${unit.label}',
              onChanged: _setWeight,
            ),
            const SizedBox(height: AppSpacing.xs),
            _PlateStage(
              unit: unit,
              calculation: calculation,
              plates: shown?.perSide ?? const [],
            ),
            const SizedBox(height: AppSpacing.sm),
            AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              child: calculation.isExact
                  ? _TotalsRow(
                      key: const ValueKey('totals'),
                      unit: unit,
                      loadout: calculation.exact!,
                    )
                  : _NearestCard(
                      key: const ValueKey('nearest'),
                      unit: unit,
                      calculation: calculation,
                      onPick: _setWeight,
                    ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              key: plateSheetApplyKey,
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.of(
                  context,
                ).pop(widget.applyLabel == null ? null : applied);
              },
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: Text(
                widget.applyLabel == null
                    ? 'Gotowe'
                    : 'Wpisz ${formatPlateNumber(applied)} ${unit.label} '
                          'do ${widget.applyLabel}',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ciemny panel z rysunkiem jednej strony gryfu i legendą nominałów.
class _PlateStage extends StatelessWidget {
  const _PlateStage({
    required this.unit,
    required this.calculation,
    required this.plates,
  });

  final WeightUnit unit;
  final PlateCalculation calculation;
  final List<double> plates;

  @override
  Widget build(BuildContext context) {
    final loadout = calculation.shown;
    // Legenda w tej samej kolejności co rysunek: od najlżejszego.
    final counts = Map.fromEntries(
      (loadout?.counts.entries.toList() ?? const <MapEntry<double, int>>[])
        ..sort((a, b) => a.key.compareTo(b.key)),
    );
    final perSide = loadout?.perSideTotal;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: WorkoutColors.field,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: WorkoutColors.nextCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: Text('NA KAŻDĄ STRONĘ', style: _eyebrow)),
              if (perSide != null && perSide > 0)
                Text(
                  '${calculation.isExact ? '' : '≈ '}'
                  '${formatPlateNumber(perSide)} ${unit.label}',
                  style: AppTextStyles.number(
                    size: 16,
                    weight: FontWeight.w600,
                    color: WorkoutColors.textSoft,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Semantics(
            label: plates.isEmpty
                ? 'Sam gryf'
                : 'Na stronę, od najlżejszego: '
                      '${ascendingPlates(plates).map(formatPlateNumber).join(', ')}',
            child: BarbellSleeve(plates: plates, unit: unit),
          ),
          const SizedBox(height: 8),
          if (calculation.belowBar)
            const _LegendNote(text: 'Mniej niż sam gryf')
          else if (counts.isEmpty)
            const _LegendNote(text: 'Sam gryf, bez talerzy')
          else
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final entry in counts.entries)
                  _LegendChip(
                    key: ValueKey(
                      'plate-legend-${formatPlateNumber(entry.key)}',
                    ),
                    color: PlateColors.of(entry.key, unit),
                    weight: entry.key,
                    count: entry.value,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({
    super.key,
    required this.color,
    required this.weight,
    required this.count,
  });

  final Color color;
  final double weight;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 4, 10, 4),
      decoration: BoxDecoration(
        color: WorkoutColors.chip,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            formatPlateNumber(weight),
            style: AppTextStyles.number(size: 16),
          ),
          // „× 1” nic nie wnosi — mnożnik tylko przy powtórzonych talerzach,
          // dzięki czemu cztery różne talerze mieszczą się w jednej linii.
          if (count > 1) ...[
            const SizedBox(width: 4),
            Text(
              '× $count',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LegendNote extends StatelessWidget {
  const _LegendNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        style: const TextStyle(
          color: WorkoutColors.textSoft,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Gryf · Talerze · Razem.
class _TotalsRow extends StatelessWidget {
  const _TotalsRow({super.key, required this.unit, required this.loadout});

  final WeightUnit unit;
  final PlateLoadout loadout;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Kpi(label: 'GRYF', value: loadout.barWeight, unit: unit),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Kpi(
            label: 'TALERZE',
            value: loadout.perSideTotal * 2,
            unit: unit,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Kpi(
            label: 'RAZEM',
            value: loadout.total,
            unit: unit,
            accent: true,
          ),
        ),
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({
    required this.label,
    required this.value,
    required this.unit,
    this.accent = false,
  });

  final String label;
  final double value;
  final WeightUnit unit;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
      decoration: BoxDecoration(
        color: accent
            ? AppColors.primary.withValues(alpha: 0.10)
            : AppColors.background.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppRadius.tile),
        border: Border.all(
          color: accent
              ? AppColors.primaryVariant.withValues(alpha: 0.35)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: _eyebrow.copyWith(color: accent ? WorkoutColors.link : null),
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: formatPlateNumber(value),
                  style: AppTextStyles.number(size: 22),
                ),
                TextSpan(
                  text: ' ${unit.label}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
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

/// Ciężaru nie da się złożyć — dwie najbliższe możliwości do wyboru.
class _NearestCard extends StatelessWidget {
  const _NearestCard({
    super.key,
    required this.unit,
    required this.calculation,
    required this.onPick,
  });

  final WeightUnit unit;
  final PlateCalculation calculation;
  final ValueChanged<double> onPick;

  @override
  Widget build(BuildContext context) {
    final lower = calculation.lower?.total;
    final upper = calculation.belowBar
        ? calculation.barWeight
        : calculation.upper?.total;
    final message = calculation.belowBar
        ? 'Sam gryf waży ${formatPlateNumber(calculation.barWeight)} '
              '${unit.label}'
        : 'Z Twoich talerzy nie złożysz '
              '${formatPlateNumber(calculation.target)} ${unit.label}';
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [WorkoutColors.recordCardStart, WorkoutColors.recordCardEnd],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.record.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: AppColors.record,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: WorkoutColors.recordText,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (lower != null)
                Expanded(
                  child: _NearestOption(
                    key: plateSheetLowerKey,
                    caption: 'Mniej',
                    value: lower,
                    unit: unit,
                    onTap: () => onPick(lower),
                  ),
                ),
              if (lower != null && upper != null) const SizedBox(width: 8),
              if (upper != null)
                Expanded(
                  child: _NearestOption(
                    key: plateSheetUpperKey,
                    caption: 'Więcej',
                    value: upper,
                    unit: unit,
                    onTap: () => onPick(upper),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NearestOption extends StatelessWidget {
  const _NearestOption({
    super.key,
    required this.caption,
    required this.value,
    required this.unit,
    required this.onTap,
  });

  final String caption;
  final double value;
  final WeightUnit unit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.record.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Text(
                caption.toUpperCase(),
                style: _eyebrow.copyWith(color: WorkoutColors.recordText),
              ),
              const SizedBox(height: 2),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: formatPlateNumber(value),
                      style: AppTextStyles.number(
                        size: 22,
                        color: AppColors.record,
                      ),
                    ),
                    TextSpan(
                      text: ' ${unit.label}',
                      style: const TextStyle(
                        color: WorkoutColors.recordText,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
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

class _SquareButton extends StatelessWidget {
  const _SquareButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: WorkoutColors.chip,
      borderRadius: BorderRadius.circular(AppRadius.tile),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox.square(
          dimension: AppSpacing.minTapTarget,
          child: Icon(
            icon,
            color: AppColors.iconOnTile,
            size: 20,
            semanticLabel: semanticLabel,
          ),
        ),
      ),
    );
  }
}

const _eyebrow = TextStyle(
  color: WorkoutColors.textFaint,
  fontSize: 10.5,
  fontWeight: FontWeight.w800,
  letterSpacing: 0.8,
);
