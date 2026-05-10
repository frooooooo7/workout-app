import '../models/custom_training_plan.dart';

abstract interface class TrainingPlanRepository {
  Future<List<CustomTrainingPlan>> getAll();

  Future<CustomTrainingPlan> create(CustomTrainingPlan plan);

  Future<CustomTrainingPlan> update(CustomTrainingPlan plan);

  Future<void> delete(String id);
}
