import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../training/presentation/widgets/stats/stats_format.dart';
import '../../domain/models/profile_details.dart';
import '../utils/profile_details_labels.dart';
import 'ruler_picker.dart';

const bodyWeightSheetSaveKey = Key('body-weight-sheet-save');
const bodyWeightSheetDateKey = Key('body-weight-sheet-date');
const bodyWeightSheetRulerKey = Key('body-weight-sheet-ruler');

/// Wynik arkusza pomiaru.
typedef BodyWeightInput = ({DateTime date, double weightKg});

/// Arkusz dodawania (albo edycji, gdy [editing]) pomiaru: dzień i waga na
/// linijce. [existingDates] — dni, które mają już pomiar (ostrzeżenie
/// o zastąpieniu). Zwraca `null` po zamknięciu bez zapisu.
Future<BodyWeightInput?> showBodyWeightEntrySheet(
  BuildContext context, {
  required DateTime initialDate,
  required double initialWeightKg,
  bool editing = false,
  Set<DateTime> existingDates = const {},
  DateTime Function()? clock,
}) {
  return showModalBottomSheet<BodyWeightInput>(
    context: context,
    backgroundColor: AppColors.surface,
    barrierColor: Colors.black54,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
    ),
    builder: (_) => _BodyWeightEntrySheet(
      initialDate: initialDate,
      initialWeightKg: initialWeightKg,
      editing: editing,
      existingDates: existingDates,
      clock: clock ?? DateTime.now,
    ),
  );
}

class _BodyWeightEntrySheet extends StatefulWidget {
  const _BodyWeightEntrySheet({
    required this.initialDate,
    required this.initialWeightKg,
    required this.editing,
    required this.existingDates,
    required this.clock,
  });

  final DateTime initialDate;
  final double initialWeightKg;
  final bool editing;
  final Set<DateTime> existingDates;
  final DateTime Function() clock;

  @override
  State<_BodyWeightEntrySheet> createState() => _BodyWeightEntrySheetState();
}

class _BodyWeightEntrySheetState extends State<_BodyWeightEntrySheet> {
  late DateTime _date = widget.initialDate;
  late double _weight = widget.initialWeightKg;

  DateTime get _today {
    final now = widget.clock();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: _today,
      helpText: 'Dzień pomiaru',
    );
    if (picked != null && mounted) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    }
  }

  String _dateLabel() {
    final today = _today;
    if (_date == today) return 'Dziś';
    if (_date == DateTime(today.year, today.month, today.day - 1)) {
      return 'Wczoraj';
    }
    return formatStatsLongDate(_date);
  }

  @override
  Widget build(BuildContext context) {
    final replaces = !widget.editing && widget.existingDates.contains(_date);
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
              widget.editing ? 'Edytuj pomiar' : 'Nowy pomiar',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Material(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: InkWell(
                key: bodyWeightSheetDateKey,
                borderRadius: BorderRadius.circular(AppRadius.md),
                // Dzień jest kluczem pomiaru — przy edycji się nie zmienia.
                onTap: widget.editing ? null : _pickDate,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.event_rounded,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          _dateLabel(),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (!widget.editing)
                        const Icon(
                          Icons.expand_more_rounded,
                          color: AppColors.textSecondary,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (replaces) ...[
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Ten dzień ma już pomiar — zapis go zastąpi.',
                style: TextStyle(color: AppColors.statAmber, fontSize: 12.5),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: formatWeightValue(_weight),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const TextSpan(
                      text: ' kg',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            RulerPicker(
              key: bodyWeightSheetRulerKey,
              min: kMinWeightKg,
              max: kMaxWeightKg,
              step: 0.1,
              majorEvery: 10,
              tickGap: 8,
              initial: widget.initialWeightKg,
              value: _weight,
              semanticsLabel: 'Waga',
              formatValue: formatWeightKg,
              onChanged: (kg) => setState(() => _weight = kg),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              key: bodyWeightSheetSaveKey,
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).pop((date: _date, weightKg: _weight));
              },
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Zapisz'),
            ),
          ],
        ),
      ),
    );
  }
}
