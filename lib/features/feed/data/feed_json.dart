import '../../../core/network/api_client.dart';
import '../../library/domain/models/exercise.dart';
import '../../training/data/training_history_json.dart';
import '../../training/domain/models/training_history_models.dart';
import '../domain/models/cursor_page.dart';
import '../domain/models/feed_author.dart';
import '../domain/models/feed_post.dart';
import '../domain/models/post_comment.dart';
import '../domain/models/post_detail.dart';

/// Ręczne (de)serializatory feedu. `*ToJson` służą wyłącznie cache'owi
/// pierwszej strony — zapisują ten sam kształt, który zwraca API.
abstract final class FeedJson {
  static FeedAuthor authorFromJson(Map<String, dynamic> json) {
    return FeedAuthor(
      id: json['id'] as String,
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      handle: json['handle'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
    );
  }

  static Map<String, dynamic> authorToJson(FeedAuthor author) => {
    'id': author.id,
    'firstName': author.firstName,
    'lastName': author.lastName,
    'handle': author.handle,
    'avatarUrl': author.avatarUrl,
  };

  static FeedPost postFromJson(Map<String, dynamic> json) {
    return FeedPost(
      id: json['id'] as String,
      author: authorFromJson(json['author'] as Map<String, dynamic>),
      title: json['title'] as String? ?? 'Trening',
      note: _nonBlank(json['note'] as String?),
      startedAt: DateTime.parse(json['startedAt'] as String).toUtc(),
      finishedAt: DateTime.tryParse(json['finishedAt'] as String? ?? '')
          ?.toUtc(),
      durationSec: (json['durationSec'] as num?)?.toInt() ?? 0,
      exercisesCount: (json['exercisesCount'] as num?)?.toInt() ?? 0,
      completedSetsCount: (json['completedSetsCount'] as num?)?.toInt() ?? 0,
      totalVolumeKg: (json['totalVolumeKg'] as num?)?.toDouble() ?? 0,
      muscles: _musclesFromJson(json['muscles']),
      topExercises: (json['topExercises'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_topExerciseFromJson)
          .toList(growable: false),
      kudosCount: (json['kudosCount'] as num?)?.toInt() ?? 0,
      commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
      hasKudoed: json['hasKudoed'] as bool? ?? false,
      isOwn: json['isOwn'] as bool? ?? false,
      recentKudos: (json['recentKudos'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(authorFromJson)
          .toList(growable: false),
    );
  }

  static Map<String, dynamic> postToJson(FeedPost post) => {
    'id': post.id,
    'author': authorToJson(post.author),
    'title': post.title,
    'note': post.note,
    'startedAt': post.startedAt.toUtc().toIso8601String(),
    'finishedAt': post.finishedAt?.toUtc().toIso8601String(),
    'durationSec': post.durationSec,
    'exercisesCount': post.exercisesCount,
    'completedSetsCount': post.completedSetsCount,
    'totalVolumeKg': post.totalVolumeKg,
    'muscles': post.muscles.map((m) => m.name).toList(),
    'topExercises': post.topExercises
        .map(
          (e) => {
            'name': e.name,
            'completedSets': e.completedSets,
            'bestSet': e.bestSet == null
                ? null
                : {'weightKg': e.bestSet!.weightKg, 'reps': e.bestSet!.reps},
          },
        )
        .toList(),
    'kudosCount': post.kudosCount,
    'commentCount': post.commentCount,
    'hasKudoed': post.hasKudoed,
    'isOwn': post.isOwn,
    'recentKudos': post.recentKudos.map(authorToJson).toList(),
  };

  /// Pozycje, których nie da się sparsować, są pomijane — jeden zepsuty post
  /// nie może wywrócić całego feedu.
  static FeedPage feedPageFromJson(Object? data) {
    if (data is! Map<String, dynamic>) {
      throw const ApiException('invalid_response', statusCode: 200);
    }
    final items = <FeedPost>[];
    for (final raw in data['items'] as List? ?? const []) {
      if (raw is! Map<String, dynamic>) continue;
      try {
        items.add(postFromJson(raw));
      } catch (_) {
        /* pomijamy uszkodzony wpis */
      }
    }
    return FeedPage(
      items: List.unmodifiable(items),
      nextCursor: data['nextCursor'] as String?,
      hasMore: data['hasMore'] as bool? ?? false,
    );
  }

  static Map<String, dynamic> feedPageToJson(FeedPage page) => {
    'items': page.items.map(postToJson).toList(),
    'nextCursor': page.nextCursor,
    'hasMore': page.hasMore,
  };

  static PostDetail postDetailFromJson(Object? data) {
    if (data is! Map<String, dynamic>) {
      throw const ApiException('invalid_response', statusCode: 200);
    }
    return PostDetail(
      post: postFromJson(data),
      exercises: (data['exercises'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(trainingExerciseDetailFromJson)
          .toList(growable: false),
    );
  }

  static KudosResult kudosResultFromJson(Object? data) {
    if (data is! Map<String, dynamic>) {
      throw const ApiException('invalid_response', statusCode: 200);
    }
    final hasKudoed = data['hasKudoed'];
    final kudosCount = data['kudosCount'];
    if (hasKudoed is! bool || kudosCount is! num) {
      throw const ApiException('invalid_response', statusCode: 200);
    }
    return KudosResult(hasKudoed: hasKudoed, kudosCount: kudosCount.toInt());
  }

  static PostComment commentFromJson(Map<String, dynamic> json) {
    return PostComment(
      id: json['id'] as String,
      author: authorFromJson(json['author'] as Map<String, dynamic>),
      body: json['body'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
      isOwn: json['isOwn'] as bool? ?? false,
      canDelete: json['canDelete'] as bool? ?? false,
    );
  }

  static CommentsPage commentsPageFromJson(Object? data) {
    if (data is! Map<String, dynamic>) {
      throw const ApiException('invalid_response', statusCode: 200);
    }
    final items = <PostComment>[];
    for (final raw in data['items'] as List? ?? const []) {
      if (raw is! Map<String, dynamic>) continue;
      try {
        items.add(commentFromJson(raw));
      } catch (_) {
        /* pomijamy uszkodzony wpis */
      }
    }
    return CommentsPage(
      items: List.unmodifiable(items),
      nextCursor: data['nextCursor'] as String?,
      hasMore: data['hasMore'] as bool? ?? false,
    );
  }

  static TopExercise _topExerciseFromJson(Map<String, dynamic> json) {
    final best = json['bestSet'] as Map<String, dynamic>?;
    final metrics = trainingSetMetricsFromJson(best);
    return TopExercise(
      name: json['name'] as String? ?? 'Ćwiczenie',
      completedSets: (json['completedSets'] as num?)?.toInt() ?? 0,
      bestSet: metrics == null ||
              (metrics.weightKg == null && metrics.reps == null)
          ? null
          : TrainingSetMetrics(weightKg: metrics.weightKg, reps: metrics.reps),
    );
  }

  static List<MuscleGroup> _musclesFromJson(Object? raw) {
    if (raw is! List) return const [];
    final seen = <MuscleGroup>{};
    for (final value in raw) {
      final muscle = MuscleGroup.tryParse(value is String ? value : null);
      if (muscle != null && muscle != MuscleGroup.all) seen.add(muscle);
    }
    return List.unmodifiable(seen);
  }

  static String? _nonBlank(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
