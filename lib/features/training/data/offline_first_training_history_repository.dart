import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

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
/// * Jest cache — oddajemy go od razu (stale-while-revalidate), a sieć
///   odświeża zapis w tle. Gdy odpowiedź różni się od cache, [onFreshData]
///   daje znać ekranom, żeby przeczytały dane jeszcze raz.
/// * Brak cache — czekamy na sieć. Błąd: lokalne sesje, a bez nich wyjątek.
/// * Treningi zakończone offline (jeszcze niewysłane) są dokładane do
///   pierwszej strony wyników, więc od razu widać je w historii; niewysłana
///   edycja zastępuje starszą wersję z serwera.
/// * Treningi usunięte na tym urządzeniu (usunięcie czeka na wysyłkę) są
///   ukrywane na każdej stronie — z sieci i z cache.
class OfflineFirstTrainingHistoryRepository implements TrainingHistoryRepository {
  OfflineFirstTrainingHistoryRepository({
    required TrainingHistoryRemoteDataSource remote,
    required TrainingHistoryLocalCache localCache,
    TrainingSessionLocalHistory? localSessions,
    VoidCallback? onFreshData,
    this.freshDataDebounce = const Duration(milliseconds: 300),
  })  : _remote = remote,
        _localCache = localCache,
        _localSessions = localSessions,
        _onFreshData = onFreshData;

  final TrainingHistoryRemoteDataSource _remote;
  final TrainingHistoryLocalCache _localCache;
  final TrainingSessionLocalHistory? _localSessions;
  final VoidCallback? _onFreshData;
  final _inFlightLists = <String, Future<TrainingSessionPage>>{};

  /// Kilka odpowiedzi odświeżonych w tle naraz (np. wszystkie strony
  /// miesiąca) daje jedno powiadomienie zamiast serii przeładowań ekranów.
  final Duration freshDataDebounce;
  Timer? _freshDataTimer;

  @override
  Future<TrainingSessionPage> getSessions({
    String? cursor,
    int limit = 20,
    TrainingSessionStatus? status,
    String? planId,
    String? query,
    DateTime? from,
    DateTime? to,
  }) {
    final cacheKey = _buildListCacheKey(
      cursor: cursor,
      limit: limit,
      status: status,
      planId: planId,
      query: query,
      from: from,
      to: to,
    );
    final inFlight = _inFlightLists[cacheKey];
    if (inFlight != null) return inFlight;

    final future = _getSessionsForKey(
      cacheKey: cacheKey,
      cursor: cursor,
      limit: limit,
      status: status,
      planId: planId,
      query: query,
      from: from,
      to: to,
    );
    _inFlightLists[cacheKey] = future;
    return future.whenComplete(() {
      if (identical(_inFlightLists[cacheKey], future)) {
        _inFlightLists.remove(cacheKey);
      }
    });
  }

  Future<TrainingSessionPage> _getSessionsForKey({
    required String cacheKey,
    String? cursor,
    required int limit,
    TrainingSessionStatus? status,
    String? planId,
    String? query,
    DateTime? from,
    DateTime? to,
  }) async {
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
          final payload = _remote.pageToCachedJson(fresh);
          await _localCache.saveListResponse(
            cacheKey: cacheKey,
            payload: payload,
            updatedAt: DateTime.now().toUtc(),
          );
          return (fresh, payload);
        },
        readCache: () => _localCache.readListResponse(cacheKey),
        decodeCache: _remote.pageFromCachedJson,
      );
      final visible = await _withoutPendingDeletions(page);
      if (!isFirstPage) return visible;
      return await _withLocalSessions(
        visible,
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
    if ((await _pendingDeletionIds()).contains(sessionId)) {
      throw const ApiException('session_deleted', statusCode: 410);
    }
    final local = await _findLocal(sessionId);
    if (local != null && _isUnconfirmed(local)) {
      // Serwer jeszcze nie ma tej sesji (albo ma jej starszą wersję).
      return trainingSessionDetailFromSession(local);
    }

    try {
      return await _preferFresh<TrainingSessionDetail>(
        fetch: () async {
          final detail = await _remote.getSessionDetail(sessionId);
          final payload = _remote.detailToCachedJson(detail);
          await _localCache.saveSessionDetail(
            sessionId: sessionId,
            payload: payload,
            updatedAt: detail.updatedAt,
          );
          return (detail, payload);
        },
        readCache: () => _localCache.readSessionDetail(sessionId),
        decodeCache: _remote.detailFromCachedJson,
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

  /// [fetch] pobiera dane i zapisuje je w cache, zwracając też zapisany
  /// payload — po nim poznajemy, czy serwer odesłał coś nowego.
  Future<T> _preferFresh<T extends Object>({
    required Future<(T, Map<String, dynamic>)> Function() fetch,
    required Future<Map<String, dynamic>?> Function() readCache,
    required T Function(Map<String, dynamic> payload) decodeCache,
  }) async {
    // Cache najpierw — inaczej szybki mock zapisze odpowiedź, a my
    // odczytalibyśmy ją jako „stary” cache w tym samym wywołaniu.
    final cachedPayload = await _readSafely(readCache);
    final cached = cachedPayload == null
        ? null
        : _decodeSafely(() => decodeCache(cachedPayload));
    final remote = fetch();
    if (cachedPayload == null || cached == null) {
      final (fresh, _) = await remote;
      return fresh;
    }
    unawaited(
      remote.then<void>(
        (result) {
          final (_, freshPayload) = result;
          if (!_samePayload(cachedPayload, freshPayload)) {
            _scheduleFreshDataNotice();
          }
        },
        onError: (Object _) {},
      ),
    );
    return cached;
  }

  bool _samePayload(Map<String, dynamic> a, Map<String, dynamic> b) =>
      jsonEncode(a) == jsonEncode(b);

  void _scheduleFreshDataNotice() {
    final notify = _onFreshData;
    if (notify == null || (_freshDataTimer?.isActive ?? false)) return;
    _freshDataTimer = Timer(freshDataDebounce, notify);
  }

  Future<T?> _readSafely<T extends Object>(Future<T?> Function() read) async {
    try {
      return await read();
    } catch (_) {
      return null;
    }
  }

  T? _decodeSafely<T extends Object>(T Function() decode) {
    try {
      return decode();
    } catch (_) {
      return null;
    }
  }

  // ── Local sessions ────────────────────────────────────────────────────────

  Future<Set<String>> _pendingDeletionIds() async {
    final localSessions = _localSessions;
    if (localSessions == null) return const {};
    return await _readSafely(localSessions.pendingDeletionIds) ?? const {};
  }

  Future<TrainingSessionPage> _withoutPendingDeletions(
    TrainingSessionPage page,
  ) async {
    if (page.items.isEmpty) return page;
    final hidden = await _pendingDeletionIds();
    if (hidden.isEmpty) return page;
    final items = [
      for (final item in page.items)
        if (!hidden.contains(item.id)) item,
    ];
    if (items.length == page.items.length) return page;
    return TrainingSessionPage(
      items: items,
      nextCursor: page.nextCursor,
      hasMore: page.hasMore,
      isFromCache: page.isFromCache,
    );
  }

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
  /// wysłane (i pobrane z serwera), bo cache może być starszy niż
  /// synchronizacja. Sesja obecna już na stronie nie jest dublowana — jeśli
  /// ma niewysłaną edycję, zastępuje wersję serwera. Sesje starsze niż
  /// najstarsza pozycja strony (gdy są kolejne strony) pomijamy — pojawią się
  /// na swojej stronie, bez duplikatów.
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

      final knownStarts = {
        for (final item in page.items) item.startedAt.millisecondsSinceEpoch,
      };
      DateTime? oldest;
      for (final item in page.items) {
        if (oldest == null || item.startedAt.isBefore(oldest)) {
          oldest = item.startedAt;
        }
      }

      // Pozycje strony po id; niewysłana edycja podmienia albo (gdy już nie
      // pasuje do filtrów) usuwa pozycję serwera.
      final byId = <String, TrainingSessionListItem?>{
        for (final item in page.items) item.id: item,
      };
      final extras = <TrainingSessionListItem>[];
      var changed = false;
      for (final session in locals) {
        final matches = _matchesFilters(session, planId: planId, query: query);
        final key = byId.containsKey(session.id)
            ? session.id
            : (session.serverId != null && byId.containsKey(session.serverId)
                  ? session.serverId
                  : null);
        if (key != null) {
          final pending = session.pendingOp;
          if (pending == 'create' || pending == 'update') {
            byId[key] = matches
                ? trainingSessionListItemFromSession(session)
                : null;
            changed = true;
          }
          continue;
        }
        if (!matches ||
            // Ta sama sesja po zgubionej odpowiedzi na POST (inne id).
            knownStarts.contains(session.startedAt.millisecondsSinceEpoch) ||
            (page.hasMore &&
                oldest != null &&
                session.startedAt.isBefore(oldest))) {
          continue;
        }
        extras.add(trainingSessionListItemFromSession(session));
        changed = true;
      }
      if (!changed) return page;

      final items = [...byId.values.whereType<TrainingSessionListItem>(), ...extras]
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
