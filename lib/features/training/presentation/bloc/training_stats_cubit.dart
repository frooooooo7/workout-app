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
    this.snapshot,
    this.loading = true,
    this.failed = false,
  });

  final StatsRange range;

  /// `null` do pierwszego udanego wczytania.
  final TrainingStatsSnapshot? snapshot;
  final bool loading;

  /// Wczytanie się nie udało i nie ma czego pokazać.
  final bool failed;

  TrainingStatsState copyWith({
    StatsRange? range,
    TrainingStatsSnapshot? snapshot,
    bool? loading,
    bool? failed,
  }) {
    return TrainingStatsState(
      range: range ?? this.range,
      snapshot: snapshot ?? this.snapshot,
      loading: loading ?? this.loading,
      failed: failed ?? this.failed,
    );
  }
}

/// Statystyki liczone lokalnie z całej historii. Sesje wczytuje raz (i po
/// sygnale zmiany danych) — zmiana zakresu tylko przelicza gotowe dane.
class TrainingStatsCubit extends Cubit<TrainingStatsState> {
  TrainingStatsCubit(
    this._repository, {
    Listenable? dataChanges,
    DateTime Function()? clock,
    StatsRange initialRange = StatsRange.month,
  }) : _dataChanges = dataChanges,
       _clock = clock ?? DateTime.now,
       super(TrainingStatsState(range: initialRange)) {
    _dataChanges?.addListener(_onDataChanged);
  }

  final TrainingStatsRepository _repository;
  final Listenable? _dataChanges;
  final DateTime Function() _clock;

  List<TrainingSession> _sessions = const [];

  /// Rekordy zależą tylko od historii — nie przeliczamy ich przy zmianie
  /// zakresu.
  PersonalRecordsResult? _records;
  Future<void>? _inFlight;
  bool _reloadQueued = false;

  Future<void> load() {
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
        unawaited(load());
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
      _sessions = sessions;
      final now = _clock();
      // Jak w kalkulatorze: sesja „z przyszłości” (zły zegar) nie liczy się.
      _records = PersonalRecordsCalculator.compute(
        sessions.where((s) => !s.startedAt.isAfter(now)),
      );
      emit(
        TrainingStatsState(
          range: state.range,
          snapshot: _compute(state.range),
          loading: false,
        ),
      );
    } catch (_) {
      if (isClosed) return;
      emit(
        TrainingStatsState(
          range: state.range,
          snapshot: state.snapshot,
          loading: false,
          failed: state.snapshot == null,
        ),
      );
    }
  }

  void selectRange(StatsRange range) {
    if (range == state.range) return;
    // Przed pierwszym wczytaniem liczyć nie ma z czego — zakres zapamiętany,
    // policzy go [load].
    if (_records == null) {
      emit(state.copyWith(range: range));
      return;
    }
    emit(state.copyWith(range: range, snapshot: _compute(range)));
  }

  TrainingStatsSnapshot _compute(StatsRange range) =>
      TrainingStatsCalculator.compute(
        _sessions,
        range: range,
        now: _clock(),
        records: _records,
      );

  void _onDataChanged() {
    if (isClosed) return;
    unawaited(load());
  }

  @override
  Future<void> close() {
    _dataChanges?.removeListener(_onDataChanged);
    return super.close();
  }
}
