import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/models/training_history_models.dart';
import '../../domain/models/training_session.dart';
import '../../domain/repositories/training_history_repository.dart';
import '../../domain/repositories/training_stats_repository.dart';
import '../../domain/services/history_feed_builder.dart';
import '../../domain/services/stats/personal_records_calculator.dart';

class HistoryFeedState {
  const HistoryFeedState({
    this.entries = const [],
    this.loading = true,
    this.failed = false,
    this.fromServer = false,
  });

  /// Treningi od najnowszego.
  final List<HistoryFeedEntry> entries;

  /// Trwa pierwsze wczytanie.
  final bool loading;

  /// Nie ma czego pokazać i wczytanie się nie udało.
  final bool failed;

  /// Telefon nie miał jeszcze żadnych sesji (świeże logowanie przed pierwszą
  /// synchronizacją) — lista pochodzi z serwera i nie niesie ćwiczeń.
  final bool fromServer;
}

/// Lista treningów Historii: ukończone sesje z lokalnej bazy razem z ich
/// ćwiczeniami i rekordami — działa offline i nie czeka na sieć.
///
/// Gdy baza jest jeszcze pusta, bierze listę z serwera (bez ćwiczeń na
/// kartach). Sesje i rekordy liczą się w osobnym wątku przy dużej historii,
/// tak jak statystyki.
class HistoryFeedCubit extends Cubit<HistoryFeedState> {
  /// [dataChanges] — sygnał synchronizacji sesji; zmiana danych przelicza
  /// listę od nowa.
  HistoryFeedCubit(
    this._stats,
    this._history, {
    Listenable? dataChanges,
    DateTime Function()? clock,
  }) : _dataChanges = dataChanges,
       _clock = clock ?? DateTime.now,
       super(const HistoryFeedState()) {
    _dataChanges?.addListener(_onDataChanged);
  }

  /// Od tylu sesji liczymy w osobnym wątku — jak w `TrainingStatsCubit`.
  static const isolateThreshold = 300;

  /// Zabezpieczenie przed pętlą, gdyby serwer zwracał kursor w nieskończoność.
  static const _maxServerPages = 6;

  final TrainingStatsRepository _stats;
  final TrainingHistoryRepository _history;
  final Listenable? _dataChanges;
  final DateTime Function() _clock;

  Future<void>? _inFlight;
  bool _reloadQueued = false;

  /// Wczytuje (albo przelicza) listę. Kolejne wywołania w trakcie liczenia
  /// zlewają się w jedno dodatkowe przeliczenie.
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
    try {
      final sessions = await _stats.allCompletedSessions();
      if (isClosed) return;
      if (sessions.isNotEmpty) {
        final entries = await _build(sessions);
        if (isClosed) return;
        emit(HistoryFeedState(entries: entries, loading: false));
        return;
      }
    } on Object catch (error, stackTrace) {
      developer.log(
        'Local history read failed, falling back to the server list',
        name: 'HistoryFeedCubit',
        error: error,
        stackTrace: stackTrace,
      );
    }
    await _loadFromServer();
  }

  Future<List<HistoryFeedEntry>> _build(List<TrainingSession> sessions) async {
    final args = _FeedArgs(sessions: sessions, now: _clock());
    return sessions.length >= isolateThreshold
        ? compute(_feedJob, args)
        : _feedJob(args);
  }

  Future<void> _loadFromServer() async {
    try {
      final items = <TrainingSessionListItem>[];
      String? cursor;
      for (var page = 0; page < _maxServerPages; page++) {
        final result = await _history.getSessions(
          cursor: cursor,
          limit: TrainingHistoryRepository.maxPageSize,
          status: TrainingSessionStatus.completed,
        );
        items.addAll(result.items);
        cursor = result.nextCursor;
        if (!result.hasMore || cursor == null || cursor.isEmpty) break;
      }
      if (isClosed) return;
      items.sort((a, b) => b.startedAt.compareTo(a.startedAt));
      emit(
        HistoryFeedState(
          entries: [
            for (final item in items) historyFeedEntryFromListItem(item),
          ],
          loading: false,
          fromServer: items.isNotEmpty,
        ),
      );
    } on Object catch (error, stackTrace) {
      developer.log(
        'Training history load failed',
        name: 'HistoryFeedCubit',
        error: error,
        stackTrace: stackTrace,
      );
      if (isClosed) return;
      // Zostaje to, co już było na ekranie; błąd tylko wtedy, gdy nic nie ma.
      emit(
        HistoryFeedState(
          entries: state.entries,
          loading: false,
          failed: state.entries.isEmpty,
          fromServer: state.fromServer,
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

class _FeedArgs {
  const _FeedArgs({required this.sessions, required this.now});

  final List<TrainingSession> sessions;
  final DateTime now;
}

/// Rekordy liczone jak w statystykach: sesja „z przyszłości” (zły zegar)
/// nie bije rekordów.
List<HistoryFeedEntry> _feedJob(_FeedArgs args) {
  final valid = [
    for (final s in args.sessions)
      if (!s.startedAt.isAfter(args.now)) s,
  ];
  return buildHistoryFeed(
    args.sessions,
    PersonalRecordsCalculator.compute(valid),
  );
}
