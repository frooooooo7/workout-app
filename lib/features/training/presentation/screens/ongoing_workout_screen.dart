import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/training_session.dart';
import '../bloc/training_session_cubit.dart';
import '../widgets/ongoing_workout_footer.dart';
import '../widgets/ongoing_workout_header.dart';
import '../widgets/table_cell_input.dart';

class OngoingWorkoutArgs {
  const OngoingWorkoutArgs({this.initialSession, this.sessionCubit});

  final TrainingSession? initialSession;
  final TrainingSessionCubit? sessionCubit;
}

class OngoingWorkoutScreen extends StatefulWidget {
  const OngoingWorkoutScreen({super.key, this.args});

  final OngoingWorkoutArgs? args;

  @override
  State<OngoingWorkoutScreen> createState() => _OngoingWorkoutScreenState();
}

class _OngoingWorkoutScreenState extends State<OngoingWorkoutScreen> {
  Timer? _timer;
  Timer? _saveDebounce;
  Duration _elapsed = Duration.zero;
  TrainingSession? _draftSession;
  bool _hasUnsavedDraft = false;
  bool _allowPop = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final session = _session;
      if (session == null || !mounted) return;
      setState(() {
        _elapsed = DateTime.now().toUtc().difference(session.startedAt);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _saveDebounce?.cancel();
    super.dispose();
  }

  TrainingSession? get _session {
    return _draftSession ?? widget.args?.initialSession;
  }

  String get _elapsedLabel {
    final hours = _elapsed.inHours.toString().padLeft(2, '0');
    final minutes = (_elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    if (args == null) return const _MissingSessionScreen();

    final content = BlocBuilder<TrainingSessionCubit, TrainingSessionState>(
      builder: (context, state) {
        final sourceSession = state.activeSession ?? args.initialSession;
        if (sourceSession == null) return const _MissingSessionScreen();
        if (_draftSession == null || _draftSession!.id != sourceSession.id) {
          _draftSession = sourceSession;
        }
        final session = _draftSession!;

        return PopScope(
          canPop: _allowPop,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            await _flushDraft(context.read<TrainingSessionCubit>());
            if (!context.mounted) return;
            setState(() => _allowPop = true);
            context.pop(result);
          },
          child: Scaffold(
            backgroundColor: AppColors.background,
            body: SafeArea(
              child: Column(
                children: [
                  OngoingWorkoutHeader(
                    elapsed: _elapsedLabel,
                    onFinish: () => _finish(context, session),
                    onBack: () => _leaveWorkout(context),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                      itemCount: session.exercises.length,
                      itemBuilder: (context, index) {
                        return _SessionExerciseCard(
                          exerciseIndex: index,
                          exercise: session.exercises[index],
                          onSetChanged: (setIndex, set) =>
                              _updateSet(context, index, setIndex, set),
                        );
                      },
                    ),
                  ),
                  const OngoingWorkoutFooter(),
                ],
              ),
            ),
          ),
        );
      },
    );
    final sessionCubit = args.sessionCubit;
    if (sessionCubit != null) {
      return BlocProvider.value(value: sessionCubit, child: content);
    }
    return BlocProvider(
      create: (_) => TrainingSessionCubit(
        ServiceLocator.trainingSessionRepository,
        autoRefresh: false,
      ),
      child: content,
    );
  }

  Future<void> _finish(BuildContext context, TrainingSession session) async {
    final cubit = context.read<TrainingSessionCubit>();
    await _flushDraft(cubit);
    await cubit.finish(session.id);
    if (!context.mounted) return;
    setState(() => _allowPop = true);
    context.pop();
  }

  Future<void> _leaveWorkout(BuildContext context) async {
    final cubit = context.read<TrainingSessionCubit>();
    await _flushDraft(cubit);
    if (!context.mounted) return;
    setState(() => _allowPop = true);
    context.pop();
  }

  void _updateSet(
    BuildContext context,
    int exerciseIndex,
    int setIndex,
    TrainingSessionSet set,
  ) {
    final session = _draftSession;
    if (session == null) return;
    final exercises = List<TrainingSessionExercise>.from(session.exercises);
    final exercise = exercises[exerciseIndex];
    final sets = List<TrainingSessionSet>.from(exercise.sets);
    sets[setIndex] = set;
    exercises[exerciseIndex] = exercise.copyWith(sets: sets);
    setState(() {
      _draftSession = session.copyWith(exercises: exercises);
      _hasUnsavedDraft = true;
    });
    _scheduleDraftSave(context.read<TrainingSessionCubit>());
  }

  void _scheduleDraftSave(TrainingSessionCubit cubit) {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      unawaited(_flushDraft(cubit));
    });
  }

  Future<void> _flushDraft(TrainingSessionCubit cubit) async {
    _saveDebounce?.cancel();
    final draft = _draftSession;
    if (draft == null || !_hasUnsavedDraft) return;
    await cubit.save(draft);
    _hasUnsavedDraft = false;
  }
}

class _SessionExerciseCard extends StatelessWidget {
  const _SessionExerciseCard({
    required this.exerciseIndex,
    required this.exercise,
    required this.onSetChanged,
  });

  final int exerciseIndex;
  final TrainingSessionExercise exercise;
  final void Function(int setIndex, TrainingSessionSet set) onSetChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                  image: exercise.exerciseImageUrl != null
                      ? DecorationImage(
                          image: NetworkImage(exercise.exerciseImageUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: exercise.exerciseImageUrl == null
                    ? const Icon(
                        Icons.fitness_center,
                        color: AppColors.textMuted,
                        size: 22,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  exercise.exerciseName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Row(
            children: [
              SizedBox(width: 34, child: _HeaderText('SET')),
              SizedBox(width: 8),
              Expanded(child: _HeaderText('KG')),
              SizedBox(width: 8),
              Expanded(child: _HeaderText('POWT.')),
              SizedBox(width: 8),
              Expanded(child: _HeaderText('RIR')),
              SizedBox(width: 8),
              SizedBox(width: 44, child: _HeaderText('OK')),
            ],
          ),
          const SizedBox(height: 8),
          ...exercise.sets.asMap().entries.map((entry) {
            final setIndex = entry.key;
            final set = entry.value;
            final rowTextStyle = TextStyle(
              color: set.completed ? AppColors.textMuted : Colors.white,
              fontWeight: FontWeight.w700,
              decoration: set.completed
                  ? TextDecoration.lineThrough
                  : TextDecoration.none,
              decorationColor: AppColors.primaryVariant,
              decorationThickness: 2,
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: set.completed
                      ? AppColors.primary.withValues(alpha: 0.10)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: set.completed
                      ? Border.all(
                          color: AppColors.primary.withValues(alpha: 0.35),
                        )
                      : null,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 34,
                      child: Text(
                        '${setIndex + 1}',
                        textAlign: TextAlign.center,
                        style: rowTextStyle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TableCellInput(
                        value: set.actualWeight ?? '',
                        hint: set.plannedWeight ?? '',
                        onChanged: (value) => onSetChanged(
                          setIndex,
                          set.copyWith(
                            actualWeight: value,
                            clearActualWeight: value.trim().isEmpty,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TableCellInput(
                        value: set.actualReps ?? '',
                        hint: set.plannedReps,
                        onChanged: (value) => onSetChanged(
                          setIndex,
                          set.copyWith(
                            actualReps: value,
                            clearActualReps: value.trim().isEmpty,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TableCellInput(
                        value: set.actualRir ?? '',
                        hint: set.plannedRir?.isNotEmpty == true
                            ? set.plannedRir!
                            : '-',
                        onChanged: (value) => onSetChanged(
                          setIndex,
                          set.copyWith(
                            actualRir: value,
                            clearActualRir: value.trim().isEmpty,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 44,
                      child: Checkbox(
                        value: set.completed,
                        activeColor: AppColors.primary,
                        onChanged: (value) => onSetChanged(
                          setIndex,
                          set.copyWith(
                            completed: value ?? false,
                            completedAt: value == true
                                ? DateTime.now().toUtc()
                                : null,
                            clearCompletedAt: value != true,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  const _HeaderText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _MissingSessionScreen extends StatelessWidget {
  const _MissingSessionScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Text(
          'Brak aktywnej sesji',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
