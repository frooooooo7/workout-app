import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/units/weight_unit.dart';
import '../utils/profile_details_labels.dart';
import 'body_weight_ruler.dart';

const bodyWeightGoalSaveKey = Key('body-weight-goal-save');
const bodyWeightGoalClearKey = Key('body-weight-goal-clear');

/// Wynik arkusza celu: `kg == null` — usuń cel.
typedef BodyWeightGoalInput = ({double? kg});

/// Arkusz ustawiania celu masy ciała na linijce. Przy istniejącym celu
/// ([currentGoalKg]) pozwala go też usunąć. Zwraca `null` po zamknięciu
/// bez zmian.
Future<BodyWeightGoalInput?> showBodyWeightGoalSheet(
  BuildContext context, {
  required double initialKg,
  double? currentGoalKg,
}) {
  return showModalBottomSheet<BodyWeightGoalInput>(
    context: context,
    backgroundColor: AppColors.surface,
    barrierColor: Colors.black54,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
    ),
    builder: (_) => _BodyWeightGoalSheet(
      initialKg: currentGoalKg ?? initialKg,
      editing: currentGoalKg != null,
    ),
  );
}

class _BodyWeightGoalSheet extends StatefulWidget {
  const _BodyWeightGoalSheet({required this.initialKg, required this.editing});

  final double initialKg;
  final bool editing;

  @override
  State<_BodyWeightGoalSheet> createState() => _BodyWeightGoalSheetState();
}

class _BodyWeightGoalSheetState extends State<_BodyWeightGoalSheet> {
  late double _goal = widget.initialKg;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.sm,
          AppSpacing.xl,
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
            Text(
              widget.editing ? 'Zmień cel' : 'Ustaw cel',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            const Text(
              'Postęp liczymy od pierwszego pomiaru, a datę — z tempa '
              'z ostatnich 4 tygodni.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: formatWeightValue(_goal),
                      style: AppTextStyles.number(size: 48),
                    ),
                    TextSpan(
                      text: ' ${WeightUnits.current.label}',
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
            const SizedBox(height: AppSpacing.xs),
            BodyWeightRuler(
              initial: widget.initialKg,
              value: _goal,
              onChanged: (kg) => setState(() => _goal = kg),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              key: bodyWeightGoalSaveKey,
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).pop((kg: _goal));
              },
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Zapisz cel'),
            ),
            if (widget.editing) ...[
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                key: bodyWeightGoalClearKey,
                onPressed: () => Navigator.of(context).pop((kg: null)),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.trendDown,
                  minimumSize: const Size.fromHeight(44),
                ),
                child: const Text('Usuń cel'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
