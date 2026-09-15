import '../../../library/domain/models/exercise.dart';
import '../../../training/domain/models/training_history_models.dart';
import 'feed_author.dart';

/// Najważniejsze ćwiczenie posta — linia na karcie w feedzie.
class TopExercise {
  const TopExercise({
    required this.name,
    required this.completedSets,
    this.bestSet,
  });

  final String name;
  final int completedSets;

  /// Najlepsza seria (ciężar × powtórzenia); `null` bez zalogowanych liczb.
  final TrainingSetMetrics? bestSet;
}

/// Post w feedzie = ukończony i udostępniony trening. [id] to id sesji.
class FeedPost {
  const FeedPost({
    required this.id,
    required this.author,
    required this.title,
    this.note,
    required this.startedAt,
    this.finishedAt,
    this.durationSec = 0,
    this.exercisesCount = 0,
    this.completedSetsCount = 0,
    this.totalVolumeKg = 0,
    this.muscles = const [],
    this.topExercises = const [],
    this.kudosCount = 0,
    this.commentCount = 0,
    this.hasKudoed = false,
    this.isOwn = false,
    this.recentKudos = const [],
  });

  final String id;
  final FeedAuthor author;
  final String title;
  final String? note;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final int durationSec;
  final int exercisesCount;
  final int completedSetsCount;
  final double totalVolumeKg;
  final List<MuscleGroup> muscles;
  final List<TopExercise> topExercises;
  final int kudosCount;
  final int commentCount;
  final bool hasKudoed;
  final bool isOwn;

  /// Kilka ostatnich osób, które dały kudosa (stos awatarów).
  final List<FeedAuthor> recentKudos;

  FeedPost copyWith({
    int? kudosCount,
    int? commentCount,
    bool? hasKudoed,
    List<FeedAuthor>? recentKudos,
  }) {
    return FeedPost(
      id: id,
      author: author,
      title: title,
      note: note,
      startedAt: startedAt,
      finishedAt: finishedAt,
      durationSec: durationSec,
      exercisesCount: exercisesCount,
      completedSetsCount: completedSetsCount,
      totalVolumeKg: totalVolumeKg,
      muscles: muscles,
      topExercises: topExercises,
      kudosCount: kudosCount ?? this.kudosCount,
      commentCount: commentCount ?? this.commentCount,
      hasKudoed: hasKudoed ?? this.hasKudoed,
      isOwn: isOwn,
      recentKudos: recentKudos ?? this.recentKudos,
    );
  }

  /// Nowy stan kudosa. Gdy znamy zalogowanego użytkownika ([me]), jego awatar
  /// trafia na początek stosu (albo z niego znika).
  FeedPost withKudos({
    required bool hasKudoed,
    required int kudosCount,
    FeedAuthor? me,
  }) {
    var recent = recentKudos;
    if (me != null) {
      final others = recent.where((a) => a.id != me.id);
      recent = List.unmodifiable(hasKudoed ? [me, ...others] : others);
    }
    return copyWith(
      hasKudoed: hasKudoed,
      kudosCount: kudosCount < 0 ? 0 : kudosCount,
      recentKudos: recent,
    );
  }

  FeedPost withCommentDelta(int delta) {
    final next = commentCount + delta;
    return copyWith(commentCount: next < 0 ? 0 : next);
  }
}
