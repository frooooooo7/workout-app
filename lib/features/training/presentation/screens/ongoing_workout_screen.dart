import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/plan_colors.dart';
import '../../../../core/units/weight_unit.dart';
import '../../../../core/widgets/app_action_sheet.dart';
import '../../../library/domain/models/exercise.dart';
import '../../../library/presentation/screens/pick_exercise_screen.dart';
import '../../domain/models/training_session.dart';
import '../../domain/models/training_stats.dart';
import '../../domain/repositories/previous_performance_repository.dart';
import '../../domain/repositories/training_stats_repository.dart';
import '../../domain/services/live_workout_insights.dart';
import '../../domain/services/rest_timer_scheduler.dart';
import '../../domain/services/stats/personal_records_calculator.dart';
import '../../domain/services/stats/stats_sets.dart' show statsExerciseKey;
import '../../domain/services/training_session_detail_mapper.dart'
    show parseWeightKg;
import '../bloc/training_session_cubit.dart';
import '../widgets/ongoing_workout/next_exercise_card.dart';
import '../widgets/ongoing_workout/ongoing_workout_header.dart';
import '../widgets/ongoing_workout/record_burst.dart';
import '../widgets/ongoing_workout/rest_timer_controller.dart';
import '../widgets/ongoing_workout/rest_timer_controls.dart';
import '../widgets/ongoing_workout/rest_timer_pill.dart';
import '../widgets/ongoing_workout/session_exercise_card.dart';
import '../widgets/ongoing_workout/workout_colors.dart';
import '../widgets/ongoing_workout/workout_progress_header.dart';
import 'workout_summary_screen.dart';

class OngoingWorkoutArgs {
  const OngoingWorkoutArgs({
    this.initialSession,
    this.sessionCubit,
    this.pickExercise,
    this.restTimerScheduler,
    this.previousPerformance,
    this.statsRepository,
  });

  final TrainingSession? initialSession;
  final TrainingSessionCubit? sessionCubit;
  final Future<Exercise?> Function(BuildContext context)? pickExercise;
  final RestTimerScheduler? restTimerScheduler;

  /// Źródło kolumny „Poprzednio”; domyślnie lokalna historia użytkownika.
  final PreviousPerformanceRepository? previousPerformance;

  /// Historia do rekordów ćwiczeń; domyślnie lokalne statystyki.
  final TrainingStatsRepository? statsRepository;
}

/// Pozycje menu ⋯ w nagłówku treningu.
enum _WorkoutMenuAction { rest, rir, tempo, note, exercises, discard }

class OngoingWorkoutScreen extends StatefulWidget {
  const OngoingWorkoutScreen({super.key, this.args});

  final OngoingWorkoutArgs? args;

  @override
  State<OngoingWorkoutScreen> createState() => _OngoingWorkoutScreenState();
}

class _OngoingWorkoutScreenState extends State<OngoingWorkoutScreen> {
  Timer? _saveDebounce;
  final PageController _exercisePageController = PageController();
  final ValueNotifier<TrainingSession?> _draftSession =
      ValueNotifier<TrainingSession?>(null);
  late final RestTimerController _rest = RestTimerController(
    scheduler: _restTimerScheduler,
  );
  final Set<String> _userEnabledRirColumns = {};
  final Set<String> _userEnabledTempoColumns = {};
  final Set<String> _userHiddenRirColumns = {};
  final Set<String> _userHiddenTempoColumns = {};

  /// Ćwiczenia, w których notatkę otwarto z menu ⋯.
  final Set<String> _openNotes = {};

  /// Poprzedni trening i rekord każdego ćwiczenia (po id ćwiczenia w sesji).
  final Map<String, ExerciseHistoryInsights> _history = {};
  final Set<String> _historyRequested = {};
  Future<Map<String, ExerciseBest>?>? _bests;

  RecordBurstData? _recordBurst;

  /// Osobny notifier, żeby zmiana strony (także w trakcie swipe'a) nie
  /// przebudowywała całego ekranu — słucha go tylko pasek postępu.
  final ValueNotifier<int> _currentExerciseIndex = ValueNotifier<int>(0);
  bool _hasUnsavedDraft = false;
  Future<void>? _inFlightSave;
  bool _allowPop = false;

  @override
  void initState() {
    super.initState();
    _rest.addListener(_onRestChanged);
    unawaited(_rest.loadLastCustomDuration());
  }

  void _onRestChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _rest
      ..removeListener(_onRestChanged)
      ..dispose();
    _draftSession.dispose();
    _currentExerciseIndex.dispose();
    _exercisePageController.dispose();
    super.dispose();
  }

  RestTimerScheduler? get _restTimerScheduler {
    try {
      return widget.args?.restTimerScheduler ??
          ServiceLocator.restTimerScheduler;
    } catch (_) {
      return null;
    }
  }

  PreviousPerformanceRepository? get _previousPerformance {
    try {
      return widget.args?.previousPerformance ??
          ServiceLocator.previousPerformanceRepository;
    } catch (_) {
      return null;
    }
  }

  TrainingStatsRepository? get _statsRepository {
    try {
      return widget.args?.statsRepository ??
          ServiceLocator.trainingStatsRepository;
    } catch (_) {
      // Bez zalogowanego użytkownika (testy) — rekord z poprzedniego treningu.
      return null;
    }
  }

  /// Historia ćwiczenia z pamięci podręcznej; przy pierwszym pytaniu startuje
  /// wczytywanie i zwraca `null`.
  ExerciseHistoryInsights? _historyFor(TrainingSessionExercise exercise) {
    final cached = _history[exercise.id];
    if (cached == null && _historyRequested.add(exercise.id)) {
      unawaited(_loadHistory(exercise));
    }
    return cached;
  }

  Future<void> _loadHistory(TrainingSessionExercise exercise) async {
    final (previous, bests) = await (
      _loadPreviousSets(exercise),
      _bests ??= _loadBests(),
    ).wait;
    final best = bests?[statsExerciseKey(exercise)];
    final record = best != null
        ? ExerciseRecordBaseline.fromBest(best)
        : previous == null
        ? null
        : ExerciseRecordBaseline.fromSets(previous);
    if (!mounted) return;
    setState(() {
      _history[exercise.id] = ExerciseHistoryInsights(
        previousSets: previous,
        record: record,
      );
    });
  }

  /// Poprzedni wynik ćwiczenia; brak danych lub błąd odczytu to po prostu
  /// brak kolumny — nigdy błąd na ekranie treningu.
  Future<List<TrainingSessionSet>?> _loadPreviousSets(
    TrainingSessionExercise exercise,
  ) async {
    final repository = _previousPerformance;
    if (repository == null) return null;
    try {
      return await repository.lastCompletedSets(
        exerciseId: exercise.exerciseId,
        exerciseName: exercise.exerciseName,
      );
    } catch (_) {
      return null;
    }
  }

  /// Najlepsze wyniki ćwiczeń z całej historii — rekordy do pobicia.
  Future<Map<String, ExerciseBest>?> _loadBests() async {
    final repository = _statsRepository;
    if (repository == null) return null;
    try {
      final history = await repository.allCompletedSessions();
      return {
        for (final best in PersonalRecordsCalculator.compute(history).bests)
          best.exerciseKey: best,
      };
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    if (args == null) return const _MissingSessionScreen();

    final content = BlocBuilder<TrainingSessionCubit, TrainingSessionState>(
      builder: (context, state) {
        final sourceSession = state.activeSession ?? args.initialSession;
        if (sourceSession == null) return const _MissingSessionScreen();
        if (_draftSession.value == null ||
            _draftSession.value!.id != sourceSession.id) {
          _draftSession.value = sourceSession;
          _userEnabledRirColumns.clear();
          _userEnabledTempoColumns.clear();
          _userHiddenRirColumns.clear();
          _userHiddenTempoColumns.clear();
          _openNotes.clear();
          _currentExerciseIndex.value = 0;
        }
        final session = _draftSession.value!;
        final exerciseCount = session.exercises.length;
        if (exerciseCount > 0 && _currentExerciseIndex.value >= exerciseCount) {
          _currentExerciseIndex.value = exerciseCount - 1;
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
              bottom: false,
              child: Stack(
                children: [
                  Column(
                    children: [
                      OngoingWorkoutHeader(
                        planName: session.planName,
                        startedAt: session.startedAt,
                        onCollapse: () => _leaveWorkout(context),
                        onMore: () => unawaited(_showWorkoutMenu(context)),
                        onFinish: exerciseCount == 0
                            ? null
                            : () {
                                final current = _draftSession.value;
                                if (current != null) _finish(context, current);
                              },
                      ),
                      if (exerciseCount == 0)
                        Expanded(
                          child: _EmptyWorkout(
                            onAddExercise: () => _addExerciseToSession(context),
                          ),
                        )
                      else ...[
                        _buildProgress(context),
                        Expanded(child: _buildExercisePages(context, session)),
                      ],
                    ],
                  ),
                  if (_recordBurst != null)
                    Positioned(
                      left: 16,
                      right: 16,
                      top: 118,
                      child: IgnorePointer(
                        child: RecordBurst(
                          key: ValueKey(_recordBurst!.id),
                          data: _recordBurst!,
                          onDone: () => setState(() => _recordBurst = null),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 16 + MediaQuery.paddingOf(context).bottom,
                    child: _buildRestDock(context),
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

  Widget _buildProgress(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_draftSession, _currentExerciseIndex]),
      builder: (context, _) {
        final session = _draftSession.value;
        if (session == null || session.exercises.isEmpty) {
          return const SizedBox.shrink();
        }
        return WorkoutProgressHeader(
          exercises: session.exercises,
          currentIndex: _currentExerciseIndex.value.clamp(
            0,
            session.exercises.length - 1,
          ),
          accent: PlanColors.of(session.planName),
          onShowList: () => unawaited(_showExercisePicker(context, session)),
          onSelectExercise: _goToExercise,
        );
      },
    );
  }

  Widget _buildExercisePages(BuildContext context, TrainingSession session) {
    final restVisible = _restDockVisible(context);
    final bottomInset =
        24 +
        MediaQuery.paddingOf(context).bottom +
        // Panel odpoczynku nie może zasłaniać „Dodaj ćwiczenie”.
        (restVisible ? 92 + 16 : 0);
    return PageView.builder(
      controller: _exercisePageController,
      itemCount: session.exercises.length,
      // Sąsiednie strony budują się z wyprzedzeniem, więc swipe nie czeka
      // na layout karty.
      allowImplicitScrolling: true,
      onPageChanged: (index) => _currentExerciseIndex.value = index,
      itemBuilder: (context, index) {
        final exercise = session.exercises[index];
        final next = index + 1 < session.exercises.length
            ? session.exercises[index + 1]
            : null;
        return _KeepAlivePage(
          key: ValueKey('exercise-page-${exercise.id}'),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(12, 12, 12, bottomInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SessionExerciseCard(
                  key: ValueKey(exercise.id),
                  exerciseIndex: index,
                  exercise: exercise,
                  history: _historyFor(exercise),
                  showRirColumn: _shouldShowRirColumn(exercise),
                  showTempoColumn: _shouldShowTempoColumn(exercise),
                  noteOpen: _openNotes.contains(exercise.id),
                  onSetChanged: (setIndex, set) =>
                      _updateSet(context, index, setIndex, set),
                  onAddSet: () => _addSet(context, index),
                  onRemoveSet: (setIndex) =>
                      _removeSet(context, index, setIndex),
                  onNoteChanged: (note) => _updateNote(context, index, note),
                  onRecord: _showRecord,
                ),
                if (next != null) ...[
                  const SizedBox(height: 12),
                  NextExerciseCard(
                    exercise: next,
                    lastResult: _historyFor(next)?.lastTopSet(),
                    onTap: () => _goToExercise(index + 1),
                  ),
                ],
                const SizedBox(height: 10),
                Center(
                  child: TextButton.icon(
                    key: ValueKey('add-exercise-button-$index'),
                    onPressed: () => _addExerciseToSession(context),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Dodaj ćwiczenie'),
                    style: TextButton.styleFrom(
                      foregroundColor: WorkoutColors.link,
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      textStyle: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Panel znika pod klawiaturą — nie zasłania pól serii w trakcie pisania.
  bool _restDockVisible(BuildContext context) =>
      _rest.isActive && MediaQuery.viewInsetsOf(context).bottom == 0;

  Widget _buildRestDock(BuildContext context) {
    return RestTimerDock(
      visible: _restDockVisible(context),
      child: ListenableBuilder(
        listenable: Listenable.merge([_draftSession, _currentExerciseIndex]),
        builder: (context, _) => RestTimerPill(
          remaining: _rest.remaining,
          total: _rest.total,
          caption: _upNextCaption(),
          onExtend: () =>
              unawaited(_reportSchedule(_rest.extend(_restExtension))),
          onSkip: _rest.stop,
          onChangeDuration: () => unawaited(_pickRestDuration(context)),
        ),
      ),
    );
  }

  static const _restExtension = Duration(seconds: 15);

  /// „Teraz: seria 3 · 95 kg × 6” — co czeka po przerwie.
  String? _upNextCaption() {
    final session = _draftSession.value;
    if (session == null || session.exercises.isEmpty) return null;
    final index = _currentExerciseIndex.value.clamp(
      0,
      session.exercises.length - 1,
    );
    final exercise = session.exercises[index];
    final setIndex = exercise.sets.indexWhere((set) => !set.completed);
    if (setIndex == -1) {
      final next = index + 1 < session.exercises.length
          ? session.exercises[index + 1]
          : null;
      return next == null ? null : 'Teraz: ${next.exerciseName}';
    }
    final set = exercise.sets[setIndex];
    final label = setRowLabels(exercise.sets.map((s) => s.setType))[setIndex];
    final name = set.setType == SetType.warmup
        ? 'rozgrzewka'
        : (set.setType.badge == null ? 'seria $label' : set.setType.label);
    final weight = parseWeightKg(set.actualWeight ?? set.plannedWeight);
    final reps = (set.actualReps?.trim().isNotEmpty ?? false)
        ? set.actualReps!.trim()
        : set.plannedReps.trim();
    final load = [
      if (weight != null && weight > 0) formatWeightWithUnit(weight),
      if (reps.isNotEmpty) reps,
    ].join(' × ');
    return load.isEmpty ? 'Teraz: $name' : 'Teraz: $name · $load';
  }

  void _showRecord(RecordBurstData data) {
    unawaited(HapticFeedback.heavyImpact());
    setState(() => _recordBurst = data);
  }

  Future<void> _showWorkoutMenu(BuildContext context) async {
    final session = _draftSession.value;
    if (session == null) return;
    final hasExercises = session.exercises.isNotEmpty;
    final exercise = hasExercises
        ? session.exercises[_currentExerciseIndex.value.clamp(
            0,
            session.exercises.length - 1,
          )]
        : null;
    final restActive = _rest.isActive;
    final action = await showAppActionSheet<_WorkoutMenuAction>(
      context,
      title: exercise?.exerciseName ?? 'Trening',
      actions: [
        AppSheetAction(
          value: _WorkoutMenuAction.rest,
          icon: restActive ? Icons.timer_off_outlined : Icons.timer_outlined,
          label: restActive ? 'Zatrzymaj odpoczynek' : 'Odpoczynek',
          subtitle: restActive
              ? null
              : 'Wybierz czas — przerwa startuje sama po odhaczeniu serii',
        ),
        if (exercise != null) ...[
          AppSheetAction(
            value: _WorkoutMenuAction.rir,
            icon: Icons.speed_rounded,
            label: _shouldShowRirColumn(exercise)
                ? 'Ukryj kolumnę RIR'
                : 'Pokaż kolumnę RIR',
            subtitle: 'Ile powtórzeń zostało w zapasie',
          ),
          AppSheetAction(
            value: _WorkoutMenuAction.tempo,
            icon: Icons.av_timer_rounded,
            label: _shouldShowTempoColumn(exercise)
                ? 'Ukryj kolumnę tempo'
                : 'Pokaż kolumnę tempo',
            subtitle: 'Np. 3-1-1-0',
          ),
          if (!_noteVisible(exercise))
            const AppSheetAction(
              value: _WorkoutMenuAction.note,
              icon: Icons.sticky_note_2_outlined,
              label: 'Dodaj notatkę',
            ),
          const AppSheetAction(
            value: _WorkoutMenuAction.exercises,
            icon: Icons.format_list_bulleted_rounded,
            label: 'Lista ćwiczeń',
          ),
        ],
        const AppSheetAction(
          value: _WorkoutMenuAction.discard,
          icon: Icons.delete_outline_rounded,
          label: 'Odrzuć trening',
          destructive: true,
        ),
      ],
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case _WorkoutMenuAction.rest:
        if (restActive) {
          _rest.stop();
        } else {
          await _pickRestDuration(context);
        }
      case _WorkoutMenuAction.rir:
        _toggleRirColumn(exercise!);
      case _WorkoutMenuAction.tempo:
        _toggleTempoColumn(exercise!);
      case _WorkoutMenuAction.note:
        setState(() => _openNotes.add(exercise!.id));
      case _WorkoutMenuAction.exercises:
        await _showExercisePicker(context, session);
      case _WorkoutMenuAction.discard:
        await _cancelWorkout(context, session);
    }
  }

  bool _noteVisible(TrainingSessionExercise exercise) =>
      _openNotes.contains(exercise.id) ||
      (exercise.note?.trim().isNotEmpty ?? false);

  void _toggleRirColumn(TrainingSessionExercise exercise) {
    setState(() {
      if (_shouldShowRirColumn(exercise)) {
        _userEnabledRirColumns.remove(exercise.id);
        _userHiddenRirColumns.add(exercise.id);
      } else {
        _userHiddenRirColumns.remove(exercise.id);
        _userEnabledRirColumns.add(exercise.id);
      }
    });
  }

  void _toggleTempoColumn(TrainingSessionExercise exercise) {
    setState(() {
      if (_shouldShowTempoColumn(exercise)) {
        _userEnabledTempoColumns.remove(exercise.id);
        _userHiddenTempoColumns.add(exercise.id);
      } else {
        _userHiddenTempoColumns.remove(exercise.id);
        _userEnabledTempoColumns.add(exercise.id);
      }
    });
  }

  Future<void> _finish(BuildContext context, TrainingSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Zakończyć trening?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Czy na pewno chcesz zakończyć ten trening? Sesja zostanie zapisana w historii.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Anuluj',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Zakończ',
              style: TextStyle(color: AppColors.primaryVariant),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final cubit = context.read<TrainingSessionCubit>();
    await _flushDraft(cubit);
    final finished = await cubit.finish(session.id);
    if (!context.mounted) return;
    _openSummary(context, finished);
  }

  /// Zamienia ekran treningu na podsumowanie. Pod go_routerem najpierw
  /// zdejmujemy tę trasę (żeby `await push(...)` u wołającego się domknął
  /// i odświeżył listy), a dopiero potem wypychamy podsumowanie — obie
  /// operacje trafiają do jednej klatki, więc dla użytkownika to jedna
  /// płynna zamiana ekranów.
  void _openSummary(BuildContext context, TrainingSession finished) {
    final args = WorkoutSummaryArgs(session: finished);
    setState(() => _allowPop = true);

    final router = GoRouter.maybeOf(context);
    if (router == null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => WorkoutSummaryScreen(args: args),
        ),
      );
      return;
    }
    router.pop();
    router.push(WorkoutSummaryScreen.routePath, extra: args);
  }

  /// Zwija ekran — trening trwa dalej i wraca z karty na ekranie Trening.
  Future<void> _leaveWorkout(BuildContext context) async {
    final cubit = context.read<TrainingSessionCubit>();
    await _flushDraft(cubit);
    if (!context.mounted) return;
    setState(() => _allowPop = true);
    context.pop();
  }

  Future<void> _cancelWorkout(
    BuildContext context,
    TrainingSession session,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Odrzucić trening?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Czy na pewno chcesz odrzucić ten trening? Wszystkie zapisane postępy zostaną utracone.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Anuluj',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Odrzuć',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final cubit = context.read<TrainingSessionCubit>();
      _saveDebounce?.cancel();
      await cubit.cancel(session.id);
      if (!context.mounted) return;
      setState(() => _allowPop = true);
      context.pop();
    }
  }

  Future<void> _addExerciseToSession(BuildContext context) async {
    final session = _draftSession.value;
    if (session == null) return;

    final wasEmpty = session.exercises.isEmpty;

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
      _draftSession.value = session.copyWith(exercises: exercises);
      _hasUnsavedDraft = true;
    });
    _currentExerciseIndex.value = nextIndex;
    final cubit = context.read<TrainingSessionCubit>();
    if (wasEmpty) {
      _saveDebounce?.cancel();
      await _flushDraft(cubit);
    } else {
      _scheduleDraftSave(cubit);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_exercisePageController.hasClients) return;
      _exercisePageController.jumpToPage(nextIndex);
      _currentExerciseIndex.value = nextIndex;
    });
  }

  /// Ręczny wybór długości przerwy (menu ⋯ albo dotknięcie panelu).
  Future<void> _pickRestDuration(BuildContext context) async {
    final duration = await showRestDurationPicker(context, controller: _rest);
    if (duration == null || !context.mounted) return;
    await _reportSchedule(_rest.start(duration));
  }

  /// Licznik działa zawsze; komunikat tylko, gdy nie wyszło powiadomienie.
  Future<void> _reportSchedule(Future<bool> scheduled) async {
    final ok = await scheduled;
    if (ok || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Timer lokalny wystartował, ale powiadomienie systemowe nie zostało zaplanowane.',
        ),
      ),
    );
  }

  void _updateSet(
    BuildContext context,
    int exerciseIndex,
    int setIndex,
    TrainingSessionSet set,
  ) {
    final session = _draftSession.value;
    if (session == null) return;
    final exercises = List<TrainingSessionExercise>.from(session.exercises);
    final exercise = exercises[exerciseIndex];
    final sets = List<TrainingSessionSet>.from(exercise.sets);
    final justCompleted = set.completed && !sets[setIndex].completed;
    sets[setIndex] = set;
    exercises[exerciseIndex] = exercise.copyWith(sets: sets);
    _draftSession.value = session.copyWith(exercises: exercises);
    _hasUnsavedDraft = true;
    _scheduleDraftSave(context.read<TrainingSessionCubit>());
    // Przerwa startuje sama po odhaczeniu serii, z ostatnio wybraną długością.
    if (justCompleted) {
      unawaited(_reportSchedule(_rest.start(_rest.selectedDuration)));
    }
  }

  void _updateNote(BuildContext context, int exerciseIndex, String note) {
    final session = _draftSession.value;
    if (session == null) return;
    final exercises = List<TrainingSessionExercise>.from(session.exercises);
    final exercise = exercises[exerciseIndex];
    exercises[exerciseIndex] = note.trim().isEmpty
        ? exercise.copyWith(clearNote: true)
        : exercise.copyWith(note: note);
    _draftSession.value = session.copyWith(exercises: exercises);
    _hasUnsavedDraft = true;
    _scheduleDraftSave(context.read<TrainingSessionCubit>());
  }

  void _addSet(BuildContext context, int exerciseIndex) {
    final session = _draftSession.value;
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
      _draftSession.value = session.copyWith(exercises: exercises);
      _hasUnsavedDraft = true;
    });
    _scheduleDraftSave(context.read<TrainingSessionCubit>());
  }

  void _removeSet(BuildContext context, int exerciseIndex, int setIndex) {
    final session = _draftSession.value;
    if (session == null) return;
    final exercises = List<TrainingSessionExercise>.from(session.exercises);
    final exercise = exercises[exerciseIndex];
    if (exercise.sets.length <= 1) return;
    final sets = List<TrainingSessionSet>.from(exercise.sets)
      ..removeAt(setIndex);
    exercises[exerciseIndex] = exercise.copyWith(sets: sets);
    setState(() {
      _draftSession.value = session.copyWith(exercises: exercises);
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
    // Zapis w toku mógł nie objąć ostatnich zmian — poczekaj na niego, zanim
    // zdecydujesz, czy jest co zapisywać (np. przed „Zakończ”).
    final inFlight = _inFlightSave;
    if (inFlight != null) {
      try {
        await inFlight;
      } catch (_) {
        /* błąd obsługuje wywołanie, które rozpoczęło zapis */
      }
    }
    final draft = _draftSession.value;
    if (draft == null || !_hasUnsavedDraft) return;
    // Flaga opada przed zapisem: edycja w trakcie `save` ustawi ją ponownie,
    // więc kolejny debounce jej nie pominie.
    _hasUnsavedDraft = false;
    final save = cubit.save(draft);
    _inFlightSave = save;
    try {
      await save;
    } catch (_) {
      _hasUnsavedDraft = true;
      rethrow;
    } finally {
      if (identical(_inFlightSave, save)) _inFlightSave = null;
    }
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
    if (!_exercisePageController.hasClients) {
      _currentExerciseIndex.value = index;
      return;
    }
    final from =
        _exercisePageController.page?.round() ?? _currentExerciseIndex.value;
    if (from == index) return;
    // Przy skoku o kilka ćwiczeń animacja przez wszystkie strony pośrednie
    // buduje każdą z nich po drodze — przeskakujemy na sąsiada celu i
    // animujemy już tylko ostatnią stronę.
    if ((index - from).abs() > 1) {
      _exercisePageController.jumpToPage(index > from ? index - 1 : index + 1);
    }
    _currentExerciseIndex.value = index;
    _exercisePageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
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
              final workingSets = exercise.sets.where(
                (set) => set.countsTowardStats,
              );
              final completedSets = workingSets
                  .where((set) => set.completed)
                  .length;
              final isCurrent = index == _currentExerciseIndex.value;
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
                  '$completedSets / ${workingSets.length} serii',
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

/// Utrzymuje stronę ćwiczenia przy życiu po zjechaniu z ekranu — powrót do
/// niej nie odtwarza pól tekstowych ani miniatury od zera.
class _KeepAlivePage extends StatefulWidget {
  const _KeepAlivePage({super.key, required this.child});

  final Widget child;

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RepaintBoundary(child: widget.child);
  }
}

/// Trening bez ćwiczeń (start „z ręki”).
class _EmptyWorkout extends StatelessWidget {
  const _EmptyWorkout({required this.onAddExercise});

  final VoidCallback onAddExercise;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.fitness_center_rounded,
            size: 56,
            color: AppColors.primary.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 20),
          const Text(
            'Dodaj pierwsze ćwiczenie',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Wybór ćwiczeń i zapisywanie serii działa tak jak przy treningu z planu.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const ValueKey('add-first-exercise-button'),
            onPressed: onAddExercise,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Dodaj ćwiczenie'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 22),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
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
