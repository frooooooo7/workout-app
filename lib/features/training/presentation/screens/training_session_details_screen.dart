import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/services/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_header.dart';
import '../../domain/models/training_history_models.dart';
import '../../domain/models/training_session.dart';
import '../../domain/repositories/training_history_repository.dart';
import '../../domain/repositories/training_session_repository.dart';
import '../bloc/training_session_cubit.dart';
import '../widgets/session_details/session_exercise_card.dart';
import '../widgets/session_details/session_muscle_map.dart';
import '../widgets/session_details/session_summary_header.dart';
import '../widgets/session_details/session_timeline.dart';
import 'ongoing_workout_screen.dart';

/// Nawigacja z ekranu szczegółów (test seam dla `context.push`).
typedef SessionDetailsNavigate =
    Future<Object?> Function(
      BuildContext context,
      String location, {
      Object? extra,
    });

/// Szczegóły zakończonej sesji, ułożone od ogółu do szczegółu:
/// nagłówek z metrykami → mapa mięśni → oś czasu → karty ćwiczeń.
///
/// Metryki całej sesji pojawiają się **wyłącznie** w nagłówku; każda kolejna
/// sekcja dokłada informację, której poprzednie nie niosą.
///
/// Menu: edycja (`/app/training/history/:id/edit`), „Powtórz trening” (nowa
/// aktywna sesja) i usunięcie (offline-first, z potwierdzeniem).
class TrainingSessionDetailsScreen extends StatefulWidget {
  const TrainingSessionDetailsScreen({
    super.key,
    required this.sessionId,
    required this.repository,
    this.sessionRepository,
    this.dataChanges,
    this.navigate,
    this.onSessionsChanged,
  });

  final String sessionId;
  final TrainingHistoryRepository repository;

  /// Test seam; domyślnie [ServiceLocator.trainingSessionRepository].
  final TrainingSessionRepository? sessionRepository;

  /// Sygnał świeżych danych historii; domyślnie
  /// [ServiceLocator.trainingSessionDataChanges].
  final Listenable? dataChanges;

  /// Test seam; domyślnie `context.push`.
  final SessionDetailsNavigate? navigate;

  /// Test seam; domyślnie odświeża historię, statystyki, profil i feed.
  final VoidCallback? onSessionsChanged;

  @override
  State<TrainingSessionDetailsScreen> createState() =>
      _TrainingSessionDetailsScreenState();
}

enum _SessionHeaderAction { edit, repeat, delete }

class _TrainingSessionDetailsScreenState
    extends State<TrainingSessionDetailsScreen> {
  TrainingSessionDetail? _detail;
  bool _loading = true;
  bool _shareSaving = false;
  bool _sharedToProfile = false;

  /// Trwa usuwanie / przygotowanie powtórzenia — menu jest zablokowane.
  bool _busy = false;

  /// Po usunięciu ekran się zamyka; sygnał zmiany danych nie może go już
  /// przeładować (sesji nie ma).
  bool _removed = false;
  String? _error;
  late final Listenable _dataChanges;
  TrainingSessionCubit? _repeatCubit;

  TrainingSessionRepository? get _sessionRepository {
    if (widget.sessionRepository != null) return widget.sessionRepository;
    try {
      return ServiceLocator.trainingSessionRepository;
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _dataChanges =
        widget.dataChanges ?? ServiceLocator.trainingSessionDataChanges;
    _dataChanges.addListener(_onDataChanged);
    _load();
  }

  @override
  void dispose() {
    _dataChanges.removeListener(_onDataChanged);
    unawaited(_repeatCubit?.close());
    super.dispose();
  }

  /// Szczegóły odświeżone w tle albo zsynchronizowana sesja — przeładuj
  /// bez spinnera.
  void _onDataChanged() {
    if (!mounted || _loading || _shareSaving || _removed) return;
    unawaited(_load(silent: true));
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final detail = await widget.repository.getSessionDetail(widget.sessionId);
      final local = await _sessionRepository?.getById(widget.sessionId);
      if (!mounted) return;
      final current = _detail;
      // Ciche przeładowanie może trafić na starszy cache — pokazujemy tylko
      // nowszą wersję (i nie restartujemy animacji bez potrzeby).
      if (silent &&
          current != null &&
          !detail.updatedAt.isAfter(current.updatedAt)) {
        return;
      }
      setState(() {
        _detail = detail;
        _sharedToProfile = local?.sharedToProfile ?? detail.sharedToProfile;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted || silent) return;
      setState(() {
        _loading = false;
        _error = error is ApiException && error.statusCode == 410
            ? 'Ten trening został usunięty.'
            : 'Nie udało się pobrać szczegółów sesji.';
      });
    }
  }

  void _notifySessionsChanged() {
    final notify = widget.onSessionsChanged;
    if (notify != null) {
      notify();
      return;
    }
    ServiceLocator.notifyTrainingSessionsChanged();
    unawaited(_syncAndRefreshProfile());
  }

  Future<void> _onSharePressed() async {
    final repository = _sessionRepository;
    if (repository == null || _detail == null || _shareSaving) return;

    final nextShared = !_sharedToProfile;
    setState(() => _shareSaving = true);
    try {
      final updated = await repository.setSharedToProfile(
        widget.sessionId,
        nextShared,
      );
      if (!mounted) return;
      setState(() {
        _sharedToProfile = updated.sharedToProfile;
        _shareSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updated.sharedToProfile
                ? 'Trening pojawił się na Twoim profilu'
                : 'Usunięto trening z profilu',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      unawaited(_syncAndRefreshProfile());
    } on TrainingSessionDeletedException {
      if (!mounted) return;
      setState(() => _shareSaving = false);
      _closeAfterRemoval('Ten trening został usunięty.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _shareSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nie udało się zapisać zmiany. Spróbuj ponownie.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _syncAndRefreshProfile() async {
    await ServiceLocator.flushTrainingSessionSync();
    ServiceLocator.requestProfileRefresh();
    // Udostępniony (albo schowany / usunięty) trening znika z feedu.
    ServiceLocator.requestFeedRefresh();
  }

  Future<Object?> _navigate(String location, {Object? extra}) {
    final navigate = widget.navigate;
    if (navigate != null) return navigate(context, location, extra: extra);
    return context.push(location, extra: extra);
  }

  void _onMenuActionSelected(_SessionHeaderAction action) {
    switch (action) {
      case _SessionHeaderAction.edit:
        unawaited(_editSession());
      case _SessionHeaderAction.repeat:
        unawaited(_repeatSession());
      case _SessionHeaderAction.delete:
        unawaited(_deleteSession());
    }
  }

  // ── Usuwanie ──────────────────────────────────────────────────────────────

  Future<void> _deleteSession() async {
    final repository = _sessionRepository;
    if (repository == null || _busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Usunąć trening?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Tej operacji nie można cofnąć. Znikną też kudosy i komentarze.',
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
            key: const ValueKey('session-delete-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Usuń',
              style: TextStyle(color: AppColors.strengthWeak),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await repository.delete(widget.sessionId);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nie udało się usunąć treningu. Spróbuj ponownie.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    if (!mounted) return;
    _closeAfterRemoval('Trening został usunięty.');
  }

  void _closeAfterRemoval(String message) {
    _removed = true;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    _notifySessionsChanged();
    messenger.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
    unawaited(navigator.maybePop(true));
  }

  // ── Edycja ────────────────────────────────────────────────────────────────

  Future<void> _editSession() async {
    if (_busy) return;
    final saved = await _navigate(
      '/app/training/history/${Uri.encodeComponent(widget.sessionId)}/edit',
    );
    if (saved != true || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Zapisano zmiany w treningu.'),
        duration: Duration(seconds: 2),
      ),
    );
    await _load();
  }

  // ── Powtórzenie ───────────────────────────────────────────────────────────

  Future<void> _repeatSession() async {
    final repository = _sessionRepository;
    if (repository == null || _busy) return;
    final cubit = _repeatCubit ??= TrainingSessionCubit(
      repository,
      autoRefresh: false,
    );

    setState(() => _busy = true);
    TrainingSession? started;
    TrainingSession? conflict;
    String? failure;
    try {
      conflict = await repository.getActive();
      if (conflict == null) {
        final source = await repository.loadForEdit(widget.sessionId);
        if (source == null) {
          failure =
              'Nie udało się wczytać treningu. Sprawdź połączenie i spróbuj ponownie.';
        } else if (source.exercises.isEmpty) {
          failure = 'Ten trening nie ma ćwiczeń do powtórzenia.';
        } else {
          started = await cubit.startFromSession(source);
          conflict = started == null ? cubit.state.activeConflict : null;
        }
      }
    } catch (_) {
      failure = 'Nie udało się rozpocząć treningu. Spróbuj ponownie.';
    }
    if (!mounted) return;
    setState(() => _busy = false);

    if (failure != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure), duration: const Duration(seconds: 3)),
      );
      return;
    }
    if (conflict != null) {
      final resume = await _askToResume(conflict);
      if (resume != true || !mounted) return;
      unawaited(_openOngoingWorkout(conflict, cubit));
      return;
    }
    final session = started;
    if (session == null) return;
    unawaited(_openOngoingWorkout(session, cubit));
  }

  Future<bool?> _askToResume(TrainingSession active) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Trwa inny trening',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Masz aktywny trening „${active.planName}”. Zakończ go albo anuluj, '
          'zanim powtórzysz ten.',
          style: const TextStyle(color: AppColors.textSecondary),
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
            key: const ValueKey('session-repeat-resume-active'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Wróć do treningu',
              style: TextStyle(color: AppColors.primaryVariant),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openOngoingWorkout(
    TrainingSession session,
    TrainingSessionCubit cubit,
  ) async {
    await _navigate(
      '/app/training/ongoing-workout',
      extra: OngoingWorkoutArgs(initialSession: session, sessionCubit: cubit),
    );
    if (!mounted) return;
    // Aktywny trening mógł się skończyć — historia i statystyki się zmieniły.
    unawaited(cubit.refresh());
  }

  void _showMoreMenu(BuildContext context, RenderBox button) async {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );

    final selected = await showMenu<_SessionHeaderAction>(
      context: context,
      position: position,
      color: AppColors.surface,
      elevation: 10,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: AppColors.border.withValues(alpha: 0.8),
          width: 1.0,
        ),
      ),
      items: [
        const PopupMenuItem(
          key: ValueKey('session-menu-edit'),
          value: _SessionHeaderAction.edit,
          child: Row(
            children: [
              Icon(Icons.edit_outlined, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Text(
                'Edytuj trening',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuItem(
          key: ValueKey('session-menu-repeat'),
          value: _SessionHeaderAction.repeat,
          child: Row(
            children: [
              Icon(Icons.replay_rounded, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Text(
                'Powtórz trening',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          key: ValueKey('session-menu-delete'),
          value: _SessionHeaderAction.delete,
          child: Row(
            children: [
              Icon(
                Icons.delete_outline_rounded,
                color: AppColors.strengthWeak,
                size: 18,
              ),
              SizedBox(width: 10),
              Text(
                'Usuń trening',
                style: TextStyle(
                  color: AppColors.strengthWeak,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (selected != null && mounted) {
      _onMenuActionSelected(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canAct = _detail != null && !_busy && !_removed;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: 'Szczegóły sesji',
              onBack: () => Navigator.of(context).maybePop(),
              actions: [
                AppHeaderIconButton(
                  key: const ValueKey('session-details-share-button'),
                  icon: _sharedToProfile
                      ? Icons.check_rounded
                      : Icons.ios_share_rounded,
                  active: _sharedToProfile,
                  tooltip: _sharedToProfile
                      ? 'Usuń trening z profilu'
                      : 'Udostępnij trening na profilu',
                  onTap: _onSharePressed,
                ),
                Builder(
                  builder: (btnContext) {
                    return AppHeaderIconButton(
                      key: const ValueKey('session-details-more-button'),
                      icon: Icons.more_vert_rounded,
                      tooltip: 'Więcej opcji',
                      onTap: () {
                        if (!canAct) return;
                        final box = btnContext.findRenderObject() as RenderBox;
                        _showMoreMenu(context, box);
                      },
                    );
                  },
                ),
              ],
            ),
            if (_busy)
              const LinearProgressIndicator(
                minHeight: 2,
                color: AppColors.primary,
                backgroundColor: Colors.transparent,
              ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : _error != null
                  ? _ErrorState(message: _error!, onRetry: _load)
                  : _DetailContent(detail: _detail!),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailContent extends StatefulWidget {
  const _DetailContent({required this.detail});

  final TrainingSessionDetail detail;

  @override
  State<_DetailContent> createState() => _DetailContentState();
}

class _DetailContentState extends State<_DetailContent> {
  /// Klucze kart ćwiczeń — punkt zaczepienia dla skoku z osi czasu.
  late List<GlobalKey> _exerciseKeys;
  int? _highlightedIndex;
  Timer? _highlightTimer;

  @override
  void initState() {
    super.initState();
    _exerciseKeys = List.generate(
      widget.detail.exercises.length,
      (_) => GlobalKey(),
    );
  }

  @override
  void didUpdateWidget(_DetailContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.detail.exercises.length != widget.detail.exercises.length) {
      _exerciseKeys = List.generate(
        widget.detail.exercises.length,
        (_) => GlobalKey(),
      );
    }
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    super.dispose();
  }

  Future<void> _jumpToExercise(int index) async {
    final context = _exerciseKeys[index].currentContext;
    if (context == null) return;

    setState(() => _highlightedIndex = index);
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _highlightedIndex = null);
    });

    await Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
  }

  @override
  Widget build(BuildContext context) {
    final exercises = widget.detail.exercises;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        SessionSummaryHeader(detail: widget.detail),
        const SizedBox(height: 12),
        SessionMuscleMap(detail: widget.detail),
        const SizedBox(height: 12),
        SessionTimeline(detail: widget.detail, onExerciseTap: _jumpToExercise),
        if (exercises.isNotEmpty) ...[
          const SizedBox(height: 22),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              'Ćwiczenia',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ),
          for (var i = 0; i < exercises.length; i++)
            Padding(
              key: _exerciseKeys[i],
              padding: const EdgeInsets.only(bottom: 10),
              child: SessionExerciseCard(
                exercise: exercises[i],
                index: i,
                isHighlighted: _highlightedIndex == i,
              ),
            ),
        ],
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              color: AppColors.textMuted,
              size: 34,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Spróbuj ponownie'),
            ),
          ],
        ),
      ),
    );
  }
}
