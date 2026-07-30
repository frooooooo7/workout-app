import '../../../core/network/api_client.dart';
import '../../library/domain/models/exercise.dart';
import '../domain/models/training_history_models.dart';

class TrainingHistoryRemoteDataSource {
  const TrainingHistoryRemoteDataSource(this._api);

  final ApiClient _api;

  Future<TrainingSessionPage> getSessions({
    String? cursor,
    int limit = 20,
    TrainingSessionStatus? status,
    String? planId,
    String? query,
    DateTime? from,
    DateTime? to,
  }) async {
    final path = Uri(
      path: '/api/v1/training-sessions',
      queryParameters: {
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        'limit': '$limit',
        if (status != null) 'status': _statusToApi(status),
        if (planId != null && planId.isNotEmpty) 'planId': planId,
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        if (from != null) 'from': from.toUtc().toIso8601String(),
        if (to != null) 'to': to.toUtc().toIso8601String(),
      },
    ).toString();
    final data = await _api.get(path, auth: true) as Map<String, dynamic>;
    return _pageFromJson(data, isFromCache: false);
  }

  Future<TrainingSessionDetail> getSessionDetail(String sessionId) async {
    final data = await _api.get('/api/v1/training-sessions/$sessionId', auth: true)
        as Map<String, dynamic>;
    return _detailFromJson(data);
  }

  TrainingSessionPage pageFromCachedJson(Map<String, dynamic> json) {
    return _pageFromJson(json, isFromCache: true);
  }

  TrainingSessionDetail detailFromCachedJson(Map<String, dynamic> json) {
    return _detailFromJson(json);
  }

  Map<String, dynamic> pageToCachedJson(TrainingSessionPage page) {
    return {
      'items': page.items.map(_listItemToJson).toList(),
      'nextCursor': page.nextCursor,
      'hasMore': page.hasMore,
    };
  }

  Map<String, dynamic> detailToCachedJson(TrainingSessionDetail detail) {
    return {
      'id': detail.id,
      'startedAt': detail.startedAt.toUtc().toIso8601String(),
      'endedAt': detail.endedAt?.toUtc().toIso8601String(),
      'durationSec': detail.durationSec,
      'status': _statusToApi(detail.status),
      'plan': {
        'id': detail.plan.id,
        'name': detail.plan.name,
      },
      'note': detail.note,
      'exercises': detail.exercises.map((exercise) {
        return {
          'exerciseId': exercise.exerciseId,
          'exerciseName': exercise.exerciseName,
          'muscles': exercise.muscles.map((m) => m.name).toList(),
          'imageUrl': exercise.imageUrl,
          'sets': exercise.sets.map((set) {
            return {
              'setIndex': set.setIndex,
              'planned': _metricsToJson(set.planned),
              'actual': _metricsToJson(set.actual),
              'completed': set.completed,
              'completedAt': set.completedAt?.toUtc().toIso8601String(),
            };
          }).toList(),
        };
      }).toList(),
      'updatedAt': detail.updatedAt.toUtc().toIso8601String(),
    };
  }

  TrainingSessionPage _pageFromJson(
    Map<String, dynamic> data, {
    required bool isFromCache,
  }) {
    final itemsRaw = (data['items'] as List? ?? const []);
    return TrainingSessionPage(
      items: itemsRaw
          .cast<Map<String, dynamic>>()
          .map(_listItemFromJson)
          .toList(growable: false),
      nextCursor: data['nextCursor'] as String?,
      hasMore: data['hasMore'] as bool? ?? false,
      isFromCache: isFromCache,
    );
  }

  TrainingSessionListItem _listItemFromJson(Map<String, dynamic> json) {
    final plan = json['plan'] as Map<String, dynamic>? ?? const {};
    final progress = json['progressHighlight'] as Map<String, dynamic>?;
    return TrainingSessionListItem(
      id: json['id'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String).toUtc(),
      endedAt: (json['endedAt'] as String?) != null
          ? DateTime.parse(json['endedAt'] as String).toUtc()
          : null,
      durationSec: (json['durationSec'] as num?)?.toInt() ?? 0,
      status: _statusFromApi(json['status'] as String?),
      plan: TrainingPlanSummary(
        id: plan['id'] as String? ?? '',
        name: plan['name'] as String? ?? 'Bez planu',
      ),
      exercisesCount: (json['exercisesCount'] as num?)?.toInt() ?? 0,
      completedSetsCount: (json['completedSetsCount'] as num?)?.toInt() ?? 0,
      hasNote: json['hasNote'] as bool? ?? false,
      progressHighlight: progress == null
          ? null
          : TrainingProgressHighlight(
              type: _progressTypeFromApi(progress['type'] as String?),
              label: progress['label'] as String? ?? '',
            ),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
    );
  }

  TrainingSessionDetail _detailFromJson(Map<String, dynamic> json) {
    final plan = json['plan'] as Map<String, dynamic>? ?? const {};
    final exercisesRaw = (json['exercises'] as List? ?? const []);
    return TrainingSessionDetail(
      id: json['id'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String).toUtc(),
      endedAt: (json['endedAt'] as String?) != null
          ? DateTime.parse(json['endedAt'] as String).toUtc()
          : null,
      durationSec: (json['durationSec'] as num?)?.toInt() ?? 0,
      status: _statusFromApi(json['status'] as String?),
      plan: TrainingPlanSummary(
        id: plan['id'] as String? ?? '',
        name: plan['name'] as String? ?? 'Bez planu',
      ),
      note: json['note'] as String?,
      exercises: exercisesRaw.cast<Map<String, dynamic>>().map((exercise) {
        final setsRaw = (exercise['sets'] as List? ?? const []);
        return TrainingExerciseDetail(
          exerciseId: exercise['exerciseId'] as String? ?? '',
          exerciseName: exercise['exerciseName'] as String? ?? 'Ćwiczenie',
          muscles: (exercise['muscles'] as List? ?? const [])
              .map((raw) => MuscleGroup.tryParse(raw as String?))
              .whereType<MuscleGroup>()
              .toList(growable: false),
          imageUrl: exercise['imageUrl'] as String?,
          sets: setsRaw.cast<Map<String, dynamic>>().map((set) {
            return TrainingExerciseSetDetail(
              setIndex: (set['setIndex'] as num?)?.toInt() ?? 0,
              planned: _metricsFromJson(set['planned'] as Map<String, dynamic>?),
              actual: _metricsFromJson(set['actual'] as Map<String, dynamic>?),
              completed: set['completed'] as bool? ?? false,
              completedAt:
                  DateTime.tryParse(set['completedAt'] as String? ?? '')?.toUtc(),
            );
          }).toList(growable: false),
        );
      }).toList(growable: false),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> _listItemToJson(TrainingSessionListItem item) {
    return {
      'id': item.id,
      'startedAt': item.startedAt.toUtc().toIso8601String(),
      'endedAt': item.endedAt?.toUtc().toIso8601String(),
      'durationSec': item.durationSec,
      'status': _statusToApi(item.status),
      'plan': {'id': item.plan.id, 'name': item.plan.name},
      'exercisesCount': item.exercisesCount,
      'completedSetsCount': item.completedSetsCount,
      'hasNote': item.hasNote,
      'progressHighlight': item.progressHighlight == null
          ? null
          : {
              'type': _progressTypeToApi(item.progressHighlight!.type),
              'label': item.progressHighlight!.label,
            },
      'updatedAt': item.updatedAt.toUtc().toIso8601String(),
    };
  }

  TrainingSetMetrics? _metricsFromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    return TrainingSetMetrics(
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      reps: (json['reps'] as num?)?.toInt(),
      rir: (json['rir'] as num?)?.toInt(),
      tempo: json['tempo'] as String?,
    );
  }

  Map<String, dynamic>? _metricsToJson(TrainingSetMetrics? metrics) {
    if (metrics == null) return null;
    return {
      'weightKg': metrics.weightKg,
      'reps': metrics.reps,
      'rir': metrics.rir,
      'tempo': metrics.tempo,
    };
  }

  TrainingSessionStatus _statusFromApi(String? raw) {
    return switch (raw) {
      'completed' => TrainingSessionStatus.completed,
      'cancelled' => TrainingSessionStatus.cancelled,
      'active' => TrainingSessionStatus.active,
      _ => TrainingSessionStatus.completed,
    };
  }

  String _statusToApi(TrainingSessionStatus status) {
    return switch (status) {
      TrainingSessionStatus.completed => 'completed',
      TrainingSessionStatus.cancelled => 'cancelled',
      TrainingSessionStatus.active => 'active',
    };
  }

  TrainingProgressHighlightType _progressTypeFromApi(String? raw) {
    return switch (raw) {
      'weight_increase' => TrainingProgressHighlightType.weightIncrease,
      'volume_increase' => TrainingProgressHighlightType.volumeIncrease,
      _ => TrainingProgressHighlightType.noProgress,
    };
  }

  String _progressTypeToApi(TrainingProgressHighlightType type) {
    return switch (type) {
      TrainingProgressHighlightType.weightIncrease => 'weight_increase',
      TrainingProgressHighlightType.volumeIncrease => 'volume_increase',
      TrainingProgressHighlightType.noProgress => 'no_progress',
    };
  }
}

