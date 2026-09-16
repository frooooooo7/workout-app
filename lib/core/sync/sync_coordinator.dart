import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';

import '../../features/library/data/exercise_database.dart';
import '../../features/library/data/sync/exercise_sync_engine.dart';
import '../../features/training/data/sync/training_plan_sync_engine.dart';
import '../../features/training/data/sync/training_session_sync_engine.dart';
import 'sync_engine_base.dart';
import 'sync_failure.dart';
import 'sync_status.dart';

/// Dyryguje synchronizacją zalogowanego użytkownika:
///
/// * pełny cykl w bezpiecznej kolejności — ćwiczenia, plany (odwołują się
///   do ćwiczeń), na końcu sesje (odwołują się do jednych i drugich),
/// * synchronizacja chwilę po powrocie sieci ([networkAvailability]),
/// * ponawianie z narastającym odstępem, dopóki są niewysłane zmiany — na
///   wypadek, gdy sieć „jest”, ale internet jeszcze nie działa,
/// * synchronizacja po powrocie aplikacji na pierwszy plan,
/// * [status] dla wskaźnika synchronizacji.
class SyncCoordinator {
  SyncCoordinator({
    required ExerciseDatabase localDb,
    required ExerciseSyncEngine exercises,
    required TrainingPlanSyncEngine plans,
    required TrainingSessionSyncEngine sessions,
    required ValueNotifier<SyncStatus> status,
    Stream<bool>? networkAvailability,
    this.initialRetryDelay = const Duration(seconds: 15),
    this.maxRetryDelay = const Duration(minutes: 2),
    this.reconnectDelay = const Duration(seconds: 2),
    this.listenToAppLifecycle = true,
  }) : _localDb = localDb,
       _exercises = exercises,
       _plans = plans,
       _sessions = sessions,
       _status = status,
       _networkAvailability = networkAvailability,
       _retryDelay = initialRetryDelay;

  final ExerciseDatabase _localDb;
  final ExerciseSyncEngine _exercises;
  final TrainingPlanSyncEngine _plans;
  final TrainingSessionSyncEngine _sessions;
  final ValueNotifier<SyncStatus> _status;
  final Stream<bool>? _networkAvailability;

  final Duration initialRetryDelay;
  final Duration maxRetryDelay;

  /// Interfejs sieci wstaje zwykle chwilę przed tym, zanim działa DNS
  /// i routing — pierwsza próba zaraz po zdarzeniu często by się nie udała.
  final Duration reconnectDelay;

  /// Wyłączane w testach bez `WidgetsBinding`.
  final bool listenToAppLifecycle;

  /// Świeżo zakończony cykl bez zaległości nie jest powtarzany tylko dlatego,
  /// że przyszło zdarzenie „online” (np. początkowe przy starcie).
  static const _freshSyncWindow = Duration(seconds: 30);

  late final List<SyncEngineBase> _engines = [_exercises, _plans, _sessions];

  AppLifecycleListener? _lifecycleListener;
  StreamSubscription<bool>? _networkSubscription;
  Timer? _retryTimer;
  Timer? _reconnectTimer;
  Timer? _initialSyncTimer;
  Timer? _evaluateDebounce;
  Duration _retryDelay;
  Future<void>? _running;
  DateTime? _lastPassFinishedAt;
  bool? _networkAvailable;
  bool _rerunRequested = false;
  bool _passFinishedSinceEvaluation = false;
  bool _offline = false;
  int _evaluationSeq = 0;
  bool _started = false;
  bool _stopped = false;

  void start() {
    if (_started || _stopped) return;
    _started = true;
    for (final engine in _engines) {
      engine.activeRuns.addListener(_onEngineActivity);
    }
    if (listenToAppLifecycle) {
      _lifecycleListener = AppLifecycleListener(
        onResume: () => unawaited(syncNow(resetBackoff: true)),
      );
      // Pierwsza klatka czyta bazę — sync startuje sekundę później.
      _initialSyncTimer = Timer(const Duration(seconds: 1), () {
        _initialSyncTimer = null;
        if (!_stopped) unawaited(syncNow());
      });
    } else {
      unawaited(syncNow());
    }
    _networkSubscription = _networkAvailability?.listen(
      _onNetworkAvailability,
      onError: (Object error, StackTrace stackTrace) {
        // Brak wtyczki na danej platformie — zostaje ponawianie i resume.
        developer.log(
          'Network availability stream failed',
          name: 'SyncCoordinator',
          error: error,
          stackTrace: stackTrace,
        );
      },
    );
  }

  void stop() {
    if (_stopped) return;
    _stopped = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _initialSyncTimer?.cancel();
    _initialSyncTimer = null;
    _evaluateDebounce?.cancel();
    _evaluateDebounce = null;
    unawaited(_networkSubscription?.cancel());
    _networkSubscription = null;
    _lifecycleListener?.dispose();
    _lifecycleListener = null;
    for (final engine in _engines) {
      engine.activeRuns.removeListener(_onEngineActivity);
      engine.stop();
    }
  }

  /// Pełny cykl synchronizacji.
  ///
  /// [retryRejected] przywraca do kolejki zmiany odrzucone przez serwer
  /// (ręczne „Synchronizuj teraz”). Wywołanie w trakcie trwającego cyklu
  /// dokłada jeszcze jeden po jego zakończeniu.
  Future<void> syncNow({
    bool retryRejected = false,
    bool resetBackoff = false,
  }) async {
    if (_stopped) return;
    if (resetBackoff) _retryDelay = initialRetryDelay;
    if (retryRejected) {
      try {
        await _localDb.clearSyncErrors();
      } catch (_) {
        return; // baza jest zamykana (wylogowanie)
      }
    }

    final running = _running;
    if (running != null) {
      _rerunRequested = true;
      return running;
    }

    final pass = _runPasses();
    _running = pass;
    _onEngineActivity();
    try {
      await pass;
    } finally {
      _running = null;
      _lastPassFinishedAt = DateTime.now();
      _passFinishedSinceEvaluation = true;
      _onEngineActivity();
    }
  }

  /// Niewysłane i odrzucone zmiany — np. do ostrzeżenia przy wylogowaniu.
  Future<int> countUnsyncedChanges() async {
    try {
      final backlog = await _localDb.countSyncBacklog();
      return backlog.pending + backlog.failed;
    } catch (_) {
      return 0;
    }
  }

  void _onNetworkAvailability(bool available) {
    if (_stopped) return;
    final wasAvailable = _networkAvailable;
    _networkAvailable = available;

    if (!available) {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      return;
    }
    // Np. Wi-Fi → Wi-Fi + LTE: połączenie było i jest, nic nie wróciło.
    if (wasAvailable == true) return;

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(reconnectDelay, () {
      _reconnectTimer = null;
      if (_stopped || _isFreshlySynced) return;
      unawaited(syncNow(resetBackoff: true));
    });
  }

  bool get _isFreshlySynced {
    final finishedAt = _lastPassFinishedAt;
    return _running == null &&
        _status.value.phase == SyncPhase.idle &&
        finishedAt != null &&
        DateTime.now().difference(finishedAt) < _freshSyncWindow;
  }

  Future<void> _runPasses() async {
    do {
      _rerunRequested = false;
      _retryTimer?.cancel();
      _retryTimer = null;
      _drainNetworkFailure();

      await _step('exercises.flush', _exercises.flush);
      await _step('exercises.pull', _exercises.pull);
      await _step('plans.flush', _plans.flush);
      await _step('plans.pull', _plans.pull);
      await _step('sessions.flush', _sessions.flush);
      // Treningi i usunięcia z innych urządzeń (historia, statystyki).
      await _step('sessions.pull', _sessions.pull);

      // Pełny cykl bez błędów sieci — jesteśmy online.
      _offline = _drainNetworkFailure();
    } while (_rerunRequested && !_stopped);
  }

  Future<void> _step(String name, Future<void> Function() action) async {
    if (_stopped) return;
    try {
      await action();
    } catch (error, stackTrace) {
      developer.log(
        'Sync step $name failed',
        name: 'SyncCoordinator',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  bool _drainNetworkFailure() {
    var network = false;
    for (final engine in _engines) {
      final failure = engine.takeTransientFailure();
      if (failure != null && isNetworkFailure(failure)) network = true;
    }
    return network;
  }

  bool get _busy =>
      _running != null ||
      _engines.any((engine) => engine.activeRuns.value > 0);

  void _onEngineActivity() {
    if (_stopped) return;
    _evaluateDebounce?.cancel();
    // Zlewamy serię zmian silników (flush + pull) w jedno odświeżenie
    // wskaźnika zamiast liczyć backlog po każdym microtasku.
    _evaluateDebounce = Timer(const Duration(milliseconds: 180), () {
      _evaluateDebounce = null;
      unawaited(_evaluate());
    });
  }

  Future<void> _evaluate() async {
    if (_stopped) return;
    if (_busy) {
      _publish(_status.value.copyWith(phase: SyncPhase.syncing));
      return;
    }

    final seq = ++_evaluationSeq;
    ({int pending, int failed})? backlog;
    try {
      backlog = await _localDb.countSyncBacklog();
    } catch (_) {
      backlog = null; // baza jest zamykana
    }
    if (backlog == null || _stopped || seq != _evaluationSeq) return;
    if (_busy) {
      _publish(_status.value.copyWith(phase: SyncPhase.syncing));
      return;
    }

    // Zapisy z ekranów wysyłają się poza pełnym cyklem — ich błędy sieci też
    // mówią, że jesteśmy offline.
    if (_drainNetworkFailure()) _offline = true;
    if (backlog.pending == 0) _offline = false;

    final SyncPhase phase;
    if (backlog.failed > 0) {
      phase = SyncPhase.error;
    } else if (backlog.pending > 0) {
      phase = _offline ? SyncPhase.offline : SyncPhase.pending;
    } else {
      phase = SyncPhase.idle;
    }

    final previous = _status.value;
    final justSynced =
        backlog.pending == 0 &&
        (_passFinishedSinceEvaluation || previous.phase != SyncPhase.idle);
    _passFinishedSinceEvaluation = false;

    _publish(
      SyncStatus(
        phase: phase,
        pendingCount: backlog.pending,
        failedCount: backlog.failed,
        lastSyncedAt: justSynced ? DateTime.now() : previous.lastSyncedAt,
      ),
    );

    if (backlog.pending > 0) {
      _scheduleRetry();
    } else {
      _retryTimer?.cancel();
      _retryTimer = null;
      _retryDelay = initialRetryDelay;
    }
  }

  void _scheduleRetry() {
    if (_stopped || _retryTimer != null) return;
    final delay = _retryDelay;
    final doubled = delay * 2;
    _retryDelay = doubled > maxRetryDelay ? maxRetryDelay : doubled;
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      unawaited(syncNow());
    });
  }

  void _publish(SyncStatus next) {
    if (_stopped) return;
    _status.value = next;
  }
}
