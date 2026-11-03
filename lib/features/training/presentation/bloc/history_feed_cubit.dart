import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/models/training_history_models.dart';
import '../../domain/models/training_session.dart';
import '../../domain/repositories/training_history_repository.dart';
import '../../domain/services/history_feed_builder.dart';
import '../../domain/services/stats/personal_records_calculator.dart';
import 'training_stats_cubit.dart';

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
/// Sesje i rekordy bierze od [TrainingStatsCubit], który i tak czyta całą
/// historię dla Statystyk — baza jest czytana, a rekordy liczone raz. Karty
/// układają się w osobnym wątku przy dużej historii.
///
/// Gdy telefon od początku nie ma żadnych sesji (świeże logowanie przed
/// pierwszą synchronizacją), lista pochodzi z serwera i nie ma ćwiczeń na
/// kartach. Gdy sesje już były, a potem znikną (ostatni trening usunięty),
/// lista jest po prostu pusta — serwer, który o usunięciu jeszcze nie wie,
/// nie przywraca skasowanego treningu.
class HistoryFeedCubit extends Cubit<HistoryFeedState> {
  HistoryFeedCubit(this._stats, this._history)
    : super(const HistoryFeedState()) {
    _subscription = _stats.stream.listen(_onStats);
    _onStats(_stats.state);
  }

  /// Od tylu sesji kartę układa osobny wątek — jak w `TrainingStatsCubit`.
  static const isolateThreshold = TrainingStatsCubit.isolateThreshold;

  /// Zabezpieczenie przed pętlą, gdyby serwer zwracał kursor w nieskończoność.
  static const _maxServerPages = 6;

  final TrainingStatsCubit _stats;
  final TrainingHistoryRepository _history;
  late final StreamSubscription<TrainingStatsState> _subscription;

  List<TrainingSession>? _builtFrom;
  bool _hadLocalSessions = false;
  bool _serverRequested = false;

  /// Numer ostatniego zlecenia ułożenia kart — spóźniona odpowiedź z wątku
  /// po nowszym zleceniu jest nieaktualna.
  int _buildSeq = 0;

  /// Odświeża dane (przeciągnięcie listy, „Spróbuj ponownie”).
  Future<void> load() async {
    await _stats.load();
    if (isClosed) return;
    // Statystyki dały sesje — lista sama się ułoży. Inaczej próbujemy serwera
    // jeszcze raz.
    if (_stats.state.sessions.isEmpty && !_hadLocalSessions) {
      await _loadFromServer();
    }
  }

  void _onStats(TrainingStatsState stats) {
    if (isClosed) return;
    final records = stats.records;
    if (records == null) {
      // Jeszcze nic nie wczytano albo wczytanie się nie udało.
      if (stats.failed && !_serverRequested) {
        _serverRequested = true;
        unawaited(_loadFromServer());
      }
      return;
    }
    final sessions = stats.sessions;
    if (identical(sessions, _builtFrom)) return;
    _builtFrom = sessions;

    if (sessions.isEmpty) {
      if (_hadLocalSessions) {
        _buildSeq++;
        emit(const HistoryFeedState(loading: false));
      } else if (!_serverRequested) {
        _serverRequested = true;
        unawaited(_loadFromServer());
      }
      return;
    }
    _hadLocalSessions = true;
    unawaited(_build(sessions, records));
  }

  Future<void> _build(
    List<TrainingSession> sessions,
    PersonalRecordsResult records,
  ) async {
    final seq = ++_buildSeq;
    final args = _FeedArgs(sessions: sessions, records: records);
    final entries = sessions.length >= isolateThreshold
        ? await compute(_feedJob, args)
        : _feedJob(args);
    if (isClosed || seq != _buildSeq) return;
    emit(HistoryFeedState(entries: entries, loading: false));
  }

  Future<void> _loadFromServer() async {
    final seq = ++_buildSeq;
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
      // Lokalne sesje, które doszły w międzyczasie, wygrywają z serwerem.
      if (isClosed || seq != _buildSeq || _hadLocalSessions) return;
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
      if (isClosed || seq != _buildSeq || _hadLocalSessions) return;
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

  @override
  Future<void> close() {
    unawaited(_subscription.cancel());
    return super.close();
  }
}

class _FeedArgs {
  const _FeedArgs({required this.sessions, required this.records});

  final List<TrainingSession> sessions;
  final PersonalRecordsResult records;
}

List<HistoryFeedEntry> _feedJob(_FeedArgs args) =>
    buildHistoryFeed(args.sessions, args.records);
