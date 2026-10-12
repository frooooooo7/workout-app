import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_tab_header.dart';
import '../../../body_highlighter/models/body_gender.dart';
import '../../domain/models/body_measurement_entry.dart';
import '../../domain/models/profile_details.dart';
import '../bloc/body_measurements_cubit.dart';
import '../utils/body_measurement_comparison.dart';
import '../utils/body_measurement_format.dart';
import '../widgets/body_fat_summary.dart';
import '../widgets/body_measurement_change_card.dart';
import '../widgets/body_measurement_compare_pill.dart';
import '../widgets/body_measurement_compare_sheet.dart';
import '../widgets/body_measurement_entry_sheet.dart';
import '../widgets/body_measurement_history_link.dart';
import '../widgets/body_measurement_silhouette.dart';
import '../widgets/body_measurements_empty_state.dart';
import 'body_measurement_history_screen.dart';

const kBodyMeasurementsRoute = '/app/profile/body-measurements';
const bodyMeasurementsAddButtonKey = Key('body-measurements-add');

/// Pomiary ciała: porównanie dwóch wpisów na sylwetce (obwody w miejscu
/// pomiaru), tkanka tłuszczowa, zmiana wszystkich obwodów naraz i przejście
/// do historii wpisów. Wymaga [BodyMeasurementsCubit] w kontekście.
class BodyMeasurementsScreen extends StatefulWidget {
  const BodyMeasurementsScreen({
    super.key,
    this.clock = DateTime.now,
    this.loadGender,
  });

  final DateTime Function() clock;

  /// Płeć z profilu — kobieca sylwetka dla [Gender.female]. Bez niej (albo
  /// gdy się nie wczyta) sylwetka męska.
  final Future<Gender?> Function()? loadGender;

  @override
  State<BodyMeasurementsScreen> createState() => _BodyMeasurementsScreenState();
}

class _BodyMeasurementsScreenState extends State<BodyMeasurementsScreen> {
  /// `null`, dopóki płeć z profilu się wczytuje.
  BodyGender? _bodyGender;

  @override
  void initState() {
    super.initState();
    context.read<BodyMeasurementsCubit>().load();
    if (widget.loadGender == null) {
      _bodyGender = BodyGender.male;
    } else {
      unawaited(_resolveGender(widget.loadGender!));
    }
  }

  Future<void> _resolveGender(Future<Gender?> Function() load) async {
    Gender? gender;
    try {
      gender = await load().timeout(const Duration(seconds: 3));
    } catch (_) {
      /* offline albo brak profilu — sylwetka męska */
    }
    if (!mounted) return;
    setState(
      () => _bodyGender = gender == Gender.female
          ? BodyGender.female
          : BodyGender.male,
    );
  }

  DateTime get _today {
    final now = widget.clock();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> _addEntry() async {
    final cubit = context.read<BodyMeasurementsCubit>();
    if (cubit.state.saving) return;
    final entries = cubit.state.entries ?? const <BodyMeasurementEntry>[];
    final entry = await showBodyMeasurementEntrySheet(
      context,
      initialDate: _today,
      hints: _latestValues(entries),
      existingDates: {for (final e in entries) e.date},
      clock: widget.clock,
    );
    if (entry == null) return;
    await cubit.save(entry);
  }

  Future<void> _pickComparison(BodyMeasurementComparison comparison) async {
    final cubit = context.read<BodyMeasurementsCubit>();
    final picked = await showBodyMeasurementCompareSheet(
      context,
      dates: [for (final e in cubit.state.entries!) e.date],
      from: comparison.from,
      to: comparison.to,
      today: _today,
    );
    if (picked == null) return;
    cubit.compare(picked.from, picked.to);
  }

  void _openHistory([BodyMeasurementField? field]) {
    if (field != null) context.read<BodyMeasurementsCubit>().selectField(field);
    BodyMeasurementHistoryScreen.open(context, clock: widget.clock);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<BodyMeasurementsCubit, BodyMeasurementsState>(
      listenWhen: (previous, current) =>
          current.messageId != previous.messageId && current.message != null,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(state.message!),
              behavior: SnackBarBehavior.floating,
            ),
          );
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              AppTabHeader(
                title: 'Pomiary ciała',
                showSync: false,
                leading: AppTabHeaderButton.back(
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                actions: [
                  AppTabHeaderButton(
                    key: bodyMeasurementsAddButtonKey,
                    icon: Icons.add_rounded,
                    tooltip: 'Dodaj pomiary',
                    accent: true,
                    onPressed: _addEntry,
                  ),
                ],
              ),
              Expanded(
                child:
                    BlocBuilder<BodyMeasurementsCubit, BodyMeasurementsState>(
                      builder: (context, state) {
                        final cubit = context.read<BodyMeasurementsCubit>();
                        final entries = state.entries;
                        if (entries == null) {
                          if (state.loadError != null) {
                            return _LoadError(
                              message: state.loadError!,
                              onRetry: cubit.load,
                            );
                          }
                          return const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          );
                        }
                        final comparison = BodyMeasurementComparison.of(
                          entries,
                          from: state.comparedDates?.from,
                          to: state.comparedDates?.to,
                        );
                        return RefreshIndicator(
                          color: AppColors.primary,
                          onRefresh: cubit.load,
                          child: comparison == null
                              ? BodyMeasurementsEmptyState(
                                  gender: _bodyGender,
                                  onAdd: _addEntry,
                                )
                              : _Content(
                                  comparison: comparison,
                                  entryCount: entries.length,
                                  today: _today,
                                  gender: _bodyGender,
                                  onPickComparison: entries.length < 2
                                      ? null
                                      : () => _pickComparison(comparison),
                                  onOpenHistory: _openHistory,
                                ),
                        );
                      },
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ostatnia znana wartość każdego pomiaru.
Map<BodyMeasurementField, double> _latestValues(
  List<BodyMeasurementEntry> sorted,
) => {for (final e in sorted) ...e.values};

class _Content extends StatelessWidget {
  const _Content({
    required this.comparison,
    required this.entryCount,
    required this.today,
    required this.gender,
    required this.onPickComparison,
    required this.onOpenHistory,
  });

  final BodyMeasurementComparison comparison;
  final int entryCount;
  final DateTime today;
  final BodyGender? gender;
  final VoidCallback? onPickComparison;
  final void Function([BodyMeasurementField? field]) onOpenHistory;

  @override
  Widget build(BuildContext context) {
    final deltas = comparison.deltas;
    final bodyFat = deltas[BodyMeasurementField.bodyFat];
    final changes = {
      for (final MapEntry(:key, :value) in deltas.entries)
        if (!key.isPercent && value.change != null) key: value.change!,
    };

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.pageGutter,
        AppSpacing.xxs,
        AppSpacing.pageGutter,
        AppSpacing.xl + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Wąski ekran albo duża czcionka — pigułka się zmniejsza.
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: BodyMeasurementComparePill(
                  from: comparison.from,
                  to: comparison.to,
                  today: today,
                  onTap: onPickComparison,
                ),
              ),
            ),
            if (bodyFat != null) ...[
              const SizedBox(width: AppSpacing.sm),
              BodyFatSummary(delta: bodyFat),
            ],
          ],
        ),
        const SizedBox(height: 6),
        if (gender == null)
          const SizedBox(height: BodyMeasurementSilhouette.height)
        else
          BodyMeasurementSilhouette(
            gender: gender!,
            deltas: deltas,
            onFieldTap: onOpenHistory,
          ),
        const SizedBox(height: 6),
        // Bez wspólnych obwodów w obu datach (np. sam tłuszcz) karta nie
        // ma czego pokazać; przy jednym wpisie zapowiada porównanie.
        if (changes.isNotEmpty || !comparison.hasRange)
          BodyMeasurementChangeCard(
            title: comparison.hasRange
                ? 'Zmiana od ${formatMeasurementDate(comparison.from, today)}'
                : 'Zmiana',
            changes: changes,
            emptyMessage:
                'Dodaj kolejne pomiary, a zobaczysz tu, jak zmienia się '
                'każdy obwód.',
            onFieldTap: onOpenHistory,
          ),
        const SizedBox(height: 10),
        BodyMeasurementHistoryLink(
          entryCount: entryCount,
          onTap: onOpenHistory,
        ),
      ],
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: AppColors.strengthWeak,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Spróbuj ponownie'),
            ),
          ],
        ),
      ),
    );
  }
}
