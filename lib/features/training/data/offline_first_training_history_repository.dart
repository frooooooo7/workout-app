import 'dart:async';

import '../../../core/network/api_client.dart';
import '../domain/models/training_history_models.dart';
import '../domain/models/training_session.dart';
import '../domain/repositories/training_history_repository.dart';
import '../domain/services/training_session_detail_mapper.dart';
import 'training_history_local_cache.dart';
import 'training_history_remote_data_source.dart';
import 'training_session_local_history.dart';

/// Historia treningów: serwer jest źródłem prawdy, ale użytkownik nigdy nie
/// czeka na niego bez potrzeby.
///
/// * Słaby zasięg — gdy jest cache, a serwer nie odpowie w
///   [cacheGracePeriod], od razu zwracamy cache (żądanie kończy się w tle
///   i odświeża cache na następny raz).
/// * Brak sieci, błąd serwera — cache, a bez cache: lokalne sesje.
/// * Treningi zakończone offline (jeszcze niewysłane) są dokładane do
///   pierwszej strony wyników, więc od razu widać je w historii.
class OfflineFirstTrainingHistoryRepository implements TrainingHistoryRepository {
  const OfflineFirstTrainingHistoryRepository({
    required TrainingHistoryRemoteDataSource remote,
    required TrainingHistoryLocalCache localCache,
    TrainingSessionLocalHistory? localSessions,
    this.cacheGracePeriod = const Duration(milliseconds: 2500),
  })  : _remote = remote,
        _localCache = localCache,
        _localSessions = localSessions;

  final TrainingHistoryRemoteDataSource _remote;
  final TrainingHistoryLocalCache _localCache;
  final TrainingSessionLocalHistory? _localSessions;

  /// Ile czekamy na serwer, zanim pokażemy zapisany cache.
  final Duration cacheGracePeriod;

  @override
  Future<TrainingSessionPage> getSessions({
    String? cursor,
    int limit = 20,
    TrainingSessionStatus? status,
    String? planId,
    String? query,
    DateTime? from,
    DateTime? to,
  }) async {
    final cacheKey = _buildListCacheKey(
      cursor: cursor,
      limit: limit,
      status: status,
      planId: planId,
      query: query,
      from: from,
      to: to,
    );
    final isFirstPage = cursor == null || cursor.isEmpty;

    try {
      final page = await _preferFresh<TrainingSessionPage>(
        fetch: () async {
          final fresh = await _remote.getSessions(
            cursor: cursor,
            limit: limit,
            status: status,
            planId: planId,
            query: query,
            from: from,
            to: to,
          );
          await _localCache.saveListResponse(
            cacheKey: cacheKey,
            payload: _remote.pageToCachedJson(fresh),
            updatedAt: DateTime.now().toUtc(),
          );
          return fresh;
        },
        readCache: () async {
          final cached = await _localCache.readListResponse(cacheKey);
          return cached == null ? null : _remote.pageFromCachedJson(cached);
        },
      );
      if (!isFirstPage) return page;
      return await _withLocalSessions(
        page,
        status: status,
        planId: planId,
        query: query,
        from: from,
        to: to,
      );
    } on ApiException catch (error) {
      if (!isFirstPage || !_isRecoverable(error)) rethrow;
      final localOnly = await _localOnlyPage(
        status: status,
        planId: planId,
        query: query,
        from: from,
        to: to,
      );
      if (localOnly == null) rethrow;
      return localOnly;
    }
  }

  @override
  Future<TrainingSessionDetail> getSessionDetail(String sessionId) async {
    final local = await _findLocal(sessionId);
    if (local != null && _isUnconfirmed(local)) {
      // Serwer jeszcze nie ma tej sesji (albo ma jej starszą wersję).
      return trainingSessionDetailFromSession(local);
    }

    try {
      return await _preferFresh<TrainingSessionDetail>(
        fetch: () async {
          final detail = await _remote.getSessionDetail(sessionId);
          await _localCache.saveSessionDetail(
            sessionId: sessionId,
            payload: _remote.detailToCachedJson(detail),
            updatedAt: detail.updatedAt,
          );
          return detail;
        },
        readCache: () async {
          final cached = await _localCache.readSessionDetail(sessionId);
          return cached == null ? null : _remote.detailFromCachedJson(cached);
        },
      );
    } on ApiException catch (error) {
      if (local != null && _isRecoverable(error)) {
        return trainingSessionDetailFromSession(local);
      }
      rethrow;
    }
  }

  // ── Network vs cache ──────────────────────────────────────────────────────

  /// Błędy, przy których lepiej pokazać zapisane dane niż ekran błędu.
  bool _isRecoverable(ApiException error) {
    final status = error.statusCode;
    return status == null ||
        status >= 500 ||
        status == 401 ||
        status == 408 ||
        status == 429;
  }

  Future<T> _preferFresh<T extends Object>({
    required Future<T> Function() fetch,
    required Future<T?> Function() readCache,
  }) async {
    final remote = fetch();
    // Błąd żądania, na które już nie czekamy, nie może wyciec jako nieobsłużony.
    unawaited(remote.then<void>((_) {}, onError: (Object _) {}));

    final cached = await _readSafely(readCache);
    if (cached == null) return remote;

    final completer = Completer<_FetchOutcome<T>>();
    final timer = Timer(cacheGracePeriod, () {
      if (!completer.isCompleted) completer.complete(_FetchOutcome<T>.timedOut());
    });
    unawaited(
      remote.then<void>(
        (value) {
          if (!completer.isCompleted) {
            completer.complete(_FetchOutcome<T>.fresh(value));
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!completer.isCompleted) {
            completer.complete(_FetchOutcome<T>.failed(error, stackTrace));
          }
        },
      ),
    );

    final outcome = await completer.future;
    timer.cancel();

    final value = outcome.value;
    if (value != null) return value;
    final error = outcome.error;
    if (error == null) return cached; // serwer nie zdążył
    if (error is ApiException && _isRecoverable(error)) return cached;
    Error.throwWithStackTrace(error, outcome.stackTrace ?? StackTrace.current);
  }

  Future<T?> _readSafely<T extends Object>(Future<T?> Function() read) async {
    try {
      return await read();
    } catch (_) {
      return null;
    }
  }

  // ── Local sessions ────────────────────────────────────────────────────────

  bool _isUnconfirmed(TrainingSession session) =>
      session.status != TrainingSessionStatus.active &&
      session.exercises.isNotEmpty &&
      (session.pendingOp != null || session.serverId == null);

  Future<TrainingSession?> _findLocal(String sessionId) async {
    final localSessions = _localSessions;
    if (localSessions == null) return null;
    return _readSafely(() => localSessions.findById(sessionId));
  }

  bool _matchesFilters(
    TrainingSession session, {
    String? planId,
    String? query,
  }) {
    if (planId != null &&
        planId.isNotEmpty &&
        session.planServerId != planId &&
        session.planLocalId != planId) {
      return false;
    }
    final needle = query?.trim().toLowerCase();
    if (needle != null && needle.isNotEmpty) {
      final haystack = [
        session.planName,
        session.note ?? '',
        for (final exercise in session.exercises) exercise.exerciseName,
      ].join(' ').toLowerCase();
      if (!haystack.contains(needle)) return false;
    }
    return true;
  }

  /// Dokłada do pierwszej strony sesje, których nie ma w odpowiedzi serwera.
  ///
  /// Świeża odpowiedź: tylko sesje jeszcze niewysłane. Cache: także
  /// wysłane, bo cache może być starszy niż synchronizacja. Sesje starsze
  /// niż najstarsza pozycja strony (gdy są kolejne strony) pomijamy — pojawią
  /// się na swojej stronie, bez duplikatów.
  Future<TrainingSessionPage> _withLocalSessions(
    TrainingSessionPage page, {
    TrainingSessionStatus? status,
    String? planId,
    String? query,
    DateTime? from,
    DateTime? to,
  }) async {
    final localSessions = _localSessions;
    if (localSessions == null) return page;
    try {
      final locals = await localSessions.finishedSessions(
        status: status,
        from: from,
        to: to,
        includeSynced: page.isFromCache,
      );
      if (locals.isEmpty) return page;

      final knownIds = {for (final item in page.items) item.id};
      final knownStarts = {
        for (final item in page.items) item.startedAt.millisecondsSinceEpoch,
      };
      DateTime? oldest;
      for (final item in page.items) {
        if (oldest == null || item.startedAt.isBefore(oldest)) {
          oldest = item.startedAt;
        }
      }

      final extras = <TrainingSessionListItem>[
        for (final session in locals)
          if (_matchesFilters(session, planId: planId, query: query) &&
              !knownIds.contains(session.id) &&
              !knownIds.contains(session.serverId) &&
              // Ta sama sesja po zgubionej odpowiedzi na POST (inne id).
              !knownStarts.contains(session.startedAt.millisecondsSinceEpoch) &&
              !(page.hasMore &&
                  oldest != null &&
                  session.startedAt.isBefore(oldest)))
            trainingSessionListItemFromSession(session),
      ];
      if (extras.isEmpty) return page;

      final items = [...page.items, ...extras]
        ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
      return TrainingSessionPage(
        items: items,
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
        isFromCache: page.isFromCache,
      );
    } catch (_) {
      return page;
    }
  }

  /// Offline bez cache — pokaż przynajmniej treningi z tego urządzenia.
  Future<TrainingSessionPage?> _localOnlyPage({
    TrainingSessionStatus? status,
    String? planId,
    String? query,
    DateTime? from,
    DateTime? to,
  }) async {
    final localSessions = _localSessions;
    if (localSessions == null) return null;
    final locals = await _readSafely(
      () => localSessions.finishedSessions(
        status: status,
        from: from,
        to: to,
        includeSynced: true,
      ),
    );
    if (locals == null) return null;
    final items = [
      for (final session in locals)
        if (_matchesFilters(session, planId: planId, query: query))
          trainingSessionListItemFromSession(session),
    ];
    if (items.isEmpty) return null;
    return TrainingSessionPage(
      items: items,
      nextCursor: null,
      hasMore: false,
      isFromCache: true,
    );
  }

  String _buildListCacheKey({
    String? cursor,
    required int limit,
    TrainingSessionStatus? status,
    String? planId,
    String? query,
    DateTime? from,
    DateTime? to,
  }) {
    return [
      'cursor=${cursor ?? ''}',
      'limit=$limit',
      'status=${status?.name ?? ''}',
      'planId=${planId ?? ''}',
      'q=${query?.trim() ?? ''}',
      'from=${from?.toUtc().toIso8601String() ?? ''}',
      'to=${to?.toUtc().toIso8601String() ?? ''}',
    ].join('&');
  }
}

class _FetchOutcome<T extends Object> {
  _FetchOutcome._({this.value, this.error, this.stackTrace});

  factory _FetchOutcome.fresh(T value) => _FetchOutcome._(value: value);

  factory _FetchOutcome.failed(Object error, StackTrace stackTrace) =>
      _FetchOutcome._(error: error, stackTrace: stackTrace);

  factory _FetchOutcome.timedOut() => _FetchOutcome._();

  final T? value;
  final Object? error;
  final StackTrace? stackTrace;
}
