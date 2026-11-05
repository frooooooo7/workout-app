import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/units/weight_unit.dart';
import '../../../domain/services/plate_calculator.dart';
import '../ongoing_workout/workout_colors.dart';
import 'plate_visuals.dart';

const restPlateStripKey = Key('rest-plate-strip');

/// Pasek „Na stronę: 25 + 15 + 5” pod licznikiem odpoczynku — talerze na
/// następną serię, bez otwierania kalkulatora. Dotknięcie go otwiera.
class RestPlateStrip extends StatelessWidget {
  const RestPlateStrip({
    super.key,
    required this.calculation,
    required this.unit,
    required this.onTap,
  });

  final PlateCalculation calculation;
  final WeightUnit unit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final loadout = calculation.shown;
    // Tekst od największego (25 + 10 + …), a miniatura obok — jak rysunek
    // gryfu — od najlżejszego z lewej.
    final plates = [...?loadout?.perSide]..sort((a, b) => b.compareTo(a));
    final text = plates.isEmpty
        ? 'Sam gryf'
        : '${calculation.isExact ? '' : '≈ '}'
              '${plates.map(formatPlateNumber).join(' + ')}';
    return Semantics(
      button: true,
      label: 'Na stronę: $text. Otwórz kalkulator talerzy',
      excludeSemantics: true,
      child: Material(
        color: WorkoutColors.field,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: restPlateStripKey,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                MiniPlateStack(plates: plates, unit: unit),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'NA STRONĘ',
                        style: TextStyle(
                          color: WorkoutColors.textFaint,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.number(size: 18),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
