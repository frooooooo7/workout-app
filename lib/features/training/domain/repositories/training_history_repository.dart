import '../models/training_history_models.dart';

abstract class TrainingHistoryRepository {
  /// Największy `limit` akceptowany przez backend (`training-history.schemas.ts`
  /// → `max(50, "invalid_limit")`). Większa wartość kończy się odpowiedzią 400,
  /// nie pustą listą — dlatego duże zakresy trzeba stronicować kursorem.
  static const int maxPageSize = 50;

  Future<TrainingSessionPage> getSessions({
    String? cursor,
    int limit = 20,
    TrainingSessionStatus? status,
    String? planId,
    String? query,
    DateTime? from,
    DateTime? to,
  });

  Future<TrainingSessionDetail> getSessionDetail(String sessionId);
}

