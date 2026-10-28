import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/units/weight_unit.dart';
import '../../../../../core/utils/keyboard.dart';
import '../../../../library/presentation/screens/exercise_details_screen.dart';
import '../../../domain/models/training_session.dart';
import '../../../domain/repositories/previous_performance_repository.dart';
import '../../../domain/services/cardio_insights.dart' show formatPacePerKm;
import '../../../domain/services/live_workout_insights.dart';
import '../../../domain/services/stats/stats_sets.dart' show taggedMuscles;
import '../../../domain/services/training_session_detail_mapper.dart'
    show parseReps, parseWeightKg;
import '../../../domain/services/workout_edit.dart' show maxExerciseNoteLength;
import '../set_type_badge.dart';
import 'cardio_set_table.dart';
import 'cardio_stopwatch.dart';
import 'dashed_add_button.dart';
import 'exercise_stat_chips.dart';
import 'exercise_thumb.dart';
import 'record_burst.dart';
import 'session_set_row.dart';
import 'set_table_layout.dart';
import 'workout_accent.dart';
import 'workout_colors.dart';

/// Karta bieżącego ćwiczenia: miniatura, nazwa i partie, chipy „Ostatnio” /
/// „Rekord”, notatka, tabela serii i „Dodaj serię”.
///
/// Serie trzyma lokalnie (pisanie w polu nie przebudowuje całego ekranu),
/// a każdą zmianę oddaje przez [onSetChanged].
class SessionExerciseCard extends StatefulWidget {
  const SessionExerciseCard({
    super.key,
    required this.exerciseIndex,
    required this.exercise,
    required this.history,
    required this.showRirColumn,
    required this.showTempoColumn,
    required this.noteOpen,
    required this.onSetChanged,
    required this.onAddSet,
    required this.onRemoveSet,
    required this.onNoteChanged,
    required this.onRecord,
    this.embedded = false,
    this.focused = true,
    this.stopwatch,
  });

  final int exerciseIndex;
  final TrainingSessionExercise exercise;

  /// Poprzedni trening i rekord; `null`, dopóki się wczytują.
  final ExerciseHistoryInsights? history;
  final bool showRirColumn;
  final bool showTempoColumn;

  /// Notatka otwarta z menu ⋯ — pole dostaje fokus.
  final bool noteOpen;
  final void Function(int setIndex, TrainingSessionSet set) onSetChanged;
  final VoidCallback onAddSet;
  final void Function(int setIndex) onRemoveSet;
  final ValueChanged<String> onNoteChanged;

  /// Odhaczona seria pobiła rekord.
  final ValueChanged<RecordBurstData> onRecord;

  /// Część karty superserii — bez własnego tła i ramki.
  final bool embedded;

  /// Czy to ćwiczenie jest teraz na kolei (w superserii tylko jedno ma
  /// podświetloną serię).
  final bool focused;

  /// Stoper odcinków kardio (wspólny dla treningu).
  final CardioStopwatchController? stopwatch;

  @override
  State<SessionExerciseCard> createState() => _SessionExerciseCardState();
}

class _SessionExerciseCardState extends State<SessionExerciseCard> {
  late List<TrainingSessionSet> _sets;
  late final TextEditingController _noteController;
  final FocusNode _noteFocus = FocusNode();

  /// Notatka była w sesji od początku — pole widać bez otwierania z menu.
  late bool _hadNote;

  @override
  void initState() {
    super.initState();
    _sets = List<TrainingSessionSet>.from(widget.exercise.sets);
    _noteController = TextEditingController(text: widget.exercise.note ?? '');
    _hadNote = _noteController.text.trim().isNotEmpty;
  }

  @override
  void didUpdateWidget(covariant SessionExerciseCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exercise.id != widget.exercise.id ||
        widget.exercise.sets.length != _sets.length) {
      _sets = List<TrainingSessionSet>.from(widget.exercise.sets);
    }
    if (oldWidget.exercise.id != widget.exercise.id) {
      _noteController.text = widget.exercise.note ?? '';
      _hadNote = _noteController.text.trim().isNotEmpty;
    }
    if (widget.noteOpen && !oldWidget.noteOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _noteFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  ExerciseRecordBaseline? get _record => widget.history?.record;

  void _handleSetChanged(int setIndex, TrainingSessionSet set) {
    final stopwatch = widget.stopwatch;
    if (set.completed &&
        !_sets[setIndex].completed &&
        stopwatch?.setId == set.id) {
      // Odhaczony w trakcie pomiaru — czas ze stopera, chyba że wpisany.
      final measured = stopwatch!.stop();
      set = set.actualDurationSeconds == null
          ? set.copyWith(actualDurationSeconds: measured.inSeconds)
          : set;
    }
    final before = recordSetIndexes(_record, _sets);
    setState(() {
      _sets = List<TrainingSessionSet>.from(_sets);
      _sets[setIndex] = set;
    });
    widget.onSetChanged(setIndex, set);
    final after = recordSetIndexes(_record, _sets);
    if (after.contains(setIndex) && !before.contains(setIndex)) {
      _announceRecord(setIndex, set);
    }
  }

  void _announceRecord(int setIndex, TrainingSessionSet set) {
    final baseline = recordBaselineBefore(_record!, _sets, setIndex);
    final weight = parseWeightKg(set.actualWeight);
    final reps = parseReps(set.actualReps);
    final result = (weight ?? 0) > 0
        ? '${formatWeightWithUnit(weight!)}${reps == null ? '' : ' × $reps'}'
        : '$reps powt.';
    widget.onRecord(
      RecordBurstData(
        id: set.id,
        exerciseName: widget.exercise.exerciseName,
        result: result,
        improvement: baseline.improvementOf(weight, reps),
      ),
    );
  }

  /// Znaczek serii: rodzaj serii albo usunięcie (z „Cofnij” na ekranie).
  Future<void> _openSetOptions(int setIndex) async {
    hideKeyboard();
    final set = _sets[setIndex];
    final cardio = widget.exercise.tracking.tracksDuration;
    final label = setRowLabels(_sets.map((s) => s.setType))[setIndex];
    final title = set.setType == SetType.warmup
        ? 'Rozgrzewka'
        : cardio
        ? 'Odcinek $label'
        : 'Seria $label';
    final choice = await showSetOptionsSheet(
      context,
      title: title,
      current: set.setType,
      removeLabel: _sets.length > 1
          ? (cardio ? 'Usuń odcinek' : 'Usuń serię')
          : null,
    );
    if (choice == null || !mounted || setIndex >= _sets.length) return;
    if (_sets[setIndex].id != set.id) return;
    if (choice.remove) {
      _removeSet(setIndex);
      return;
    }
    final picked = choice.type;
    if (picked == null || picked == set.setType) return;
    _handleSetChanged(setIndex, set.copyWith(setType: picked));
  }

  /// Przepisuje ciężar i powtórzenia poprzedniego wyniku do serii.
  void _fillFromPrevious(int setIndex, TrainingSessionSet previous) {
    final weight = previous.actualWeight?.trim() ?? '';
    final reps = previous.actualReps?.trim() ?? '';
    _handleSetChanged(
      setIndex,
      _sets[setIndex].copyWith(
        actualWeight: weight.isEmpty ? null : weight,
        actualReps: reps.isEmpty ? null : reps,
      ),
    );
  }

  /// Stoper dla odcinka [setIndex]; „Zapisz” wpisuje zmierzony czas.
  void _startStopwatch(int setIndex) {
    final stopwatch = widget.stopwatch;
    if (stopwatch == null) return;
    final set = _sets[setIndex];
    stopwatch.start(
      set.id,
      from: Duration(seconds: set.actualDurationSeconds ?? 0),
      onSave: (measured) {
        if (!mounted) return;
        final index = _sets.indexWhere((s) => s.id == set.id);
        if (index == -1) return;
        _handleSetChanged(
          index,
          _sets[index].copyWith(actualDurationSeconds: measured.inSeconds),
        );
      },
    );
  }

  void _removeSet(int setIndex) {
    final stopwatch = widget.stopwatch;
    if (stopwatch?.setId == _sets[setIndex].id) stopwatch!.stop();
    setState(
      () => _sets = List<TrainingSessionSet>.from(_sets)..removeAt(setIndex),
    );
    widget.onRemoveSet(setIndex);
  }

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;
    final history = widget.history;
    final previous = history?.previousSets;
    final cardio = exercise.tracking.tracksDuration;
    final subtitle = cardio
        ? 'Kardio · ${exercise.tracking.label.toLowerCase()}'
        : taggedMuscles(exercise).map((m) => m.shortLabel).take(2).join(' · ');
    final bestPace = history?.bestPaceSecondsPerKm;

    final thumbSize = widget.embedded ? 44.0 : 56.0;
    return Container(
      padding: widget.embedded ? EdgeInsets.zero : const EdgeInsets.all(14),
      decoration: widget.embedded
          ? null
          : BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ExerciseThumb(
                imageUrl: exercise.exerciseImageUrl,
                size: thumbSize,
                radius: widget.embedded ? 12 : 14,
                cardio: cardio,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.exerciseName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _HistoryButton(
                key: ValueKey(
                  'session-exercise-details-${widget.exerciseIndex}',
                ),
                onTap: () => unawaited(
                  openExerciseDetailsFromSession(context, exercise),
                ),
              ),
            ],
          ),
          ExerciseStatChips(
            last: history?.lastResult(exercise),
            record: cardio
                ? (bestPace == null
                      ? null
                      : formatPacePerKm(bestPace, exercise.distanceUnit))
                : history?.record?.format(),
            recordLabel: cardio ? 'Tempo' : 'Rekord',
          ),
          if (widget.noteOpen || _hadNote) ...[
            const SizedBox(height: 10),
            _NoteField(
              key: ValueKey('exercise-note-field-${widget.exerciseIndex}'),
              controller: _noteController,
              focusNode: _noteFocus,
              onChanged: widget.onNoteChanged,
            ),
          ],
          const SizedBox(height: 14),
          if (cardio)
            CardioSetTable(
              exerciseIndex: widget.exerciseIndex,
              exercise: exercise,
              sets: _sets,
              previous: previous,
              focused: widget.focused,
              stopwatch: widget.stopwatch,
              onChanged: _handleSetChanged,
              onPickType: (i) => unawaited(_openSetOptions(i)),
              onRemove: _sets.length > 1 ? _removeSet : null,
              onStartStopwatch: widget.stopwatch == null
                  ? null
                  : _startStopwatch,
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final layout = SetTableLayout.of(
                  constraints.maxWidth,
                  hasPrevious: previous != null && previous.isNotEmpty,
                  showWeight: exercise.tracking.tracksWeight,
                  showRir: widget.showRirColumn,
                  showTempo: widget.showTempoColumn,
                );
                return _SetTable(
                  exerciseIndex: widget.exerciseIndex,
                  sets: _sets,
                  previous: previous,
                  earlier: history?.earlierSets ?? const [],
                  legs: isLegExercise(exercise.exerciseMuscles),
                  record: _record,
                  layout: layout,
                  focused: widget.focused,
                  onChanged: _handleSetChanged,
                  onPickType: (i) => unawaited(_openSetOptions(i)),
                  onFillPrevious: _fillFromPrevious,
                  onRemove: _sets.length > 1 ? _removeSet : null,
                );
              },
            ),
          const SizedBox(height: 10),
          DashedAddButton(
            key: const ValueKey('add-session-set-button'),
            label: cardio ? 'Dodaj odcinek' : 'Dodaj serię',
            onTap: widget.onAddSet,
          ),
          if (cardio) CardioTotalsBar(exercise: exercise, sets: _sets),
        ],
      ),
    );
  }
}

class _SetTable extends StatelessWidget {
  const _SetTable({
    required this.exerciseIndex,
    required this.sets,
    required this.previous,
    required this.earlier,
    required this.legs,
    required this.record,
    required this.layout,
    required this.focused,
    required this.onChanged,
    required this.onPickType,
    required this.onFillPrevious,
    required this.onRemove,
  });

  final int exerciseIndex;
  final List<TrainingSessionSet> sets;
  final List<TrainingSessionSet>? previous;

  /// Serie z wcześniejszych treningów (od najnowszego) — do progresji.
  final List<List<TrainingSessionSet>> earlier;
  final bool legs;
  final ExerciseRecordBaseline? record;
  final SetTableLayout layout;
  final bool focused;
  final void Function(int setIndex, TrainingSessionSet set) onChanged;
  final ValueChanged<int> onPickType;
  final void Function(int setIndex, TrainingSessionSet previous) onFillPrevious;
  final ValueChanged<int>? onRemove;

  @override
  Widget build(BuildContext context) {
    final labels = setRowLabels(sets.map((set) => set.setType));
    final activeIndex = focused ? sets.indexWhere((set) => !set.completed) : -1;
    final records = recordSetIndexes(record, sets);
    final previous = this.previous;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SetTableHeader(layout: layout),
        for (var i = 0; i < sets.length; i++)
          Builder(
            key: ValueKey(sets[i].id),
            builder: (context) {
              final previousSet = previous == null || previous.isEmpty
                  ? null
                  : previousSetFor(sets, i, previous);
              final previousText = formatPreviousSet(previousSet);
              return SessionSetRow(
                exerciseIndex: exerciseIndex,
                setIndex: i,
                label: labels[i],
                set: sets[i],
                layout: layout,
                active: i == activeIndex,
                record: records.contains(i),
                previousText: previousText,
                onFillPrevious: previousSet == null || previousText == null
                    ? null
                    : () => onFillPrevious(i, previousSet),
                progression: i == activeIndex
                    ? progressionHintFor(
                        sets[i],
                        previousSet,
                        settings: WorkoutAccentScope.progressionOf(context),
                        earlier: [
                          for (final sessionSets in earlier)
                            previousSetFor(sets, i, sessionSets),
                        ],
                        legs: legs,
                      )
                    : null,
                onChanged: (set) => onChanged(i, set),
                onPickType: () => onPickType(i),
                onRemove: onRemove == null ? null : () => onRemove!(i),
              );
            },
          ),
      ],
    );
  }
}

class _HistoryButton extends StatelessWidget {
  const _HistoryButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: WorkoutColors.chip,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: const SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            Icons.show_chart_rounded,
            color: AppColors.iconOnTile,
            size: 20,
            semanticLabel: 'Historia ćwiczenia',
          ),
        ),
      ),
    );
  }
}

class _NoteField extends StatelessWidget {
  const _NoteField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    // Długa notatka zawija się w kilka linii, ale Enter to „Gotowe” —
    // klawiatura się chowa, a notatka jest już zapisana (onChanged).
    final field = TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      onSubmitted: (_) => focusNode.unfocus(),
      onTapOutside: hideKeyboardOnTapOutside,
      textInputAction: TextInputAction.done,
      keyboardType: TextInputType.text,
      textAlignVertical: TextAlignVertical.center,
      maxLength: maxExerciseNoteLength,
      minLines: 1,
      maxLines: 4,
      textCapitalization: TextCapitalization.sentences,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        hintText: 'Notatka do ćwiczenia (np. ustawienie ławki)',
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        prefixIcon: const Icon(
          Icons.sticky_note_2_outlined,
          size: 16,
          color: AppColors.textSecondary,
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 36),
        counterText: '',
        isDense: true,
        filled: true,
        fillColor: WorkoutColors.chip,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        suffixIconConstraints: const BoxConstraints(minWidth: 44),
        suffixIcon: ListenableBuilder(
          listenable: focusNode,
          builder: (context, _) => focusNode.hasFocus
              ? IconButton(
                  key: const ValueKey('exercise-note-done'),
                  tooltip: 'Zapisz notatkę',
                  onPressed: focusNode.unfocus,
                  icon: const Icon(
                    Icons.check_rounded,
                    size: 20,
                    color: AppColors.success,
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
    return field;
  }
}
