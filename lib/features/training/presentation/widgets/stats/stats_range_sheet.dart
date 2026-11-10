import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../domain/models/training_stats.dart';
import '../../bloc/training_stats_cubit.dart';
import 'stats_date_range_picker.dart';
import 'stats_format.dart';
import 'stats_range_selector.dart' show formatStatsDateRange;

/// Wybór zakresu na ekranach szczegółów: mała pigułka „30 dni ▾” w nagłówku
/// zamiast pełnego paska — zakres jest wspólny z pulpitem.
class StatsRangeChip extends StatelessWidget {
  const StatsRangeChip({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TrainingStatsCubit, TrainingStatsState>(
      buildWhen: (a, b) =>
          a.range != b.range ||
          a.customRange != b.customRange ||
          a.snapshot?.window != b.snapshot?.window,
      builder: (context, state) {
        final snapshot = state.snapshot;
        final label =
            state.range == StatsRange.custom && state.customRange != null
            ? formatStatsDateRange(state.customRange!)
            : snapshot != null && snapshot.range == state.range
            ? formatStatsPeriodTitle(snapshot)
            : state.range.label;
        return Semantics(
          button: true,
          label: 'Zakres: $label. Zmień',
          excludeSemantics: true,
          onTap: () => showStatsRangeSheet(context),
          child: InkWell(
            key: const ValueKey('stats-range-chip-button'),
            onTap: () {
              HapticFeedback.selectionClick();
              showStatsRangeSheet(context);
            },
            borderRadius: BorderRadius.circular(AppRadius.tile),
            child: Container(
              height: AppSpacing.minTapTarget,
              constraints: const BoxConstraints(maxWidth: 190),
              padding: const EdgeInsets.only(left: 14, right: 8),
              decoration: BoxDecoration(
                color: AppColors.tile,
                borderRadius: BorderRadius.circular(AppRadius.tile),
                border: Border.all(color: AppColors.borderStrong),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Arkusz z gotowymi zakresami i „Własny zakres…” (kalendarz).
Future<void> showStatsRangeSheet(BuildContext context) {
  final cubit = context.read<TrainingStatsCubit>();
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            for (final range in StatsRange.presets)
              ListTile(
                key: ValueKey('stats-range-${range.name}'),
                title: Text(
                  range.label,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: cubit.state.range == range
                    ? const Icon(
                        Icons.check_rounded,
                        color: AppColors.primaryVariant,
                      )
                    : null,
                onTap: () {
                  cubit.selectRange(range);
                  Navigator.of(sheetContext).pop();
                },
              ),
            ListTile(
              key: const ValueKey('stats-range-custom'),
              leading: const Icon(
                Icons.date_range_rounded,
                color: AppColors.textSecondary,
              ),
              title: const Text(
                'Własny zakres…',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: cubit.state.range == StatsRange.custom
                  ? const Icon(
                      Icons.check_rounded,
                      color: AppColors.primaryVariant,
                    )
                  : null,
              onTap: () async {
                final now = DateTime.now();
                final picked = await pickStatsDateRange(
                  sheetContext,
                  initial: cubit.state.customRange,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(now.year, now.month, now.day),
                );
                if (picked != null) cubit.selectCustomRange(picked);
                if (sheetContext.mounted) Navigator.of(sheetContext).pop();
              },
            ),
          ],
        ),
      ),
    ),
  );
}
