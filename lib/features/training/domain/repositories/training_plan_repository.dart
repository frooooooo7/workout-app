import '../models/custom_training_plan.dart';
import '../models/post_draft.dart';

abstract interface class TrainingPlanRepository {
  Future<List<CustomTrainingPlan>> getAll();

  /// Resolves a plan by its local id or by the server id stored for it.
  Future<CustomTrainingPlan?> getById(String id);

  /// [cover] — co zrobić z okładką planu (wysyłana w tle, także offline).
  Future<CustomTrainingPlan> create(
    CustomTrainingPlan plan, {
    PostPhotoChange cover = const KeepPostPhoto(),
  });

  Future<CustomTrainingPlan> update(
    CustomTrainingPlan plan, {
    PostPhotoChange cover = const KeepPostPhoto(),
  });

  /// Zapisuje kolejność planów na liście ([orderedIds] od pierwszego).
  Future<void> reorder(List<String> orderedIds);

  Future<void> delete(String id);
}
