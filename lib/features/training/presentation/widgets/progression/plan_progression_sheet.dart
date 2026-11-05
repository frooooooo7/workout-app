import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/units/weight_unit.dart';
import '../../../domain/models/progression_settings.dart';
import 'progression_picker.dart';

/// Wybór z arkusza: [progression] `null` — plan idzie za ustawieniami konta.
typedef PlanProgressionChoice = ({ProgressionSettings? progression});

/// Arkusz „Progresja w planie”: ta sama lista metod co w Ustawieniach plus
/// „Jak w ustawieniach”. `null` po zamknięciu bez „Gotowe”.
Future<PlanProgressionChoice?> showPlanProgressionSheet(
  BuildContext context, {
  required String planName,
  required ProgressionSettings? own,
  required ProgressionSettings account,
}) {
  return showModalBottomSheet<PlanProgressionChoice>(
    context: context,
    backgroundColor: AppColors.surface,
    barrierColor: Colors.black54,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
    ),
    builder: (_) =>
        _PlanProgressionSheet(planName: planName, own: own, account: account),
  );
}

class _PlanProgressionSheet extends StatefulWidget {
  const _PlanProgressionSheet({
    required this.planName,
    required this.own,
    required this.account,
  });

  final String planName;
  final ProgressionSettings? own;
  final ProgressionSettings account;

  @override
  State<_PlanProgressionSheet> createState() => _PlanProgressionSheetState();
}

class _PlanProgressionSheetState extends State<_PlanProgressionSheet> {
  late bool _inherits = widget.own == null;

  /// Ostatnio wybrana własna metoda — wraca po kliknięciu innej po „Jak
  /// w ustawieniach”.
  late ProgressionSettings _own = widget.own ?? widget.account;

  @override
  Widget build(BuildContext context) {
    final name = widget.planName.trim();
    final height = MediaQuery.sizeOf(context).height;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: height * 0.9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.sm),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty
                        ? 'Progresja w tym planie'
                        : 'Progresja w planie „$name”',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Nadpisuje ustawienie z Ustawień tylko w tym planie.',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: ProgressionPicker(
                  settings: _inherits ? widget.account : _own,
                  inherits: _inherits,
                  inheritLabel: widget.account
                      .inUnit(WeightUnits.current)
                      .summary,
                  onInherit: () => setState(() => _inherits = true),
                  onChanged: (next) => setState(() {
                    _inherits = false;
                    _own = next;
                  }),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: FilledButton(
                key: const ValueKey('plan-progression-done'),
                onPressed: () => Navigator.of(
                  context,
                ).pop((progression: _inherits ? null : _own)),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                ),
                child: const Text(
                  'Gotowe',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
