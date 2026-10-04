import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../training/presentation/widgets/stats/stats_format.dart';
import '../../domain/models/body_measurement_entry.dart';
import '../utils/body_measurement_format.dart';

const bodyMeasurementSheetSaveKey = Key('body-measurement-sheet-save');
const bodyMeasurementSheetDateKey = Key('body-measurement-sheet-date');

/// Pole arkusza dla danego pomiaru (testy).
Key bodyMeasurementFieldKey(BodyMeasurementField field) =>
    ValueKey('body-measurement-field-${field.name}');

/// Arkusz dodawania (albo edycji, gdy [initial] ma wpis) pomiarów z jednego
/// dnia. Puste pole — nie mierzono. [hints] to ostatnie znane wartości
/// (podpowiedź w pustych polach). [existingDates] — dni, które mają już
/// wpis (ostrzeżenie o zastąpieniu). Zwraca `null` po zamknięciu bez zapisu.
Future<BodyMeasurementEntry?> showBodyMeasurementEntrySheet(
  BuildContext context, {
  required DateTime initialDate,
  BodyMeasurementEntry? initial,
  Map<BodyMeasurementField, double> hints = const {},
  Set<DateTime> existingDates = const {},
  DateTime Function()? clock,
}) {
  return showModalBottomSheet<BodyMeasurementEntry>(
    context: context,
    backgroundColor: AppColors.surface,
    barrierColor: Colors.black54,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
    ),
    builder: (_) => _BodyMeasurementEntrySheet(
      initialDate: initial?.date ?? initialDate,
      initial: initial,
      hints: hints,
      existingDates: existingDates,
      clock: clock ?? DateTime.now,
    ),
  );
}

/// `84,5` / `84.5` → 84.5; puste → `null`; niepoprawne → `NaN`.
double? parseMeasurementInput(String text) {
  final trimmed = text.trim().replaceAll(',', '.');
  if (trimmed.isEmpty) return null;
  return double.tryParse(trimmed) ?? double.nan;
}

class _BodyMeasurementEntrySheet extends StatefulWidget {
  const _BodyMeasurementEntrySheet({
    required this.initialDate,
    required this.initial,
    required this.hints,
    required this.existingDates,
    required this.clock,
  });

  final DateTime initialDate;
  final BodyMeasurementEntry? initial;
  final Map<BodyMeasurementField, double> hints;
  final Set<DateTime> existingDates;
  final DateTime Function() clock;

  @override
  State<_BodyMeasurementEntrySheet> createState() =>
      _BodyMeasurementEntrySheetState();
}

class _BodyMeasurementEntrySheetState
    extends State<_BodyMeasurementEntrySheet> {
  late DateTime _date = widget.initialDate;
  late final Map<BodyMeasurementField, TextEditingController> _controllers = {
    for (final field in BodyMeasurementField.values)
      field: TextEditingController(
        text: switch (widget.initial?[field]) {
          final value? => formatMeasurementValue(value),
          null => '',
        },
      ),
  };
  final _errors = <BodyMeasurementField, String>{};
  String? _formError;

  bool get _editing => widget.initial != null;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

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

  void _submit() {
    final values = <BodyMeasurementField, double>{};
    final errors = <BodyMeasurementField, String>{};
    for (final field in BodyMeasurementField.values) {
      final value = parseMeasurementInput(_controllers[field]!.text);
      if (value == null) continue;
      if (value.isNaN || !field.accepts(value)) {
        errors[field] =
            'Od ${formatMeasurementValue(field.min)} do '
            '${formatMeasurement(field, field.max)}';
        continue;
      }
      values[field] = (value * 10).round() / 10;
    }
    setState(() {
      _errors
        ..clear()
        ..addAll(errors);
      _formError = errors.isEmpty && values.isEmpty
          ? 'Wpisz co najmniej jeden pomiar.'
          : null;
    });
    if (errors.isNotEmpty || values.isEmpty) return;
    HapticFeedback.lightImpact();
    Navigator.of(
      context,
    ).pop(BodyMeasurementEntry(date: _date, values: values));
  }

  @override
  Widget build(BuildContext context) {
    final replaces = !_editing && widget.existingDates.contains(_date);
    final fields = BodyMeasurementField.values;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
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
                _editing ? 'Edytuj pomiary' : 'Nowe pomiary',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              const Text(
                'Wpisz tylko to, co dziś mierzysz — reszta może zostać pusta.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: AppSpacing.sm),
              Material(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: InkWell(
                  key: bodyMeasurementSheetDateKey,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  // Dzień jest kluczem wpisu — przy edycji się nie zmienia.
                  onTap: _editing ? null : _pickDate,
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
                        if (!_editing)
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
                  'Ten dzień ma już pomiary — zapis je zastąpi.',
                  style: TextStyle(color: AppColors.statAmber, fontSize: 12.5),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              for (var i = 0; i < fields.length; i += 2) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _field(fields[i], last: false)),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: i + 1 < fields.length
                          ? _field(fields[i + 1], last: i + 2 >= fields.length)
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              if (_formError != null) ...[
                Text(
                  _formError!,
                  style: const TextStyle(
                    color: AppColors.strengthWeak,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
              ],
              const SizedBox(height: AppSpacing.xs),
              FilledButton(
                key: bodyMeasurementSheetSaveKey,
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Zapisz'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(BodyMeasurementField field, {required bool last}) {
    final hint = widget.hints[field];
    return TextField(
      key: bodyMeasurementFieldKey(field),
      controller: _controllers[field],
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: last ? TextInputAction.done : TextInputAction.next,
      onSubmitted: last ? (_) => _submit() : null,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        LengthLimitingTextInputFormatter(5),
      ],
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        labelText: field.label,
        // Etykieta zawsze u góry — widać jednostkę i ostatnią wartość.
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        floatingLabelStyle: const TextStyle(color: AppColors.textSecondary),
        hintText: hint == null ? null : formatMeasurementValue(hint),
        suffixText: field.unit,
        suffixStyle: const TextStyle(color: AppColors.textMuted),
        errorText: _errors[field],
        errorMaxLines: 2,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
    );
  }
}
