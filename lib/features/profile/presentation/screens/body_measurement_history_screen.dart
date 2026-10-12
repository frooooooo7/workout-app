import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_action_sheet.dart';
import '../../../../core/widgets/app_tab_header.dart';
import '../../../training/presentation/widgets/stats/stats_format.dart';
import '../../domain/models/body_measurement_entry.dart';
import '../bloc/body_measurements_cubit.dart';
import '../widgets/body_measurement_entry_sheet.dart';
import '../widgets/body_measurement_entry_tile.dart';
import '../widgets/body_measurement_trend_card.dart';

/// Historia pomiarów: wykres wybranego pomiaru i lista wpisów do edycji
/// albo usunięcia. Otwierana z [BodyMeasurementsScreen] z tym samym
/// [BodyMeasurementsCubit].
class BodyMeasurementHistoryScreen extends StatefulWidget {
  const BodyMeasurementHistoryScreen({super.key, this.clock = DateTime.now});

  final DateTime Function() clock;

  /// Otwiera historię z kubitem ekranu pomiarów z [context].
  static Future<void> open(
    BuildContext context, {
    DateTime Function() clock = DateTime.now,
  }) {
    final cubit = context.read<BodyMeasurementsCubit>();
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: BodyMeasurementHistoryScreen(clock: clock),
        ),
      ),
    );
  }

  @override
  State<BodyMeasurementHistoryScreen> createState() =>
      _BodyMeasurementHistoryScreenState();
}

enum _EntryAction { edit, delete }

class _BodyMeasurementHistoryScreenState
    extends State<BodyMeasurementHistoryScreen> {
  Future<void> _editEntry(BodyMeasurementEntry entry) async {
    final cubit = context.read<BodyMeasurementsCubit>();
    final edited = await showBodyMeasurementEntrySheet(
      context,
      initialDate: entry.date,
      initial: entry,
      clock: widget.clock,
    );
    if (edited == null || edited == entry) return;
    await cubit.save(edited);
  }

  Future<void> _showEntryActions(BodyMeasurementEntry entry) async {
    final action = await showAppActionSheet<_EntryAction>(
      context,
      title: formatStatsLongDate(entry.date),
      actions: const [
        AppSheetAction(
          value: _EntryAction.edit,
          icon: Icons.edit_outlined,
          label: 'Edytuj',
        ),
        AppSheetAction(
          value: _EntryAction.delete,
          icon: Icons.delete_outline_rounded,
          label: 'Usuń pomiary',
          destructive: true,
        ),
      ],
    );
    if (!mounted) return;
    switch (action) {
      case _EntryAction.edit:
        await _editEntry(entry);
      case _EntryAction.delete:
        await context.read<BodyMeasurementsCubit>().delete(entry);
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppTabHeader(
              title: 'Historia pomiarów',
              showSync: false,
              leading: AppTabHeaderButton.back(
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            Expanded(
              child: BlocBuilder<BodyMeasurementsCubit, BodyMeasurementsState>(
                builder: (context, state) {
                  final entries =
                      state.entries ?? const <BodyMeasurementEntry>[];
                  if (entries.isEmpty) {
                    return const Center(
                      child: Text(
                        'Brak pomiarów',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    );
                  }
                  final newestFirst = entries.reversed.toList();
                  return ListView(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.pageGutter,
                      AppSpacing.xs,
                      AppSpacing.pageGutter,
                      AppSpacing.xl + MediaQuery.paddingOf(context).bottom,
                    ),
                    children: [
                      BodyMeasurementTrendCard(
                        entries: entries,
                        selected: state.selectedField,
                        onSelected: context
                            .read<BodyMeasurementsCubit>()
                            .selectField,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      const Padding(
                        padding: EdgeInsets.only(left: AppSpacing.xxs),
                        child: Text('Wpisy', style: _sectionStyle),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                          child: Column(
                            children: [
                              for (final entry in newestFirst) ...[
                                if (entry != newestFirst.first)
                                  const Divider(
                                    height: 1,
                                    thickness: 1,
                                    indent: 14,
                                    color: AppColors.border,
                                  ),
                                BodyMeasurementEntryTile(
                                  key: bodyMeasurementEntryKey(entry.date),
                                  entry: entry,
                                  onTap: () => _editEntry(entry),
                                  onMore: () => _showEntryActions(entry),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _sectionStyle = TextStyle(
  color: AppColors.textPrimary,
  fontSize: 15,
  fontWeight: FontWeight.w800,
);
