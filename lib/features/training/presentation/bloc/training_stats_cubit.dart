import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/models/training_session.dart';
import '../../domain/models/training_stats.dart';
import '../../domain/repositories/training_stats_repository.dart';
import '../../domain/services/stats/personal_records_calculator.dart';
import '../../domain/services/stats/training_stats_calculator.dart';

class TrainingStatsState {
  const TrainingStatsState({
    this.range = StatsRange.month,
    this.offset = 0,
    this.customRange,
    this.snapshot,
    this.loading = true,
    this.failed = false,
    this.recordsBySession = const {},
    this.sessions = const [],
    this.records,
  });

  final StatsRange range;

  /// Ile okresów kalendarzowych wstecz (tydzień/miesiąc/rok); 0 = bieżący.
  final int offset;

  /// Ostatnio wybrane daty z kalendarza; ma sens przy [StatsRange.custom],
  /// ale zostaje po przełączeniu na inny zakres, żeby dało się do nich wrócić.
  final StatsDateRange? customRange;

  /// `null` do pierwszego udanego wczytania.
  final TrainingStatsSnapshot? snapshot;
  final bool loading;

  /// Wczytanie się nie udało i nie ma czego pokazać.
  final bool failed;

  /// Ile rekordów padło w danej sesji (z całej historii, niezależnie od
  /// zakresu). Klucz to zarówno identyfikator serwerowy, jak i lokalny, więc
  /// pasuje do pozycji listy historii przed synchronizacją i po niej.
  final Map<String, int> recordsBySession;

  /// Wszystkie ukończone sesje z telefonu i rekordy z całej historii — te
  /// same dane, z których liczą się statystyki. Lista sesji w Historii
  /// korzysta z nich, zamiast czytać bazę i liczyć rekordy drugi raz.
  /// `records` to `null` do pierwszego udanego wczytania.
  final List<TrainingSession> sessions;
  final PersonalRecordsResult? records;

  TrainingStatsState copyWith({
    StatsRange? range,
    int? offset,
    StatsDateRange? customRange,
    TrainingStatsSnapshot? snapshot,
    bool? loading,
    bool? failed,
    Map<String, int>? recordsBySession,
    List<TrainingSession>? sessions,
    PersonalRecordsResult? records,
  }) {
    return TrainingStatsState(
      range: range ?? this.range,
      offset: offset ?? this.offset,
      customRange: customRange ?? this.customRange,
      snapshot: snapshot ?? this.snapshot,
      loading: loading ?? this.loading,
      failed: failed ?? this.failed,
      recordsBySession: recordsBySession ?? this.recordsBySession,
      sessions: sessions ?? this.sessions,
      records: records ?? this.records,
    );
  }
}

/// Statystyki liczone lokalnie z całej historii. Sesje wczytuje raz (i po
/// sygnale zmiany danych) — zmiana zakresu tylko przelicza gotowe dane.
///
/// Przy dużej historii ([isolateThreshold] sesji i więcej) liczenie idzie do
/// osobnego wątku, żeby przełączanie zakresów nie przycinało ekranu.
class TrainingStatsCubit extends Cubit<TrainingStatsState> {
  TrainingStatsCubit(
    this._repository, {
    Listenable? dataChanges,
    DateTime Function()? clock,
    StatsRange initialRange = StatsRange.month,
    Future<int?> Function()? weeklyGoalLoader,
  }) : _dataChanges = dataChanges,
       _clock = clock ?? DateTime.now,
       _weeklyGoalLoader = weeklyGoalLoader,
       super(TrainingStatsState(range: initialRange)) {
    _dataChanges?.addListener(_onDataChanged);
  }

  /// Od tylu sesji liczymy w osobnym wątku. Poniżej narzut kopiowania danych
  /// do wątku kosztuje więcej niż samo liczenie.
  static const isolateThreshold = 300;

  static const _goalTimeout = Duration(seconds: 5);

  final TrainingStatsRepository _repository;
  final Listenable? _dataChanges;
  final DateTime Function() _clock;
  final Future<int?> Function()? _weeklyGoalLoader;

  List<TrainingSession> _sessions = const [];

  /// Rekordy zależą tylko od historii — nie przeliczamy ich przy zmianie
  /// zakresu.
  PersonalRecordsResult? _records;
  int? _weeklyGoal;
  Future<void>? _inFlight;
  bool _reloadQueued = false;

  /// Numer ostatniego zlecenia liczenia — odpowiedź z wątku, która przyszła
  /// po nowszym zleceniu, jest nieaktualna i ją porzucamy.
  int _computeSeq = 0;

  bool get _heavy => _sessions.length >= isolateThreshold;

  /// Wczytuje sesje i odświeża cel tygodniowy (np. po przeciągnięciu).
  Future<void> load() {
    unawaited(_refreshGoal());
    return _loadSessions();
  }

  Future<void> _loadSessions() {
    final inFlight = _inFlight;
    if (inFlight != null) {
      _reloadQueued = true;
      return inFlight;
    }
    final future = _load();
    _inFlight = future;
    return future.whenComplete(() {
      _inFlight = null;
      if (_reloadQueued && !isClosed) {
        _reloadQueued = false;
        unawaited(_loadSessions());
      }
    });
  }

  Future<void> _load() async {
    if (isClosed) return;
    if (state.snapshot == null && !state.loading) {
      emit(state.copyWith(loading: true, failed: false));
    }
    try {
      final sessions = await _repository.allCompletedSessions();
      if (isClosed) return;
      final now = _clock();
      // Jak w kalkulatorze: sesja „z przyszłości” (zły zegar) nie liczy się.
      final valid = [
        for (final s in sessions)
          if (!s.startedAt.isAfter(now)) s,
      ];
      final records = sessions.length >= isolateThreshold
          ? await compute(_recordsJob, valid)
          : _recordsJob(valid);
      if (isClosed) return;
      // Sesje i ich rekordy podmieniamy razem — inaczej zmiana zakresu w trakcie
      // liczenia zestawiłaby nowe sesje ze starymi rekordami.
      _sessions = sessions;
      _records = records;
      final snapshot = await _snapshotFor(
        state.range,
        state.customRange,
        state.offset,
      );
      if (isClosed || snapshot == null) return;
      emit(
        state.copyWith(
          snapshot: snapshot,
          loading: false,
          failed: false,
          recordsBySession: records.countsBySession(valid),
          sessions: sessions,
          records: records,
        ),
      );
    } catch (_) {
      if (isClosed) return;
      emit(
        TrainingStatsState(
          range: state.range,
          offset: state.offset,
          customRange: state.customRange,
          snapshot: state.snapshot,
          loading: false,
          failed: state.snapshot == null,
          recordsBySession: state.recordsBySession,
          sessions: state.sessions,
          records: state.records,
        ),
      );
    }
  }

  Future<void> _refreshGoal() async {
    final loader = _weeklyGoalLoader;
    if (loader == null) return;
    try {
      final goal = await loader().timeout(_goalTimeout);
      if (isClosed || goal == _weeklyGoal) return;
      _weeklyGoal = goal;
      // Bez wczytanych sesji cel dołączy się przy pierwszym liczeniu.
      if (_records == null || state.snapshot == null) return;
      final snapshot = await _snapshotFor(
        state.range,
        state.customRange,
        state.offset,
      );
      if (isClosed || snapshot == null) return;
      emit(state.copyWith(snapshot: snapshot, loading: false));
    } catch (_) {
      // Cel to dodatek — bez sieci karta celu po prostu się nie pokaże.
    }
  }

  void selectRange(StatsRange range) {
    if (range == StatsRange.custom) {
      final saved = state.customRange;
      if (saved != null) selectCustomRange(saved);
      return;
    }
    if (range == state.range && state.offset == 0) return;
    _switchTo(range, state.customRange, 0);
  }

  /// Strzałki okresu: [delta] -1 = wcześniejszy, +1 = późniejszy. Nie wychodzi
  /// poza bieżący okres ani poza początek historii.
  void shiftPeriod(int delta) {
    // Dopóki snapshot nie dogonił wybranego okresu (liczenie w wątku), strzałki
    // nie działają — `hasEarlier` pochodziłoby ze starego okna.
    if (state.snapshot?.offset != state.offset) return;
    final next = state.offset - delta;
    if (next < 0) return;
    if (delta < 0 && !(state.snapshot?.hasEarlier ?? false)) return;
    if (state.range == StatsRange.all || state.range == StatsRange.custom) {
      return;
    }
    _switchTo(state.range, state.customRange, next);
  }

  /// Zakres z kalendarza (oba dni włącznie).
  void selectCustomRange(StatsDateRange custom) {
    if (state.range == StatsRange.custom && state.customRange == custom) {
      return;
    }
    _switchTo(StatsRange.custom, custom, 0);
  }

  void _switchTo(StatsRange range, StatsDateRange? custom, int offset) {
    // Przed pierwszym wczytaniem liczyć nie ma z czego — zakres zapamiętany,
    // policzy go [load].
    if (_records == null) {
      emit(state.copyWith(range: range, customRange: custom, offset: offset));
      return;
    }
    if (!_heavy) {
      emit(
        state.copyWith(
          range: range,
          offset: offset,
          customRange: custom,
          snapshot: _computeNow(range, custom, offset),
        ),
      );
      return;
    }
    // Pasek zakresów reaguje od razu; wykresy dopiero, gdy wątek skończy.
    emit(state.copyWith(range: range, customRange: custom, offset: offset));
    unawaited(_recompute(range, custom, offset));
  }

  Future<void> _recompute(
    StatsRange range,
    StatsDateRange? custom,
    int offset,
  ) async {
    try {
      final snapshot = await _snapshotFor(range, custom, offset);
      if (isClosed || snapshot == null) return;
      emit(state.copyWith(snapshot: snapshot, loading: false));
    } catch (_) {
      // Porażka liczenia w tle nie może zostawić ekranu w stanie ładowania:
      // zostaje poprzedni snapshot (albo błąd, gdy nie ma żadnego).
      if (isClosed) return;
      emit(
        TrainingStatsState(
          range: state.range,
          offset: state.offset,
          customRange: state.customRange,
          snapshot: state.snapshot,
          loading: false,
          failed: state.snapshot == null,
          recordsBySession: state.recordsBySession,
          sessions: state.sessions,
          records: state.records,
        ),
      );
    }
  }

  /// Snapshot dla zakresu albo `null`, gdy w międzyczasie zlecono nowszy.
  Future<TrainingStatsSnapshot?> _snapshotFor(
    StatsRange range,
    StatsDateRange? custom,
    int offset,
  ) async {
    final seq = ++_computeSeq;
    if (!_heavy) return _computeNow(range, custom, offset);
    while (true) {
      final goal = _weeklyGoal;
      final result = await compute(
        _snapshotJob,
        _SnapshotArgs(
          sessions: _sessions,
          range: range,
          customRange: custom,
          offset: offset,
          now: _clock(),
          records: _records,
          weeklyGoal: goal,
        ),
      );
      if (seq != _computeSeq) return null;
      // Cel z profilu mógł dojść, gdy wątek jeszcze liczył — bez ponowienia
      // pierwszy ekran zostałby bez karty celu aż do kolejnej zmiany.
      if (goal == _weeklyGoal) return result;
    }
  }

  TrainingStatsSnapshot _computeNow(
    StatsRange range,
    StatsDateRange? custom,
    int offset,
  ) => TrainingStatsCalculator.compute(
    _sessions,
    range: range,
    customRange: custom,
    offset: offset,
    now: _clock(),
    records: _records,
    weeklyGoal: _weeklyGoal,
  );

  void _onDataChanged() {
    if (isClosed) return;
    // Cubit Historii żyje całą sesję aplikacji — cel zmieniony w profilu (albo
    // niewczytany, gdy pierwszy odczyt był offline) musi dołączyć się przy
    // najbliższej zmianie danych, nie dopiero po przeciągnięciu.
    unawaited(_refreshGoal());
    unawaited(_loadSessions());
  }

  @override
  Future<void> close() {
    _dataChanges?.removeListener(_onDataChanged);
    return super.close();
  }
}

PersonalRecordsResult _recordsJob(List<TrainingSession> sessions) =>
    PersonalRecordsCalculator.compute(sessions);

class _SnapshotArgs {
  const _SnapshotArgs({
    required this.sessions,
    required this.range,
    required this.customRange,
    required this.offset,
    required this.now,
    required this.records,
    required this.weeklyGoal,
  });

  final List<TrainingSession> sessions;
  final StatsRange range;
  final StatsDateRange? customRange;
  final int offset;
  final DateTime now;
  final PersonalRecordsResult? records;
  final int? weeklyGoal;
}

TrainingStatsSnapshot _snapshotJob(_SnapshotArgs a) =>
    TrainingStatsCalculator.compute(
      a.sessions,
      range: a.range,
      customRange: a.customRange,
      offset: a.offset,
      now: a.now,
      records: a.records,
      weeklyGoal: a.weeklyGoal,
    );
