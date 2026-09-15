import '../../../training/domain/models/training_history_models.dart';
import 'feed_post.dart';

/// Szczegóły posta: dane z feedu + pełna lista ćwiczeń z seriami.
class PostDetail {
  const PostDetail({required this.post, required this.exercises});

  final FeedPost post;
  final List<TrainingExerciseDetail> exercises;

  /// Model odczytu historii — dzięki niemu ekran posta używa tych samych
  /// widgetów co szczegóły sesji (nagłówek z metrykami, mapa mięśni, karty
  /// ćwiczeń).
  TrainingSessionDetail toSessionDetail() {
    return TrainingSessionDetail(
      id: post.id,
      startedAt: post.startedAt,
      endedAt: post.finishedAt,
      durationSec: post.durationSec,
      status: TrainingSessionStatus.completed,
      plan: TrainingPlanSummary(id: '', name: post.title),
      note: post.note,
      exercises: exercises,
      updatedAt: post.finishedAt ?? post.startedAt,
      sharedToProfile: true,
    );
  }
}

class KudosResult {
  const KudosResult({required this.hasKudoed, required this.kudosCount});

  final bool hasKudoed;
  final int kudosCount;
}
