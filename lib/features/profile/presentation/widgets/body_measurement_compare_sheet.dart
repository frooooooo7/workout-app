import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../utils/body_measurement_format.dart';

const bodyMeasurementCompareApplyKey = Key('body-measurement-compare-apply');

/// Data wpisu w sekcji „Od” / „Do” arkusza porównania (testy).
Key bodyMeasurementCompareDateKey({
  required bool from,
  required DateTime date,
}) => ValueKey('body-measurement-compare-${from ? 'from' : 'to'}-$date');

/// Arkusz wyboru dwóch wpisów do porównania. [dates] — daty wszystkich
/// wpisów od najstarszej. Zwraca wybrane daty albo `null` po zamknięciu.
Future<({DateTime from, DateTime to})?> showBodyMeasurementCompareSheet(
  BuildContext context, {
  required List<DateTime> dates,
  required DateTime from,
  required DateTime to,
  required DateTime today,
}) {
  return showModalBottomSheet<({DateTime from, DateTime to})>(
    context: context,
    backgroundColor: AppColors.surface,
    barrierColor: Colors.black54,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
    ),
    builder: (_) => _CompareSheet(
      dates: dates,
      initialFrom: from,
      initialTo: to,
      today: today,
    ),
  );
}

class _CompareSheet extends StatefulWidget {
  const _CompareSheet({
    required this.dates,
    required this.initialFrom,
    required this.initialTo,
    required this.today,
  });

  final List<DateTime> dates;
  final DateTime initialFrom;
  final DateTime initialTo;
  final DateTime today;

  @override
  State<_CompareSheet> createState() => _CompareSheetState();
}

class _CompareSheetState extends State<_CompareSheet> {
  late DateTime _from = widget.initialFrom;
  late DateTime _to = widget.initialTo;

  void _pickFrom(DateTime date) {
    HapticFeedback.selectionClick();
    setState(() {
      _from = date;
      // „Do” zawsze po „Od” — przesuwamy na ostatni wpis.
      if (!_to.isAfter(date)) _to = widget.dates.last;
    });
  }

  void _pickTo(DateTime date) {
    HapticFeedback.selectionClick();
    setState(() => _to = date);
  }

  @override
  Widget build(BuildContext context) {
    final newestFirst = widget.dates.reversed.toList();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageGutter,
          AppSpacing.sm,
          AppSpacing.pageGutter,
          AppSpacing.md,
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
            const Text(
              'Porównaj pomiary',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _DateSection(
                      title: 'Od',
                      dates: newestFirst,
                      selected: _from,
                      today: widget.today,
                      // Ostatni wpis nie może być początkiem porównania.
                      enabled: (d) => d.isBefore(widget.dates.last),
                      keyOf: (d) =>
                          bodyMeasurementCompareDateKey(from: true, date: d),
                      onPick: _pickFrom,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _DateSection(
                      title: 'Do',
                      dates: newestFirst,
                      selected: _to,
                      today: widget.today,
                      enabled: (d) => d.isAfter(_from),
                      keyOf: (d) =>
                          bodyMeasurementCompareDateKey(from: false, date: d),
                      onPick: _pickTo,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              key: bodyMeasurementCompareApplyKey,
              onPressed: () =>
                  Navigator.of(context).pop((from: _from, to: _to)),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
              ),
              child: const Text('Porównaj'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateSection extends StatelessWidget {
  const _DateSection({
    required this.title,
    required this.dates,
    required this.selected,
    required this.today,
    required this.enabled,
    required this.keyOf,
    required this.onPick,
  });

  final String title;
  final List<DateTime> dates;
  final DateTime selected;
  final DateTime today;
  final bool Function(DateTime date) enabled;
  final Key Function(DateTime date) keyOf;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final date in dates)
              _DateChip(
                key: keyOf(date),
                label: formatMeasurementDate(date, today),
                selected: date == selected,
                onTap: enabled(date) ? () => onPick(date) : null,
              ),
          ],
        ),
      ],
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Semantics(
      button: true,
      selected: selected,
      enabled: !disabled,
      child: Material(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.18)
            : AppColors.tile,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.borderStrong,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: disabled
                    ? AppColors.textMuted
                    : selected
                    ? AppColors.textPrimary
                    : AppColors.iconOnTile,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
