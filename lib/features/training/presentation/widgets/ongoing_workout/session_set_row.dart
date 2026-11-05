import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/units/weight_unit.dart';
import '../../../domain/models/progression_settings.dart';
import '../../../domain/models/training_session.dart';
import '../../../domain/services/live_workout_insights.dart';
import '../table_cell_input.dart';
import 'record_set_tag.dart';
import 'session_set_badge.dart';
import 'set_check_button.dart';
import 'set_table_layout.dart';
import 'workout_colors.dart';
import 'workout_accent.dart';

/// Wiersz serii w treningu na żywo: numer / rodzaj, wynik z poprzedniego
/// treningu, pola i duży przycisk odhaczenia. Zrobiona seria zielenieje,
/// następna do zrobienia ([active]) jest wyróżniona i ma podpowiedź
/// progresji w polu ciężaru. Znaczek serii otwiera arkusz z rodzajem serii
/// i usuwaniem.
class SessionSetRow extends StatelessWidget {
  const SessionSetRow({
    super.key,
    required this.exerciseIndex,
    required this.setIndex,
    required this.label,
    required this.set,
    required this.layout,
    required this.active,
    required this.record,
    required this.onChanged,
    required this.onPickType,
    this.previousText,
    this.onFillPrevious,
    this.progression,
    this.onRemove,
  });

  final int exerciseIndex;
  final int setIndex;
  final String label;
  final TrainingSessionSet set;
  final SetTableLayout layout;
  final bool active;

  /// Seria pobiła rekord ćwiczenia — złoty znaczek.
  final bool record;
  final ValueChanged<TrainingSessionSet> onChanged;
  final VoidCallback onPickType;

  /// `82,5 × 8` z poprzedniego treningu; dotknięcie ([onFillPrevious])
  /// wpisuje go w pola.
  final String? previousText;
  final VoidCallback? onFillPrevious;
  final ProgressionHint? progression;

  /// `null` — ostatniej serii ćwiczenia nie da się usunąć.
  final VoidCallback? onRemove;

  bool get _isWarmup => set.setType == SetType.warmup;

  String get _semanticName => _isWarmup ? 'Seria rozgrzewkowa' : 'Seria $label';

  void _toggle(bool completed) {
    onChanged(
      set.copyWith(
        completed: completed,
        completedAt: completed ? DateTime.now().toUtc() : null,
        clearCompletedAt: !completed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final completed = set.completed;
    final highlighted = active && !completed;
    final accent = WorkoutAccent.of(context);

    final row = AnimatedContainer(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      height: highlighted ? 56 : 48,
      padding: EdgeInsets.symmetric(
        horizontal: SetTableLayout.rowPadding - (highlighted ? 1.5 : 0),
      ),
      decoration: BoxDecoration(
        color: completed
            ? AppColors.success.withValues(alpha: 0.06)
            : highlighted
            ? accent.fill.withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: highlighted
            ? Border.all(
                color: accent.strong.withValues(alpha: 0.55),
                width: 1.5,
              )
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: SetTableLayout.badgeWidth,
            child: Center(
              child: SessionSetBadge(
                key: ValueKey('session-set-type-$exerciseIndex-$setIndex'),
                label: label,
                type: set.setType,
                completed: completed,
                active: highlighted,
                onTap: onPickType,
              ),
            ),
          ),
          const SizedBox(width: SetTableLayout.gap),
          if (layout.showPrevious) ...[
            SizedBox(
              width: layout.previousWidth,
              child: _PreviousCell(
                key: ValueKey('session-set-previous-$exerciseIndex-$setIndex'),
                text: previousText,
                emphasized: highlighted,
                onTap: onFillPrevious,
              ),
            ),
            const SizedBox(width: SetTableLayout.gap),
          ] else
            const Spacer(),
          if (layout.showWeight) ...[
            SizedBox(
              width: layout.weightWidth,
              child: _WeightField(
                key: ValueKey('session-set-weight-$exerciseIndex-$setIndex'),
                set: set,
                look: _look(completed: completed, highlighted: highlighted),
                progression: highlighted ? progression : null,
                onChanged: onChanged,
              ),
            ),
            const SizedBox(width: SetTableLayout.gap),
          ],
          SizedBox(
            width: layout.repsWidth,
            child: _RepsField(
              key: ValueKey('session-set-reps-$exerciseIndex-$setIndex'),
              set: set,
              look: _look(completed: completed, highlighted: highlighted),
              progression: highlighted ? progression : null,
              onChanged: onChanged,
            ),
          ),
          if (layout.showRir) ...[
            const SizedBox(width: SetTableLayout.gap),
            SizedBox(
              width: layout.rirWidth,
              child: TableCellInput(
                key: ValueKey('session-set-rir-$exerciseIndex-$setIndex'),
                value: set.actualRir ?? '',
                hint: set.plannedRir?.isNotEmpty == true
                    ? set.plannedRir!
                    : '-',
                look: _look(
                  completed: completed,
                  highlighted: highlighted,
                  small: true,
                ),
                onChanged: (value) => onChanged(
                  set.copyWith(
                    actualRir: value,
                    clearActualRir: value.trim().isEmpty,
                  ),
                ),
              ),
            ),
          ],
          if (layout.showTempo) ...[
            const SizedBox(width: SetTableLayout.gap),
            SizedBox(
              width: layout.tempoWidth,
              child: TableCellInput(
                key: ValueKey('session-set-tempo-$exerciseIndex-$setIndex'),
                value: set.actualTempo ?? '',
                hint: set.plannedTempo?.isNotEmpty == true
                    ? set.plannedTempo!
                    : '-',
                keyboardType: TextInputType.text,
                look: _look(
                  completed: completed,
                  highlighted: highlighted,
                  small: true,
                ),
                onChanged: (value) => onChanged(
                  set.copyWith(
                    actualTempo: value,
                    clearActualTempo: value.trim().isEmpty,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(width: SetTableLayout.gap),
          SetCheckButton(
            key: ValueKey('session-set-check-$exerciseIndex-$setIndex'),
            completed: completed,
            active: highlighted,
            semanticLabel: _semanticName,
            onChanged: _toggle,
          ),
        ],
      ),
    );

    final content = Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          row,
          if (record)
            Positioned(
              left: SetTableLayout.badgeWidth + SetTableLayout.gap,
              top: -7,
              child: RecordSetTag(
                key: ValueKey('session-set-record-$exerciseIndex-$setIndex'),
              ),
            ),
        ],
      ),
    );

    final removable = onRemove;
    if (removable == null) return content;
    return Semantics(
      customSemanticsActions: {
        const CustomSemanticsAction(label: 'Usuń serię'): removable,
      },
      child: content,
    );
  }

  /// Pola zrobionej serii wyglądają jak zwykły tekst (dalej da się je
  /// poprawić), aktywnej — jak pola z obwódką, pozostałe są ciche.
  TableCellInputLook _look({
    required bool completed,
    required bool highlighted,
    bool small = false,
  }) {
    final size = small ? 17.0 : (highlighted ? 21.0 : 20.0);
    final textColor = completed && _isWarmup
        ? AppColors.iconOnTile
        : AppColors.textPrimary;
    return TableCellInputLook(
      textStyle: AppTextStyles.number(size: size, color: textColor),
      hintStyle: AppTextStyles.number(size: size, color: AppColors.textMuted),
      fillColor: completed ? Colors.transparent : WorkoutColors.field,
      borderColor: highlighted ? WorkoutColors.fieldBorder : Colors.transparent,
      radius: 11,
      verticalPadding: highlighted ? 10 : 8,
    );
  }
}

/// Pole ciężaru z podpowiedzią progresji: pusty placeholder to proponowany
/// ciężar, a znaczek `+2,5` nad polem mówi, o ile więcej niż poprzednio.
/// Użytkownik dalej wpisuje ciężar sam.
class _WeightField extends StatelessWidget {
  const _WeightField({
    super.key,
    required this.set,
    required this.look,
    required this.progression,
    required this.onChanged,
  });

  final TrainingSessionSet set;
  final TableCellInputLook look;
  final ProgressionHint? progression;
  final ValueChanged<TrainingSessionSet> onChanged;

  @override
  Widget build(BuildContext context) {
    final hint = progression;
    final unit = WeightUnits.current;
    final field = WeightCellInput(
      valueKg: set.actualWeight,
      // Propozycja z progresji ma pierwszeństwo przed ciężarem z planu.
      hintKg: hint == null ? set.plannedWeight : null,
      fallbackHint: hint == null
          ? ''
          : formatStepNumber(unit.fromKg(hint.weightKg)),
      look: look,
      onChanged: (value) => onChanged(
        set.copyWith(
          actualWeight: value,
          clearActualWeight: value.trim().isEmpty,
        ),
      ),
    );
    if (hint == null) return field;
    final String text;
    if (hint.isDeload) {
      final percent = ((1 - ProgressionSettings.deloadFactor) * 100).round();
      text = '−$percent%';
    } else if (hint.isIncrease) {
      text = '+${formatStepNumber(unit.fromKg(hint.deltaKg))}';
    } else {
      return field;
    }
    return _Tagged(
      field: field,
      tag: _HintTag(
        key: const Key('progression-hint-tag'),
        text: text,
        deload: hint.isDeload,
        semanticLabel: 'Propozycja: ${formatWeightWithUnit(hint.weightKg)}',
      ),
    );
  }
}

/// Pole powtórzeń; przy podwójnej progresji placeholder to cel na dziś,
/// a znaczek `+1` mówi, o ile więcej niż poprzednio.
class _RepsField extends StatelessWidget {
  const _RepsField({
    super.key,
    required this.set,
    required this.look,
    required this.progression,
    required this.onChanged,
  });

  final TrainingSessionSet set;
  final TableCellInputLook look;
  final ProgressionHint? progression;
  final ValueChanged<TrainingSessionSet> onChanged;

  @override
  Widget build(BuildContext context) {
    final target = progression?.reps;
    final field = TableCellInput(
      value: set.actualReps ?? '',
      hint: target?.toString() ?? set.plannedReps,
      look: look,
      onChanged: (value) => onChanged(
        set.copyWith(actualReps: value, clearActualReps: value.trim().isEmpty),
      ),
    );
    final hint = progression;
    if (hint == null || !hint.addsReps) return field;
    return _Tagged(
      field: field,
      tag: _HintTag(
        key: const Key('progression-reps-tag'),
        text: '+${hint.repsDelta}',
        semanticLabel: 'Propozycja: ${hint.reps} powtórzeń',
      ),
    );
  }
}

class _Tagged extends StatelessWidget {
  const _Tagged({required this.field, required this.tag});

  final Widget field;
  final Widget tag;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        field,
        Positioned(right: 4, top: -9, child: tag),
      ],
    );
  }
}

/// Mały znaczek nad polem: zielony przy zwyżce, bursztynowy przy deloadzie.
class _HintTag extends StatelessWidget {
  const _HintTag({
    super.key,
    required this.text,
    required this.semanticLabel,
    this.deload = false,
  });

  final String text;
  final String semanticLabel;
  final bool deload;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: deload
              ? WorkoutColors.deloadTag
              : WorkoutColors.progressionTag,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: deload ? AppColors.statAmber : AppColors.success,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

/// Wynik tej serii z poprzedniego treningu; dotknięcie wpisuje go w pola.
class _PreviousCell extends StatelessWidget {
  const _PreviousCell({
    super.key,
    required this.text,
    required this.emphasized,
    required this.onTap,
  });

  final String? text;
  final bool emphasized;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text ?? '—',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.tabular(
        TextStyle(
          color: text == null
              ? AppColors.textMuted
              : emphasized
              ? WorkoutColors.textSoft
              : WorkoutColors.textFaint,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    final cell = SizedBox(
      height: 36,
      child: Align(alignment: Alignment.centerLeft, child: label),
    );
    if (onTap == null || text == null) return cell;
    return Semantics(
      button: true,
      label: 'Użyj poprzedniego wyniku: $text',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: cell,
      ),
    );
  }
}
