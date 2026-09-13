import '../models/custom_training_plan.dart';
import '../models/training_session.dart';

abstract interface class TrainingSessionRepository {
  Future<TrainingSession?> getActive();

  /// Szuka po `local_id` albo `server_id` — historia podaje ten drugi.
  Future<TrainingSession?> getById(String sessionId);

  Future<TrainingSession> startFromPlan(CustomTrainingPlan plan);

  Future<TrainingSession> startCustom({
    String planName = TrainingSession.defaultCustomName,
  });

  Future<TrainingSession> save(TrainingSession session);

  Future<TrainingSession> finish(String sessionId);

  Future<TrainingSession> cancel(String sessionId);

  /// Włącza/wyłącza widoczność ukończonej sesji w aktywności na profilu.
  Future<TrainingSession> setSharedToProfile(String sessionId, bool shared);
}
