import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../library/domain/models/exercise.dart';
import '../../../library/presentation/screens/pick_exercise_screen.dart';
import '../../domain/models/training_session.dart';
import '../bloc/training_session_cubit.dart';
import '../widgets/ongoing_workout_footer.dart';
import '../widgets/ongoing_workout_header.dart';
import '../widgets/table_cell_input.dart';

class OngoingWorkoutArgs {
  const OngoingWorkoutArgs({
    this.initialSession,
    this.sessionCubit,
    this.pickExercise,
  });

  final TrainingSession? initialSession;
  final TrainingSessionCubit? sessionCubit;
  final Future<Exercise?> Function(BuildContext context)? pickExercise;
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
  Timer? _restTimer;
  final PageController _exercisePageController = PageController();
  Duration _elapsed = Duration.zero;
  Duration _restRemaining = Duration.zero;
  TrainingSession? _draftSession;
  final Set<String> _userEnabledRirColumns = {};
  final Set<String> _userEnabledTempoColumns = {};
  final Set<String> _userHiddenRirColumns = {};
  final Set<String> _userHiddenTempoColumns = {};
  int _currentExerciseIndex = 0;
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
    _restTimer?.cancel();
    _exercisePageController.dispose();
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

  bool get _restActive => _restTimer?.isActive == true;

  String get _restTimeLabel {
    final minutes = _restRemaining.inMinutes.toString().padLeft(2, '0');
    final seconds = (_restRemaining.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
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
          _userEnabledRirColumns.clear();
          _userEnabledTempoColumns.clear();
          _userHiddenRirColumns.clear();
          _userHiddenTempoColumns.clear();
          _currentExerciseIndex = 0;
        }
        final session = _draftSession!;
        final exerciseCount = session.exercises.length;
        if (exerciseCount == 0) return const _MissingSessionScreen();
        if (exerciseCount > 0 && _currentExerciseIndex >= exerciseCount) {
          _currentExerciseIndex = exerciseCount - 1;
        }

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
                  _ExerciseProgressBar(
                    currentIndex: _currentExerciseIndex,
                    exerciseCount: exerciseCount,
                    exerciseName:
                        session.exercises[_currentExerciseIndex].exerciseName,
                    onPrevious: _currentExerciseIndex > 0
                        ? () => _goToExercise(_currentExerciseIndex - 1)
                        : null,
                    onNext: _currentExerciseIndex < exerciseCount - 1
                        ? () => _goToExercise(_currentExerciseIndex + 1)
                        : null,
                    onShowList: () => _showExercisePicker(context, session),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _exercisePageController,
                      itemCount: session.exercises.length,
                      onPageChanged: (index) {
                        setState(() => _currentExerciseIndex = index);
                      },
                      itemBuilder: (context, index) {
                        return SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                          child: _SessionExerciseCard(
                            exerciseIndex: index,
                            exercise: session.exercises[index],
                            showRirColumn: _shouldShowRirColumn(
                              session.exercises[index],
                            ),
                            showTempoColumn: _shouldShowTempoColumn(
                              session.exercises[index],
                            ),
                            onShowRirColumn: () => setState(() {
                              _userHiddenRirColumns.remove(
                                session.exercises[index].id,
                              );
                              _userEnabledRirColumns.add(
                                session.exercises[index].id,
                              );
                            }),
                            onShowTempoColumn: () => setState(() {
                              _userHiddenTempoColumns.remove(
                                session.exercises[index].id,
                              );
                              _userEnabledTempoColumns.add(
                                session.exercises[index].id,
                              );
                            }),
                            onHideRirColumn: () => setState(() {
                              _userEnabledRirColumns.remove(
                                session.exercises[index].id,
                              );
                              _userHiddenRirColumns.add(
                                session.exercises[index].id,
                              );
                            }),
                            onHideTempoColumn: () => setState(() {
                              _userEnabledTempoColumns.remove(
                                session.exercises[index].id,
                              );
                              _userHiddenTempoColumns.add(
                                session.exercises[index].id,
                              );
                            }),
                            onSetChanged: (setIndex, set) =>
                                _updateSet(context, index, setIndex, set),
                            onAddSet: () => _addSet(context, index),
                            onRemoveSet: (setIndex) =>
                                _removeSet(context, index, setIndex),
                          ),
                        );
                      },
                    ),
                  ),
                  if (_restActive)
                    _RestTimerBanner(
                      remaining: _restTimeLabel,
                      onStop: _stopRestTimer,
                    ),
                  OngoingWorkoutFooter(
                    restLabel: 'Odpoczynek',
                    restActive: _restActive,
                    onRestTap: _toggleRestTimer,
                    onAddExerciseTap: () => _addExerciseToSession(context),
                  ),
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

  Future<void> _addExerciseToSession(BuildContext context) async {
    final session = _draftSession;
    if (session == null) return;

    final picked =
        await (widget.args?.pickExercise?.call(context) ??
            Navigator.of(context).push<Exercise>(
              MaterialPageRoute(builder: (_) => const PickExerciseScreen()),
            ));
    if (picked == null || !context.mounted) return;

    final exercises = List<TrainingSessionExercise>.from(session.exercises)
      ..add(
        TrainingSessionExercise(
          exerciseId: picked.id,
          exerciseName: picked.name,
          exerciseMuscles: picked.muscles.map((muscle) => muscle.name).toList(),
          exerciseCategory: picked.category.name,
          exerciseImageUrl: picked.imageUrl,
          sets: [TrainingSessionSet()],
        ),
      );
    final nextIndex = exercises.length - 1;
    setState(() {
      _draftSession = session.copyWith(exercises: exercises);
      _currentExerciseIndex = nextIndex;
      _hasUnsavedDraft = true;
    });
    _scheduleDraftSave(context.read<TrainingSessionCubit>());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_exercisePageController.hasClients) return;
      _exercisePageController.jumpToPage(nextIndex);
      if (_currentExerciseIndex != nextIndex) {
        setState(() => _currentExerciseIndex = nextIndex);
      }
    });
  }

  void _toggleRestTimer() {
    if (_restActive) {
      _stopRestTimer();
    } else {
      _startRestTimer();
    }
  }

  void _startRestTimer() {
    _restTimer?.cancel();
    setState(() => _restRemaining = const Duration(seconds: 90));
    _restTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_restRemaining <= const Duration(seconds: 1)) {
        _stopRestTimer();
        return;
      }
      setState(() {
        _restRemaining -= const Duration(seconds: 1);
      });
    });
  }

  void _stopRestTimer() {
    _restTimer?.cancel();
    if (!mounted) return;
    setState(() => _restRemaining = Duration.zero);
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

  void _addSet(BuildContext context, int exerciseIndex) {
    final session = _draftSession;
    if (session == null) return;
    final exercises = List<TrainingSessionExercise>.from(session.exercises);
    final exercise = exercises[exerciseIndex];
    final sets = List<TrainingSessionSet>.from(exercise.sets);
    final previousSet = sets.isNotEmpty ? sets.last : null;
    sets.add(
      TrainingSessionSet(
        plannedWeight: previousSet?.plannedWeight,
        plannedReps: previousSet?.plannedReps ?? '',
        plannedRir: previousSet?.plannedRir,
        plannedTempo: previousSet?.plannedTempo,
        actualWeight: previousSet?.actualWeight ?? previousSet?.plannedWeight,
        actualReps: previousSet?.actualReps ?? previousSet?.plannedReps,
        actualRir: previousSet?.actualRir ?? previousSet?.plannedRir,
        actualTempo: previousSet?.actualTempo ?? previousSet?.plannedTempo,
      ),
    );
    exercises[exerciseIndex] = exercise.copyWith(sets: sets);
    setState(() {
      _draftSession = session.copyWith(exercises: exercises);
      _hasUnsavedDraft = true;
    });
    _scheduleDraftSave(context.read<TrainingSessionCubit>());
  }

  void _removeSet(BuildContext context, int exerciseIndex, int setIndex) {
    final session = _draftSession;
    if (session == null) return;
    final exercises = List<TrainingSessionExercise>.from(session.exercises);
    final exercise = exercises[exerciseIndex];
    if (exercise.sets.length <= 1) return;
    final sets = List<TrainingSessionSet>.from(exercise.sets)
      ..removeAt(setIndex);
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

  bool _shouldShowRirColumn(TrainingSessionExercise exercise) {
    if (_userHiddenRirColumns.contains(exercise.id)) return false;
    return _userEnabledRirColumns.contains(exercise.id) ||
        exercise.sets.any(
          (set) =>
              (set.plannedRir?.trim().isNotEmpty ?? false) ||
              (set.actualRir?.trim().isNotEmpty ?? false),
        );
  }

  bool _shouldShowTempoColumn(TrainingSessionExercise exercise) {
    if (_userHiddenTempoColumns.contains(exercise.id)) return false;
    return _userEnabledTempoColumns.contains(exercise.id) ||
        exercise.sets.any(
          (set) =>
              (set.plannedTempo?.trim().isNotEmpty ?? false) ||
              (set.actualTempo?.trim().isNotEmpty ?? false),
        );
  }

  void _goToExercise(int index) {
    if (_currentExerciseIndex != index) {
      setState(() => _currentExerciseIndex = index);
    }
    if (!_exercisePageController.hasClients) return;
    _exercisePageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _showExercisePicker(
    BuildContext context,
    TrainingSession session,
  ) async {
    final selectedIndex = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: session.exercises.length,
            separatorBuilder: (_, _) =>
                const Divider(color: AppColors.border, height: 1),
            itemBuilder: (context, index) {
              final exercise = session.exercises[index];
              final completedSets = exercise.sets
                  .where((set) => set.completed)
                  .length;
              final isCurrent = index == _currentExerciseIndex;
              return ListTile(
                selected: isCurrent,
                selectedTileColor: AppColors.primary.withValues(alpha: 0.12),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                leading: CircleAvatar(
                  backgroundColor: isCurrent
                      ? AppColors.primary.withValues(alpha: 0.2)
                      : AppColors.surfaceVariant,
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: isCurrent
                          ? AppColors.primaryVariant
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                title: Text(
                  exercise.exerciseName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  '$completedSets / ${exercise.sets.length} serii',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                trailing: isCurrent
                    ? const Icon(
                        Icons.check_rounded,
                        color: AppColors.primaryVariant,
                      )
                    : null,
                onTap: () => Navigator.of(context).pop(index),
              );
            },
          ),
        );
      },
    );
    if (selectedIndex == null || !mounted) return;
    _goToExercise(selectedIndex);
  }
}

class _ExerciseProgressBar extends StatelessWidget {
  const _ExerciseProgressBar({
    required this.currentIndex,
    required this.exerciseCount,
    required this.exerciseName,
    required this.onPrevious,
    required this.onNext,
    required this.onShowList,
  });

  final int currentIndex;
  final int exerciseCount;
  final String exerciseName;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onShowList;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        children: [
          Row(
            children: [
              _NavigationButton(
                icon: Icons.chevron_left_rounded,
                onTap: onPrevious,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Material(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onShowList,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.format_list_bulleted_rounded,
                            color: AppColors.primaryVariant,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${currentIndex + 1} / $exerciseCount',
                                  style: const TextStyle(
                                    color: AppColors.primaryVariant,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  exerciseName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _NavigationButton(
                icon: Icons.chevron_right_rounded,
                onTap: onNext,
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 4,
              value: exerciseCount == 0
                  ? 0
                  : (currentIndex + 1) / exerciseCount,
              backgroundColor: AppColors.surfaceVariant,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primaryVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RestTimerBanner extends StatelessWidget {
  const _RestTimerBanner({required this.remaining, required this.onStop});

  final String remaining;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.timer_outlined,
              color: AppColors.primaryVariant,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                remaining,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton(onPressed: onStop, child: const Text('Zatrzymaj')),
          ],
        ),
      ),
    );
  }
}

class _NavigationButton extends StatelessWidget {
  const _NavigationButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onTap == null ? AppColors.surfaceVariant : AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 56,
          child: Icon(
            icon,
            color: onTap == null
                ? AppColors.textMuted
                : AppColors.textSecondary,
            size: 26,
          ),
        ),
      ),
    );
  }
}

class _SessionExerciseCard extends StatelessWidget {
  const _SessionExerciseCard({
    required this.exerciseIndex,
    required this.exercise,
    required this.showRirColumn,
    required this.showTempoColumn,
    required this.onShowRirColumn,
    required this.onShowTempoColumn,
    required this.onHideRirColumn,
    required this.onHideTempoColumn,
    required this.onSetChanged,
    required this.onAddSet,
    required this.onRemoveSet,
  });

  final int exerciseIndex;
  final TrainingSessionExercise exercise;
  final bool showRirColumn;
  final bool showTempoColumn;
  final VoidCallback onShowRirColumn;
  final VoidCallback onShowTempoColumn;
  final VoidCallback onHideRirColumn;
  final VoidCallback onHideTempoColumn;
  final void Function(int setIndex, TrainingSessionSet set) onSetChanged;
  final VoidCallback onAddSet;
  final void Function(int setIndex) onRemoveSet;

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
              if (!showRirColumn) ...[
                const SizedBox(width: 8),
                _OptionalColumnButton(
                  key: ValueKey('show-rir-column-button-$exerciseIndex'),
                  label: 'RIR',
                  adding: true,
                  onTap: onShowRirColumn,
                ),
              ] else ...[
                const SizedBox(width: 8),
                _OptionalColumnButton(
                  key: ValueKey('hide-rir-column-button-$exerciseIndex'),
                  label: 'RIR',
                  adding: false,
                  onTap: onHideRirColumn,
                ),
              ],
              if (!showTempoColumn) ...[
                const SizedBox(width: 8),
                _OptionalColumnButton(
                  key: ValueKey('show-tempo-column-button-$exerciseIndex'),
                  label: 'Tempo',
                  adding: true,
                  onTap: onShowTempoColumn,
                ),
              ] else ...[
                const SizedBox(width: 8),
                _OptionalColumnButton(
                  key: ValueKey('hide-tempo-column-button-$exerciseIndex'),
                  label: 'Tempo',
                  adding: false,
                  onTap: onHideTempoColumn,
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const SizedBox(width: 34, child: _HeaderText('SET')),
              const SizedBox(width: 8),
              const Expanded(child: _HeaderText('KG')),
              const SizedBox(width: 8),
              const Expanded(child: _HeaderText('POWT.')),
              if (showRirColumn) ...[
                const SizedBox(width: 8),
                const Expanded(child: _HeaderText('RIR')),
              ],
              if (showTempoColumn) ...[
                const SizedBox(width: 8),
                const Expanded(child: _HeaderText('TEMPO')),
              ],
              const SizedBox(width: 8),
              const SizedBox(width: 44, child: _HeaderText('OK')),
              const SizedBox(width: 8),
              const SizedBox(width: 44),
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
                    if (showRirColumn) ...[
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
                    ],
                    if (showTempoColumn) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: TableCellInput(
                          key: ValueKey(
                            'session-set-tempo-$exerciseIndex-$setIndex',
                          ),
                          value: set.actualTempo ?? '',
                          hint: set.plannedTempo?.isNotEmpty == true
                              ? set.plannedTempo!
                              : '-',
                          keyboardType: TextInputType.text,
                          onChanged: (value) => onSetChanged(
                            setIndex,
                            set.copyWith(
                              actualTempo: value,
                              clearActualTempo: value.trim().isEmpty,
                            ),
                          ),
                        ),
                      ),
                    ],
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
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 44,
                      child: IconButton(
                        tooltip: 'Usuń serię',
                        onPressed: exercise.sets.length > 1
                            ? () => onRemoveSet(setIndex)
                            : null,
                        icon: const Icon(Icons.delete_outline_rounded),
                        color: AppColors.textSecondary,
                        disabledColor: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const ValueKey('add-session-set-button'),
              onPressed: onAddSet,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Dodaj serię'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryVariant,
                side: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.45),
                ),
                minimumSize: const Size.fromHeight(44),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionalColumnButton extends StatelessWidget {
  const _OptionalColumnButton({
    super.key,
    required this.label,
    required this.adding,
    required this.onTap,
  });

  final String label;
  final bool adding;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                adding ? Icons.add_rounded : Icons.close_rounded,
                color: AppColors.primaryVariant,
                size: 16,
              ),
              const SizedBox(width: 2),
              Text(
                '${adding ? '+' : '-'}$label',
                style: const TextStyle(
                  color: AppColors.primaryVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
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
