import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../domain/models/training_session.dart';
import '../../../domain/services/cardio_insights.dart';
import '../../../domain/repositories/previous_performance_repository.dart'
    show previousSetFor;
import '../table_cell_input.dart';
import 'cardio_stopwatch.dart';
import 'session_set_badge.dart';
import 'set_check_button.dart';
import 'workout_accent.dart';
import 'workout_colors.dart';

/// Tabela odcinków kardio: `#  CZAS  KM  TEMPO  ✓` (bez dystansu — sam
/// czas). Aktywny odcinek ma przy czasie przycisk stopera, a mierzony
/// odcinek pokazuje bieżący czas na turkusowo.
class CardioSetTable extends StatelessWidget {
  const CardioSetTable({
    super.key,
    required this.exerciseIndex,
    required this.exercise,
    required this.sets,
    required this.previous,
    required this.focused,
    required this.stopwatch,
    required this.onChanged,
    required this.onPickType,
    required this.onRemove,
    required this.onStartStopwatch,
  });

  final int exerciseIndex;
  final TrainingSessionExercise exercise;
  final List<TrainingSessionSet> sets;
  final List<TrainingSessionSet>? previous;
  final bool focused;
  final CardioStopwatchController? stopwatch;
  final void Function(int setIndex, TrainingSessionSet set) onChanged;
  final ValueChanged<int> onPickType;
  final ValueChanged<int>? onRemove;
  final ValueChanged<int>? onStartStopwatch;

  @override
  Widget build(BuildContext context) {
    final labels = setRowLabels(sets.map((set) => set.setType));
    final activeIndex = focused ? sets.indexWhere((set) => !set.completed) : -1;
    final previous = this.previous;
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = CardioTableLayout.of(
          constraints.maxWidth,
          withDistance: exercise.tracking.tracksDistance,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(layout: layout, unit: exercise.distanceUnit),
            for (var i = 0; i < sets.length; i++)
              CardioSetRow(
                key: ValueKey(sets[i].id),
                exerciseIndex: exerciseIndex,
                setIndex: i,
                label: labels[i],
                set: sets[i],
                previousSet: previous == null || previous.isEmpty
                    ? null
                    : previousSetFor(sets, i, previous),
                layout: layout,
                unit: exercise.distanceUnit,
                active: i == activeIndex,
                stopwatch: stopwatch,
                onChanged: (set) => onChanged(i, set),
                onPickType: () => onPickType(i),
                onRemove: onRemove == null ? null : () => onRemove!(i),
                onStartStopwatch: onStartStopwatch == null
                    ? null
                    : () => onStartStopwatch!(i),
              ),
          ],
        );
      },
    );
  }
}

/// Szerokości kolumn: czas bierze resztę miejsca (z dystansem) albo ma
/// stałą szerokość (sam czas).
class CardioTableLayout {
  const CardioTableLayout._({
    required this.timeWidth,
    required this.distanceWidth,
    required this.paceWidth,
  });

  factory CardioTableLayout.of(double width, {required bool withDistance}) {
    final available =
        width -
        _rowPadding * 2 -
        badgeWidth -
        checkWidth -
        gap * (withDistance ? 4 : 2);
    if (!withDistance) {
      return CardioTableLayout._(
        timeWidth: available.clamp(0.0, 150.0),
        distanceWidth: 0,
        paceWidth: 0,
      );
    }
    return CardioTableLayout._(
      timeWidth: (available - _distance - _pace).clamp(0.0, double.infinity),
      distanceWidth: _distance,
      paceWidth: _pace,
    );
  }

  static const badgeWidth = 30.0;
  static const checkWidth = 44.0;
  static const gap = 8.0;
  static const _rowPadding = 6.0;
  static const _distance = 72.0;
  static const _pace = 52.0;

  final double timeWidth;

  /// 0 — ćwiczenie bez dystansu.
  final double distanceWidth;
  final double paceWidth;

  bool get withDistance => distanceWidth > 0;
}

class _Header extends StatelessWidget {
  const _Header({required this.layout, required this.unit});

  final CardioTableLayout layout;
  final DistanceUnit unit;

  @override
  Widget build(BuildContext context) {
    Widget cell(String text, double width, {bool center = true}) => SizedBox(
      width: width,
      child: Text(
        text,
        maxLines: 1,
        textAlign: center ? TextAlign.center : TextAlign.left,
        style: _style,
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: CardioTableLayout._rowPadding,
      ),
      child: Row(
        children: [
          cell('#', CardioTableLayout.badgeWidth),
          const SizedBox(width: CardioTableLayout.gap),
          cell('CZAS', layout.timeWidth, center: false),
          if (layout.withDistance) ...[
            const SizedBox(width: CardioTableLayout.gap),
            cell(unit.label.toUpperCase(), layout.distanceWidth),
            const SizedBox(width: CardioTableLayout.gap),
            cell('TEMPO', layout.paceWidth),
          ],
          const Spacer(),
          const SizedBox(width: CardioTableLayout.checkWidth),
        ],
      ),
    );
  }

  static const _style = TextStyle(
    color: WorkoutColors.textFaint,
    fontSize: 10.5,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.7,
  );
}

/// Odcinek kardio. Zrobiony zielenieje, aktywny ma obwódkę w kolorze
/// akcentu. Znaczek odcinka otwiera arkusz z rodzajem i usuwaniem.
class CardioSetRow extends StatelessWidget {
  const CardioSetRow({
    super.key,
    required this.exerciseIndex,
    required this.setIndex,
    required this.label,
    required this.set,
    required this.layout,
    required this.unit,
    required this.active,
    required this.onChanged,
    required this.onPickType,
    this.previousSet,
    this.stopwatch,
    this.onRemove,
    this.onStartStopwatch,
  });

  final int exerciseIndex;
  final int setIndex;
  final String label;
  final TrainingSessionSet set;

  /// Ten odcinek z poprzedniego treningu — podpowiedź w pustych polach.
  final TrainingSessionSet? previousSet;
  final CardioTableLayout layout;
  final DistanceUnit unit;
  final bool active;
  final CardioStopwatchController? stopwatch;
  final ValueChanged<TrainingSessionSet> onChanged;
  final VoidCallback onPickType;
  final VoidCallback? onRemove;
  final VoidCallback? onStartStopwatch;

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
    final look = _look(completed: completed, highlighted: highlighted);
    final pace = unit.pace(
      seconds: set.actualDurationSeconds,
      meters: set.actualDistanceM,
    );

    final row = AnimatedContainer(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      height: highlighted ? 56 : 48,
      padding: EdgeInsets.symmetric(
        horizontal: CardioTableLayout._rowPadding - (highlighted ? 1.5 : 0),
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
            width: CardioTableLayout.badgeWidth,
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
          const SizedBox(width: CardioTableLayout.gap),
          SizedBox(
            width: layout.timeWidth,
            child: _TimeCell(
              key: ValueKey('cardio-time-$exerciseIndex-$setIndex'),
              set: set,
              previous: previousSet,
              look: look,
              showStopwatchButton: highlighted && onStartStopwatch != null,
              stopwatch: stopwatch,
              onStartStopwatch: onStartStopwatch,
              onChanged: onChanged,
            ),
          ),
          if (layout.withDistance) ...[
            const SizedBox(width: CardioTableLayout.gap),
            SizedBox(
              width: layout.distanceWidth,
              child: DistanceCellInput(
                key: ValueKey('cardio-distance-$exerciseIndex-$setIndex'),
                meters: set.actualDistanceM,
                hintMeters:
                    set.plannedDistanceM ?? previousSet?.actualDistanceM,
                unit: unit,
                look: look,
                onChanged: (meters) => onChanged(
                  set.copyWith(
                    actualDistanceM: meters,
                    clearActualDistance: meters == null,
                  ),
                ),
              ),
            ),
            const SizedBox(width: CardioTableLayout.gap),
            SizedBox(
              width: layout.paceWidth,
              child: Text(
                pace ?? '–',
                key: ValueKey('cardio-pace-$exerciseIndex-$setIndex'),
                textAlign: TextAlign.center,
                maxLines: 1,
                style: AppTextStyles.number(
                  size: 15,
                  color: pace == null
                      ? AppColors.textMuted
                      : WorkoutColors.textSoft,
                ),
              ),
            ),
          ],
          const Spacer(),
          SetCheckButton(
            key: ValueKey('session-set-check-$exerciseIndex-$setIndex'),
            completed: completed,
            active: highlighted,
            semanticLabel: set.setType == SetType.warmup
                ? 'Rozgrzewka'
                : 'Odcinek $label',
            onChanged: _toggle,
          ),
        ],
      ),
    );

    final content = Padding(padding: const EdgeInsets.only(top: 6), child: row);
    final removable = onRemove;
    if (removable == null) return content;
    return Semantics(
      customSemanticsActions: {
        const CustomSemanticsAction(label: 'Usuń odcinek'): removable,
      },
      child: content,
    );
  }

  TableCellInputLook _look({
    required bool completed,
    required bool highlighted,
  }) {
    final size = highlighted ? 21.0 : 20.0;
    final textColor = completed && set.setType == SetType.warmup
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

/// Czas odcinka: pole do wpisania, na aktywnym odcinku z przyciskiem
/// stopera, a w trakcie pomiaru — bieżący czas na turkusowo.
class _TimeCell extends StatelessWidget {
  const _TimeCell({
    super.key,
    required this.set,
    required this.previous,
    required this.look,
    required this.showStopwatchButton,
    required this.stopwatch,
    required this.onStartStopwatch,
    required this.onChanged,
  });

  final TrainingSessionSet set;
  final TrainingSessionSet? previous;
  final TableCellInputLook look;
  final bool showStopwatchButton;
  final CardioStopwatchController? stopwatch;
  final VoidCallback? onStartStopwatch;
  final ValueChanged<TrainingSessionSet> onChanged;

  @override
  Widget build(BuildContext context) {
    final controller = stopwatch;
    if (controller == null) return _field();
    // Start i stop stopera przełączają widok pola; sekundy słucha tylko
    // tekst w środku.
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.setId == set.id) {
          return _LiveTime(elapsed: controller.elapsed);
        }
        return _field();
      },
    );
  }

  Widget _field() {
    final input = DurationCellInput(
      seconds: set.actualDurationSeconds,
      hintSeconds:
          set.plannedDurationSeconds ?? previous?.actualDurationSeconds,
      look: look,
      onChanged: (seconds) => onChanged(
        set.copyWith(
          actualDurationSeconds: seconds,
          clearActualDuration: seconds == null,
        ),
      ),
    );
    if (!showStopwatchButton) return input;
    return Row(
      children: [
        _StopwatchButton(onTap: onStartStopwatch!),
        const SizedBox(width: 6),
        Expanded(child: input),
      ],
    );
  }
}

class _StopwatchButton extends StatelessWidget {
  const _StopwatchButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: stopwatchColor.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(11),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const Key('cardio-stopwatch-start'),
        onTap: onTap,
        child: const SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            Icons.timer_outlined,
            size: 20,
            color: stopwatchColor,
            semanticLabel: 'Włącz stoper',
          ),
        ),
      ),
    );
  }
}

class _LiveTime extends StatelessWidget {
  const _LiveTime({required this.elapsed});

  final ValueNotifier<Duration> elapsed;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('cardio-live-time'),
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: stopwatchColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: stopwatchColor.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, size: 18, color: stopwatchColor),
          const SizedBox(width: 8),
          Expanded(
            child: ValueListenableBuilder<Duration>(
              valueListenable: elapsed,
              builder: (context, value, _) => Text(
                formatSetDuration(value.inSeconds),
                maxLines: 1,
                style: AppTextStyles.number(size: 20, color: stopwatchColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// „Razem dziś  2,7 km · 17:47 · 6:35 /km” pod tabelą odcinków.
class CardioTotalsBar extends StatelessWidget {
  const CardioTotalsBar({
    super.key,
    required this.exercise,
    required this.sets,
  });

  final TrainingSessionExercise exercise;
  final List<TrainingSessionSet> sets;

  @override
  Widget build(BuildContext context) {
    final text = formatCardioTotals(
      cardioTotals(sets, completedOnly: false),
      exercise.tracking,
      exercise.distanceUnit,
      withPace: true,
    );
    if (text == null) return const SizedBox.shrink();
    return Container(
      key: const Key('cardio-totals'),
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: WorkoutColors.chip,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Text(
            'Razem dziś',
            style: TextStyle(
              color: WorkoutColors.textSoft,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.number(
                size: 16,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
