import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/units/weight_unit.dart';
import '../../data/plate_settings_store.dart';
import '../../domain/models/plate_equipment.dart';
import '../widgets/ongoing_workout/workout_colors.dart';
import '../widgets/plates/plate_visuals.dart';

const plateEquipmentShowInRestKey = Key('plate-equipment-show-in-rest');
const plateEquipmentAddPlateKey = Key('plate-equipment-add-plate');
Key plateEquipmentBarKey(String id) => Key('plate-equipment-bar-$id');
Key plateEquipmentPlateKey(double weight) =>
    Key('plate-equipment-plate-$weight');

/// Tło wybranej zakładki — jak w przełączniku okresu wykresu wagi.
const _selectedTab = Color(0xFF222A3C);

/// „Twój sprzęt”: gryf, talerze na siłowni i pasek talerzy w przerwie.
/// Zestaw jest osobny dla kilogramów i funtów; zmiany zapisują się od razu.
class PlateEquipmentScreen extends StatelessWidget {
  const PlateEquipmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Twój sprzęt')),
      body: SafeArea(
        child: ValueListenableBuilder<PlateSettings>(
          valueListenable: PlateSettingsStore.notifier,
          builder: (context, settings, _) {
            final unit = WeightUnits.current;
            final equipment = settings.equipmentFor(unit);
            void update(PlateEquipment next) =>
                unawaited(PlateSettingsStore.updateEquipment(unit, next));
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.md,
                AppSpacing.xl,
                AppSpacing.xxl,
              ),
              children: [
                const _Eyebrow('GRYF'),
                const SizedBox(height: AppSpacing.xs),
                _BarSelector(
                  unit: unit,
                  barWeight: equipment.barWeight,
                  onChanged: (bar) =>
                      update(equipment.copyWith(barWeight: bar)),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _barCaption(equipment.barWeight, unit),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                const Row(
                  children: [
                    Expanded(child: _Eyebrow('TALERZE')),
                    Text(
                      'dotknij, by wyłączyć',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                _PlateGrid(
                  unit: unit,
                  equipment: equipment,
                  onToggle: (weight) {
                    HapticFeedback.selectionClick();
                    update(equipment.togglePlate(weight));
                  },
                  onRemove: (weight) => update(equipment.removePlate(weight)),
                  onAdd: () async {
                    final weight = await _askWeight(
                      context,
                      title: 'Własny talerz',
                      unit: unit,
                      max: unit == WeightUnit.kg ? 50 : 100,
                    );
                    if (weight == null || weight <= 0) return;
                    update(equipment.addPlate(weight));
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
                _ShowInRestCard(
                  value: settings.showInRest,
                  onChanged: (value) => unawaited(
                    PlateSettingsStore.save(
                      settings.copyWith(showInRest: value),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Gryf i talerze zapisują się osobno dla kg i lb. '
                  'Teraz ustawiasz zestaw w ${unit.label}.',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static String _barCaption(double bar, WeightUnit unit) {
    if (bar == 0) return 'Bez gryfu — maszyny ładowane talerzami, np. suwnica.';
    if (PlateEquipment.standardBars(unit).contains(bar)) {
      return unit == WeightUnit.kg
          ? 'Olimpijski 20 kg, damski 15 kg, techniczny 10 kg.'
          : 'Olimpijski 45 lb, damski 35 lb.';
    }
    return 'Własny gryf: ${formatPlateNumber(bar)} ${unit.label}.';
  }
}

/// Gotowe wagi gryfu + „Brak” + „Inny” (wpisywana).
class _BarSelector extends StatelessWidget {
  const _BarSelector({
    required this.unit,
    required this.barWeight,
    required this.onChanged,
  });

  final WeightUnit unit;
  final double barWeight;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final standard = PlateEquipment.standardBars(unit);
    final isCustom = barWeight != 0 && !standard.contains(barWeight);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.tile),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          for (final bar in standard) ...[
            _Tab(
              key: plateEquipmentBarKey(formatPlateNumber(bar)),
              label: '${formatPlateNumber(bar)} ${unit.label}',
              selected: barWeight == bar,
              onTap: () => onChanged(bar),
            ),
            const SizedBox(width: 4),
          ],
          _Tab(
            key: plateEquipmentBarKey('none'),
            label: 'Brak',
            selected: barWeight == 0,
            onTap: () => onChanged(0),
          ),
          const SizedBox(width: 4),
          _Tab(
            key: plateEquipmentBarKey('custom'),
            label: isCustom ? formatPlateNumber(barWeight) : 'Inny',
            selected: isCustom,
            onTap: () async {
              final weight = await _askWeight(
                context,
                title: 'Waga gryfu',
                unit: unit,
                initial: isCustom ? barWeight : null,
                max: unit == WeightUnit.kg ? 60 : 130,
              );
              if (weight != null) onChanged(weight);
            },
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: AnimatedContainer(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? _selectedTab : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontSize: 13.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlateGrid extends StatelessWidget {
  const _PlateGrid({
    required this.unit,
    required this.equipment,
    required this.onToggle,
    required this.onRemove,
    required this.onAdd,
  });

  final WeightUnit unit;
  final PlateEquipment equipment;
  final ValueChanged<double> onToggle;
  final ValueChanged<double> onRemove;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 0.82,
      children: [
        for (final plate in equipment.plates)
          _PlateTile(
            key: plateEquipmentPlateKey(plate.weight),
            plate: plate,
            unit: unit,
            onTap: () => onToggle(plate.weight),
            onLongPress: plate.custom ? () => onRemove(plate.weight) : null,
          ),
        _AddPlateTile(onTap: onAdd),
      ],
    );
  }
}

class _PlateTile extends StatelessWidget {
  const _PlateTile({
    super.key,
    required this.plate,
    required this.unit,
    required this.onTap,
    this.onLongPress,
  });

  final PlateOption plate;
  final WeightUnit unit;
  final VoidCallback onTap;

  /// Tylko własny talerz da się usunąć (przytrzymanie).
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final on = plate.enabled;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      toggled: on,
      label: '${formatPlateNumber(plate.weight)} ${unit.label}',
      hint: onLongPress == null ? null : 'Przytrzymaj, by usunąć',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: AnimatedContainer(
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: on
                ? AppColors.primary.withValues(alpha: 0.08)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: on ? AppColors.primary : AppColors.border,
              width: 1.5,
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PlateDisc(
                      weight: plate.weight,
                      unit: unit,
                      size: 38,
                      enabled: on,
                    ),
                    const SizedBox(height: 6),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: formatPlateNumber(plate.weight),
                            style: AppTextStyles.number(
                              size: 18,
                              color: on
                                  ? AppColors.textPrimary
                                  : AppColors.textMuted,
                            ),
                          ),
                          TextSpan(
                            text: ' ${unit.label}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (on)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              if (plate.custom)
                const Positioned(
                  top: 7,
                  left: 8,
                  child: Text(
                    'WŁASNY',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
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

class _AddPlateTile extends StatelessWidget {
  const _AddPlateTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Dodaj własny talerz',
      excludeSemantics: true,
      child: InkWell(
        key: plateEquipmentAddPlateKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: CustomPaint(
          painter: _DashedBorderPainter(),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, color: WorkoutColors.link, size: 22),
                SizedBox(height: 4),
                Text(
                  'Własny',
                  style: TextStyle(
                    color: WorkoutColors.link,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
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

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(AppRadius.lg),
    ).deflate(0.75);
    final paint = Paint()
      ..color = WorkoutColors.dashedBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 5), paint);
        distance += 9;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) => false;
}

class _ShowInRestCard extends StatelessWidget {
  const _ShowInRestCard({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: WorkoutColors.chip,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.timer_outlined,
              color: WorkoutColors.link,
              size: 19,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Talerze w przerwie',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Pasek pod licznikiem odpoczynku przy ćwiczeniach, '
                  'w których użyłeś kalkulatora',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            key: plateEquipmentShowInRestKey,
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.eyebrow.copyWith(color: AppColors.textMuted),
    );
  }
}

/// Okno z polem liczby (waga gryfu / własnego talerza) w aktualnej
/// jednostce. Zwraca `null` po anulowaniu.
Future<double?> _askWeight(
  BuildContext context, {
  required String title,
  required WeightUnit unit,
  required double max,
  double? initial,
}) {
  return showDialog<double>(
    context: context,
    builder: (_) =>
        _WeightDialog(title: title, unit: unit, max: max, initial: initial),
  );
}

class _WeightDialog extends StatefulWidget {
  const _WeightDialog({
    required this.title,
    required this.unit,
    required this.max,
    this.initial,
  });

  final String title;
  final WeightUnit unit;
  final double max;
  final double? initial;

  @override
  State<_WeightDialog> createState() => _WeightDialogState();
}

class _WeightDialogState extends State<_WeightDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial == null ? '' : formatPlateNumber(widget.initial!),
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = parseWeightNumber(_controller.text);
    if (value == null || value <= 0) {
      setState(() => _error = 'Wpisz wagę większą od zera');
      return;
    }
    if (value > widget.max) {
      setState(
        () => _error =
            'Maksymalnie ${formatPlateNumber(widget.max)} ${widget.unit.label}',
      );
      return;
    }
    Navigator.of(context).pop((value * 100).round() / 100);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          suffixText: widget.unit.label,
          errorText: _error,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Anuluj'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Zapisz')),
      ],
    );
  }
}
