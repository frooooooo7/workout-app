import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/models/training_summary_stats.dart';
import '../../domain/repositories/training_stats_repository.dart';
import '../../domain/services/training_summary_calculator.dart';

class TrainingSummaryState {
  const TrainingSummaryState({
    this.summary,
    this.loading = true,
    this.failed = false,
  });

  /// `null` do pierwszego udanego wczytania.
  final TrainingSummary? summary;
  final bool loading;
  final bool failed;
}

/// Podsumowanie tygodnia i miesiąca liczone lokalnie. Odświeża się samo po
/// sygnale zmiany danych sesji.
class TrainingSummaryCubit extends Cubit<TrainingSummaryState> {
  TrainingSummaryCubit(
    this._repository, {
    Listenable? dataChanges,
    DateTime Function()? clock,
  }) : _dataChanges = dataChanges,
       _clock = clock ?? DateTime.now,
       super(const TrainingSummaryState()) {
    _dataChanges?.addListener(_onDataChanged);
  }

  final TrainingStatsRepository _repository;
  final Listenable? _dataChanges;
  final DateTime Function() _clock;
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
    if (state.summary == null && !state.loading) {
      emit(const TrainingSummaryState());
    }
    try {
      final now = _clock();
      final sessions = await _repository.completedSessionsSince(
        TrainingSummaryCalculator.earliestStart(now),
      );
      if (isClosed) return;
      emit(
        TrainingSummaryState(
          summary: TrainingSummaryCalculator.summarize(sessions, now: now),
          loading: false,
        ),
      );
    } catch (_) {
      if (isClosed) return;
      emit(
        TrainingSummaryState(
          summary: state.summary,
          loading: false,
          failed: state.summary == null,
        ),
      );
    }
  }

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
