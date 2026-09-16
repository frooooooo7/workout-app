import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../library/domain/models/exercise.dart';
import '../../../library/presentation/screens/pick_exercise_screen.dart';
import '../../domain/models/training_session.dart';
import '../../domain/repositories/training_session_repository.dart';
import '../bloc/edit_workout_cubit.dart';
import '../widgets/table_cell_input.dart';

/// Edycja zakończonego treningu (`/app/training/history/:sessionId/edit`).
/// Zapis działa offline; zwraca `true` przez `Navigator.pop`, gdy zapisano.
class EditWorkoutScreen extends StatelessWidget {
  const EditWorkoutScreen({
    super.key,
    required this.sessionId,
    this.repository,
    this.pickExercise,
    this.clock,
    this.onSaved,
  });

  final String sessionId;

  /// Test seam; domyślnie [ServiceLocator.trainingSessionRepository].
  final TrainingSessionRepository? repository;

  /// Test seam dla wyboru ćwiczenia; domyślnie [PickExerciseScreen].
  final Future<Exercise?> Function(BuildContext context)? pickExercise;
  final DateTime Function()? clock;

  /// Test seam; domyślnie odświeża historię, statystyki, profil i feed.
  final VoidCallback? onSaved;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => EditWorkoutCubit(
        repository ?? ServiceLocator.trainingSessionRepository,
        sessionId: sessionId,
        clock: clock,
      )..load(),
      child: _EditWorkoutView(pickExercise: pickExercise, onSaved: onSaved),
    );
  }
}

class _EditWorkoutView extends StatelessWidget {
  const _EditWorkoutView({this.pickExercise, this.onSaved});

  final Future<Exercise?> Function(BuildContext context)? pickExercise;
  final VoidCallback? onSaved;

  Future<void> _save(BuildContext context) async {
    final cubit = context.read<EditWorkoutCubit>();
    FocusScope.of(context).unfocus();
    final saved = await cubit.save();
    if (saved == null || !context.mounted) return;
    final notify = onSaved;
    if (notify != null) {
      notify();
    } else {
      ServiceLocator.notifyTrainingSessionsChanged();
      unawaited(() async {
        await ServiceLocator.flushTrainingSessionSync();
        ServiceLocator.requestProfileRefresh();
        ServiceLocator.requestFeedRefresh();
      }());
    }
    Navigator.of(context).pop(true);
  }

  Future<bool> _confirmDiscard(BuildContext context) async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Odrzucić zmiany?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Niezapisane zmiany w treningu zostaną utracone.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Wróć do edycji',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Odrzuć',
              style: TextStyle(color: AppColors.strengthWeak),
            ),
          ),
        ],
      ),
    );
    return discard == true;
  }

  Future<void> _addExercise(BuildContext context) async {
    final cubit = context.read<EditWorkoutCubit>();
    final picked =
        await (pickExercise?.call(context) ??
            Navigator.of(context).push<Exercise>(
              MaterialPageRoute(builder: (_) => const PickExerciseScreen()),
            ));
    if (picked == null) return;
    cubit.addExercise(
      TrainingSessionExercise(
        exerciseId: picked.id,
        exerciseName: picked.name,
        exerciseMuscles: picked.muscles.map((m) => m.name).toList(),
        exerciseCategory: picked.category.name,
        exerciseImageUrl: picked.imageUrl,
        sets: [TrainingSessionSet()],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EditWorkoutCubit, EditWorkoutState>(
      builder: (context, state) {
        final canLeave = !state.dirty || state.status == EditWorkoutStatus.saved;
        return PopScope(
          canPop: canLeave,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            if (await _confirmDiscard(context) && context.mounted) {
              Navigator.of(context).pop(false);
            }
          },
          child: Scaffold(
            backgroundColor: AppColors.background,
            body: SafeArea(
              child: Column(
                children: [
                  AppHeader(
                    title: 'Edytuj trening',
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(child: _buildBody(context, state)),
                  if (state.draft != null) _buildFooter(context, state),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, EditWorkoutState state) {
    final cubit = context.read<EditWorkoutCubit>();
    if (state.status == EditWorkoutStatus.loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    final draft = state.draft;
    if (draft == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                state.error ?? 'Nie udało się wczytać treningu.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: cubit.load,
                child: const Text('Spróbuj ponownie'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _Section(
          children: [
            const _FieldLabel('Nazwa treningu'),
            _TextField(
              fieldKey: const ValueKey('edit-workout-name'),
              initialValue: draft.name,
              hint: 'np. Push A',
              onChanged: cubit.setName,
            ),
            const SizedBox(height: 14),
            const _FieldLabel('Notatka'),
            _TextField(
              fieldKey: const ValueKey('edit-workout-note'),
              initialValue: draft.note,
              hint: 'Jak poszło?',
              maxLines: 3,
              onChanged: cubit.setNote,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _Section(
          children: [
            const _FieldLabel('Początek'),
            Row(
              children: [
                Expanded(
                  child: _PickerButton(
                    key: const ValueKey('edit-workout-date'),
                    icon: Icons.calendar_today_rounded,
                    label: _formatDate(draft.startedAt),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: draft.startedAt,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) cubit.setStartDate(picked);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PickerButton(
                    key: const ValueKey('edit-workout-time'),
                    icon: Icons.schedule_rounded,
                    label: _formatTime(draft.startedAt),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(draft.startedAt),
                      );
                      if (picked != null) {
                        cubit.setStartTime(picked.hour, picked.minute);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const _FieldLabel('Czas trwania (minuty)'),
            _TextField(
              fieldKey: const ValueKey('edit-workout-duration'),
              initialValue: draft.durationMinutes,
              hint: '60',
              keyboardType: TextInputType.number,
              onChanged: cubit.setDurationMinutes,
            ),
          ],
        ),
        const SizedBox(height: 22),
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            'Ćwiczenia',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        for (var i = 0; i < draft.exercises.length; i++)
          _ExerciseEditor(
            key: ValueKey('edit-exercise-${draft.exercises[i].id}'),
            exerciseIndex: i,
            exercise: draft.exercises[i],
          ),
        OutlinedButton.icon(
          key: const ValueKey('edit-workout-add-exercise'),
          onPressed: () => _addExercise(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Dodaj ćwiczenie'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primaryVariant,
            side: const BorderSide(color: AppColors.border),
            minimumSize: const Size.fromHeight(46),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context, EditWorkoutState state) {
    final saving = state.status == EditWorkoutStatus.saving;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.error != null) ...[
            Text(
              state.error!,
              key: const ValueKey('edit-workout-error'),
              style: const TextStyle(
                color: AppColors.strengthWeak,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
          ],
          SizedBox(
            height: 48,
            child: ElevatedButton(
              key: const ValueKey('edit-workout-save'),
              onPressed: saving ? null : () => _save(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Zapisz zmiany'),
            ),
          ),
        ],
      ),
    );
  }

  static String _two(int value) => value.toString().padLeft(2, '0');

  static String _formatDate(DateTime value) =>
      '${_two(value.day)}.${_two(value.month)}.${value.year}';

  static String _formatTime(DateTime value) =>
      '${_two(value.hour)}:${_two(value.minute)}';
}

class _ExerciseEditor extends StatelessWidget {
  const _ExerciseEditor({
    super.key,
    required this.exerciseIndex,
    required this.exercise,
  });

  final int exerciseIndex;
  final TrainingSessionExercise exercise;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EditWorkoutCubit>();
    const headerStyle = TextStyle(
      color: AppColors.textMuted,
      fontSize: 11,
      fontWeight: FontWeight.w700,
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  exercise.exerciseName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                key: ValueKey('edit-exercise-remove-$exerciseIndex'),
                tooltip: 'Usuń ćwiczenie',
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.strengthWeak,
                  size: 20,
                ),
                onPressed: () => cubit.removeExercise(exerciseIndex),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(right: 6, bottom: 6),
            child: Row(
              children: [
                SizedBox(width: 34, child: Text('SERIA', style: headerStyle)),
                SizedBox(width: 6),
                Expanded(
                  flex: 3,
                  child: Center(child: Text('KG', style: headerStyle)),
                ),
                SizedBox(width: 6),
                Expanded(
                  flex: 3,
                  child: Center(child: Text('POWT.', style: headerStyle)),
                ),
                SizedBox(width: 6),
                Expanded(
                  flex: 2,
                  child: Center(child: Text('RIR', style: headerStyle)),
                ),
                SizedBox(width: 80),
              ],
            ),
          ),
          for (var s = 0; s < exercise.sets.length; s++)
            Padding(
              key: ValueKey('edit-set-${exercise.sets[s].id}'),
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 34,
                    child: Text(
                      '${s + 1}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 3,
                    child: TableCellInput(
                      key: ValueKey('edit-set-$exerciseIndex-$s-weight'),
                      value: exercise.sets[s].actualWeight ?? '',
                      hint: exercise.sets[s].plannedWeight ?? '—',
                      onChanged: (v) => cubit.setWeight(exerciseIndex, s, v),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 3,
                    child: TableCellInput(
                      key: ValueKey('edit-set-$exerciseIndex-$s-reps'),
                      value: exercise.sets[s].actualReps ?? '',
                      hint: exercise.sets[s].plannedReps,
                      keyboardType: TextInputType.number,
                      onChanged: (v) => cubit.setReps(exerciseIndex, s, v),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 2,
                    child: TableCellInput(
                      key: ValueKey('edit-set-$exerciseIndex-$s-rir'),
                      value: exercise.sets[s].actualRir ?? '',
                      hint: exercise.sets[s].plannedRir ?? '—',
                      keyboardType: TextInputType.number,
                      onChanged: (v) => cubit.setRir(exerciseIndex, s, v),
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: IconButton(
                      key: ValueKey('edit-set-$exerciseIndex-$s-completed'),
                      tooltip: exercise.sets[s].completed
                          ? 'Oznacz jako nieukończoną'
                          : 'Oznacz jako ukończoną',
                      icon: Icon(
                        exercise.sets[s].completed
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: exercise.sets[s].completed
                            ? AppColors.success
                            : AppColors.textMuted,
                        size: 22,
                      ),
                      onPressed: () => cubit.toggleCompleted(exerciseIndex, s),
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: IconButton(
                      key: ValueKey('edit-set-$exerciseIndex-$s-remove'),
                      tooltip: 'Usuń serię',
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.textMuted,
                        size: 20,
                      ),
                      onPressed: () => cubit.removeSet(exerciseIndex, s),
                    ),
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: ValueKey('edit-exercise-add-set-$exerciseIndex'),
              onPressed: () => cubit.addSet(exerciseIndex),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Dodaj serię'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Pole tekstowe z własnym kontrolerem — przebudowa formularza nie może
/// przesuwać kursora ani gubić znaków.
class _TextField extends StatefulWidget {
  const _TextField({
    required this.fieldKey,
    required this.initialValue,
    required this.onChanged,
    this.hint,
    this.maxLines = 1,
    this.keyboardType,
  });

  final Key fieldKey;
  final String initialValue;
  final ValueChanged<String> onChanged;
  final String? hint;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  State<_TextField> createState() => _TextFieldState();
}

class _TextFieldState extends State<_TextField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: widget.fieldKey,
      controller: _controller,
      onChanged: widget.onChanged,
      maxLines: widget.maxLines,
      keyboardType: widget.keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: const TextStyle(color: AppColors.textMuted),
        isDense: true,
        filled: true,
        fillColor: AppColors.surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _PickerButton extends StatelessWidget {
  const _PickerButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceVariant,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Icon(icon, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
