import '../../../core/network/api_client.dart';
import '../domain/models/training_history_models.dart';
import '../domain/repositories/training_history_repository.dart';
import 'training_history_local_cache.dart';
import 'training_history_remote_data_source.dart';

class OfflineFirstTrainingHistoryRepository implements TrainingHistoryRepository {
  const OfflineFirstTrainingHistoryRepository({
    required TrainingHistoryRemoteDataSource remote,
    required TrainingHistoryLocalCache localCache,
  })  : _remote = remote,
        _localCache = localCache;

  final TrainingHistoryRemoteDataSource _remote;
  final TrainingHistoryLocalCache _localCache;

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
    try {
      final page = await _remote.getSessions(
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
        payload: _remote.pageToCachedJson(page),
        updatedAt: DateTime.now().toUtc(),
      );
      return page;
    } on ApiException catch (error) {
      if (error.message != 'network_error') rethrow;
      final cached = await _localCache.readListResponse(cacheKey);
      if (cached == null) rethrow;
      return _remote.pageFromCachedJson(cached);
    }
  }

  @override
  Future<TrainingSessionDetail> getSessionDetail(String sessionId) async {
    try {
      final detail = await _remote.getSessionDetail(sessionId);
      await _localCache.saveSessionDetail(
        sessionId: sessionId,
        payload: _remote.detailToCachedJson(detail),
        updatedAt: detail.updatedAt,
      );
      return detail;
    } on ApiException catch (error) {
      if (error.message != 'network_error') rethrow;
      final cached = await _localCache.readSessionDetail(sessionId);
      if (cached == null) rethrow;
      return _remote.detailFromCachedJson(cached);
    }
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

