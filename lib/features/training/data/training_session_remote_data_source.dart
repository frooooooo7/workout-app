import '../../../core/network/api_client.dart';
import '../domain/models/training_session.dart';

class TrainingSessionRemoteDataSource {
  const TrainingSessionRemoteDataSource(this._api);

  final ApiClient _api;

  TrainingSession _fromJson(Map<String, dynamic> json) {
    final exercises = (json['exercises'] as List)
        .cast<Map<String, dynamic>>()
        .map((exercise) {
          final sets = (exercise['sets'] as List)
              .cast<Map<String, dynamic>>()
              .map(
                (set) => TrainingSessionSet(
                  id: set['clientId'] as String? ?? set['id'] as String?,
                  plannedWeight: set['plannedWeight'] as String?,
                  plannedReps: set['plannedReps'] as String? ?? '',
                  plannedRir: set['plannedRir'] as String?,
                  plannedTempo: set['plannedTempo'] as String?,
                  actualWeight: set['actualWeight'] as String?,
                  actualReps: set['actualReps'] as String?,
                  actualRir: set['actualRir'] as String?,
                  actualTempo: set['actualTempo'] as String?,
                  completed: (set['completed'] as bool?) ?? false,
                  completedAt: set['completedAt'] != null
                      ? DateTime.tryParse(set['completedAt'] as String)?.toUtc()
                      : null,
                ),
              )
              .toList();
          return TrainingSessionExercise(
            id: exercise['clientId'] as String? ?? exercise['id'] as String?,
            exerciseId:
                (exercise['exerciseClientId'] as String?) ??
                (exercise['exerciseId'] as String?) ??
                '',
            exerciseName: exercise['exerciseName'] as String,
            exerciseMuscles: (exercise['exerciseMuscles'] as List)
                .cast<String>(),
            exerciseCategory: exercise['exerciseCategory'] as String,
            exerciseImageUrl: exercise['exerciseImageUrl'] as String?,
            sets: sets,
          );
        })
        .toList();

    return TrainingSession(
      id: json['clientId'] as String? ?? json['id'] as String,
      serverId: json['id'] as String,
      planLocalId: json['planClientId'] as String?,
      planServerId: json['planId'] as String?,
      planName: json['planName'] as String,
      status: TrainingSessionStatus.values.firstWhere(
        (status) => status.name == json['status'],
        orElse: () => TrainingSessionStatus.completed,
      ),
      note: json['note'] as String?,
      startedAt: DateTime.parse(json['startedAt'] as String).toUtc(),
      finishedAt: json['finishedAt'] != null
          ? DateTime.tryParse(json['finishedAt'] as String)?.toUtc()
          : null,
      exercises: exercises,
    );
  }

  Map<String, dynamic> toBody(
    TrainingSession session, {
    required Map<String, String?> exerciseServerIdsByLocalId,
  }) {
    return {
      'clientId': session.id,
      'planId': session.planServerId,
      'planClientId': session.planLocalId,
      'planName': session.planName,
      'status': session.status.name,
      'note': session.note,
      'startedAt': session.startedAt.toUtc().toIso8601String(),
      'finishedAt': session.finishedAt?.toUtc().toIso8601String(),
      'exercises': session.exercises.asMap().entries.map((entry) {
        final exercise = entry.value;
        final serverExerciseId =
            exerciseServerIdsByLocalId[exercise.exerciseId];
        return {
          'clientId': exercise.id,
          'exerciseId': serverExerciseId,
          'exerciseClientId': exercise.exerciseId,
          'exerciseName': exercise.exerciseName,
          'exerciseMuscles': exercise.exerciseMuscles,
          'exerciseCategory': exercise.exerciseCategory,
          'exerciseImageUrl': exercise.exerciseImageUrl,
          'position': entry.key,
          'sets': exercise.sets.asMap().entries.map((setEntry) {
            final set = setEntry.value;
            return {
              'clientId': set.id,
              'position': setEntry.key,
              'plannedWeight': set.plannedWeight,
              'plannedReps': set.plannedReps,
              'plannedRir': set.plannedRir,
              'plannedTempo': set.plannedTempo,
              'actualWeight': set.actualWeight,
              'actualReps': set.actualReps,
              'actualRir': set.actualRir,
              'actualTempo': set.actualTempo,
              'completed': set.completed,
              'completedAt': set.completedAt?.toUtc().toIso8601String(),
            };
          }).toList(),
        };
      }).toList(),
    };
  }

  Future<TrainingSession> create(
    TrainingSession session, {
    required Map<String, String?> exerciseServerIdsByLocalId,
  }) async {
    final data = await _api.post(
      '/training-sessions',
      toBody(session, exerciseServerIdsByLocalId: exerciseServerIdsByLocalId),
      auth: true,
    );
    return _fromJson(data as Map<String, dynamic>);
  }

  Future<TrainingSession> update(
    String serverId,
    TrainingSession session, {
    required Map<String, String?> exerciseServerIdsByLocalId,
  }) async {
    final data = await _api.put(
      '/training-sessions/$serverId',
      toBody(session, exerciseServerIdsByLocalId: exerciseServerIdsByLocalId),
      auth: true,
    );
    return _fromJson(data as Map<String, dynamic>);
  }
}
