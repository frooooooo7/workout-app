import '../models/training_history_models.dart';

abstract class TrainingHistoryRepository {
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

