import '../models/custom_training_plan.dart';

abstract interface class TrainingPlanRepository {
  Future<List<CustomTrainingPlan>> getAll();

  /// Resolves a plan by its local id or by the server id stored for it.
  Future<CustomTrainingPlan?> getById(String id);

  Future<CustomTrainingPlan> create(CustomTrainingPlan plan);

  Future<CustomTrainingPlan> update(CustomTrainingPlan plan);

  Future<void> delete(String id);
}
