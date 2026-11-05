import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/units/weight_unit.dart';
import '../../../domain/services/plan_update_from_session.dart';

/// Stan karty „Zaktualizuj plan”.
enum PlanUpdateStatus { proposed, saving, updated }

/// Karta po treningu z planu: „Zaktualizować plan o dzisiejsze ciężary?”.
///
/// Plan nie zmienia się sam — użytkownik widzi, co się zmieni, i decyduje.
/// Po zapisie karta zostaje z „Cofnij”, a „Nie teraz” ją chowa.
class PlanUpdateCard extends StatelessWidget {
  const PlanUpdateCard({
    super.key,
    required this.planName,
    required this.changes,
    required this.status,
    required this.onUpdate,
    required this.onDismiss,
    required this.onUndo,
  });

  final String planName;
  final List<PlanExerciseUpdate> changes;
  final PlanUpdateStatus status;
  final VoidCallback onUpdate;
  final VoidCallback onDismiss;
  final VoidCallback onUndo;

  static const _maxRows = 4;

  @override
  Widget build(BuildContext context) {
    final updated = status == PlanUpdateStatus.updated;
    final saving = status == PlanUpdateStatus.saving;
    final accent = updated ? AppColors.success : AppColors.primaryVariant;
    final shown = changes.take(_maxRows).toList();
    final hidden = changes.length - shown.length;
    final unit = WeightUnits.current.label;

    return AnimatedContainer(
      key: const ValueKey('plan-update-card'),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  updated ? Icons.check_rounded : Icons.trending_up_rounded,
                  size: 20,
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      updated
                          ? 'Plan „$planName” zaktualizowany'
                          : 'Zaktualizować plan „$planName”?',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      updated
                          ? 'Następny trening zacznie się od tych wartości.'
                          : 'Dzisiejsze ciężary i powtórzenia staną się '
                                'domyślnymi w planie.',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final change in shown)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ChangeRow(change: change, unit: unit),
            ),
          if (hidden > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'i jeszcze $hidden ${hidden == 1 ? 'ćwiczenie' : 'ćwiczenia'}',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 4),
          if (updated)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const ValueKey('plan-update-undo'),
                onPressed: onUndo,
                child: const Text('Cofnij'),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    key: const ValueKey('plan-update-dismiss'),
                    onPressed: saving ? null : onDismiss,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      minimumSize: const Size(0, 44),
                    ),
                    child: const Text('Nie teraz'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    key: const ValueKey('plan-update-confirm'),
                    onPressed: saving ? null : onUpdate,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Zaktualizuj plan',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ChangeRow extends StatelessWidget {
  const _ChangeRow({required this.change, required this.unit});

  final PlanExerciseUpdate change;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            change.exerciseName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            change.before,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.lineThrough,
              decorationColor: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            '${change.after}  ($unit × powt.)',
            style: const TextStyle(
              color: AppColors.success,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
