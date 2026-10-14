import '../../../core/network/api_client.dart';
import '../../library/data/exercise_remote_data_source.dart';
import '../domain/models/custom_training_plan.dart';

class TrainingPlanRemoteDataSource {
  const TrainingPlanRemoteDataSource(this._api);

  final ApiClient _api;



  CustomTrainingPlan _fromJson(Map<String, dynamic> json) {
    final exercises = (json['exercises'] as List)
        .cast<Map<String, dynamic>>()
        .map((item) {
      final exercise = ExerciseRemoteDataSource.fromJson(item['exercise'] as Map<String, dynamic>);
      final sets = (item['sets'] as List).cast<Map<String, dynamic>>().map((set) {
        return ExerciseSet(
          id: set['clientId'] as String? ?? set['id'] as String?,
          weight: set['weight'] as String?,
          reps: set['reps'] as String? ?? '',
          rir: set['rir'] as String?,
          tempo: set['tempo'] as String?,
          durationSeconds: (set['durationSeconds'] as num?)?.toInt(),
          distanceM: (set['distanceM'] as num?)?.toInt(),
        );
      }).toList();
      return PlanExercise(
        id: item['clientId'] as String? ?? item['id'] as String?,
        exercise: exercise,
        sets: sets,
        restSeconds: (item['restSeconds'] as num?)?.toInt(),
        supersetGroup: item['supersetGroup'] as String?,
      );
    }).toList();

    return CustomTrainingPlan(
      id: json['id'] as String,
      name: json['name'] as String,
      note: json['note'] as String?,
      selectedDays: (json['selectedDays'] as List).cast<int>(),
      exercises: exercises,
      clientId: json['clientId'] as String?,
      // Starszy serwer nie zna tych pól — zostają wartości domyślne.
      defaultRestSeconds:
          (json['defaultRestSeconds'] as num?)?.toInt() ??
          CustomTrainingPlan.defaultRest,
      colorKey: json['colorKey'] as String?,
      iconKey: json['iconKey'] as String?,
      goal: PlanGoal.fromApi(json['goal'] as String?),
      progressionStepKg: (json['progressionStepKg'] as num?)?.toDouble(),
      highlightPlanColor: json['highlightPlanColor'] as bool? ?? true,
      showRir: json['showRir'] as bool? ?? true,
      showTempo: json['showTempo'] as bool? ?? true,
      isPublic: json['isPublic'] as bool? ?? false,
      copyCount: (json['copyCount'] as num?)?.toInt() ?? 0,
      copiedFrom: _authorFromJson(json['copiedFrom']),
    );
  }

  static PlanAuthor? _authorFromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final userId = json['userId'] as String?;
    if (userId == null) return null;
    return PlanAuthor(userId: userId, handle: json['handle'] as String?);
  }

  /// Plan z odpowiedzi kopiowania i liczba pominiętych ćwiczeń (własne
  /// ćwiczenia autora, których nie widzimy w bibliotece).
  PlanCopyResult _copyResult(Object? data) {
    final json = data as Map<String, dynamic>;
    return PlanCopyResult(
      plan: _fromJson(json),
      skippedExercises: (json['skippedExercises'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toBody(
    CustomTrainingPlan plan, {
    required Map<String, String> exerciseServerIdsByLocalId,
  }) {
    return {
      'clientId': plan.id,
      'name': plan.name,
      'note': plan.note,
      'selectedDays': plan.selectedDays,
      'defaultRestSeconds': plan.defaultRestSeconds,
      'colorKey': plan.colorKey,
      'iconKey': plan.iconKey,
      'goal': plan.goal?.apiName,
      'progressionStepKg': plan.progressionStepKg,
      'highlightPlanColor': plan.highlightPlanColor,
      'showRir': plan.showRir,
      'showTempo': plan.showTempo,
      'isPublic': plan.isPublic,
      'exercises': plan.exercises.asMap().entries.map((entry) {
        final pe = entry.value;
        return {
          'clientId': pe.id,
          'exerciseId':
              exerciseServerIdsByLocalId[pe.exercise.id] ?? pe.exercise.id,
          'position': entry.key,
          'restSeconds': pe.restSeconds,
          'supersetGroup': pe.supersetGroup,
          'sets': pe.sets.asMap().entries.map((setEntry) {
            final set = setEntry.value;
            return {
              'clientId': set.id,
              'position': setEntry.key,
              'weight': set.weight,
              'reps': set.reps,
              'rir': set.rir,
              'tempo': set.tempo,
              'durationSeconds': set.durationSeconds,
              'distanceM': set.distanceM,
            };
          }).toList(),
        };
      }).toList(),
    };
  }

  Future<List<CustomTrainingPlan>> getAll() async {
    final data = await _api.get('/training-plans', auth: true);
    return (data as List).cast<Map<String, dynamic>>().map(_fromJson).toList();
  }

  Future<CustomTrainingPlan> create(
    CustomTrainingPlan plan, {
    required Map<String, String> exerciseServerIdsByLocalId,
  }) async {
    final data = await _api.post(
      '/training-plans',
      toBody(plan, exerciseServerIdsByLocalId: exerciseServerIdsByLocalId),
      auth: true,
    );
    return _fromJson(data as Map<String, dynamic>);
  }

  Future<CustomTrainingPlan> update(
    String serverId,
    CustomTrainingPlan plan, {
    required Map<String, String> exerciseServerIdsByLocalId,
  }) async {
    final data = await _api.put(
      '/training-plans/$serverId',
      toBody(plan, exerciseServerIdsByLocalId: exerciseServerIdsByLocalId),
      auth: true,
    );
    return _fromJson(data as Map<String, dynamic>);
  }

  Future<void> delete(String serverId) async {
    await _api.delete('/training-plans/$serverId', auth: true);
  }

  /// Publiczne plany użytkownika (własne — wszystkie, z ciężarami).
  Future<List<CustomTrainingPlan>> listPublic(String userId) async {
    final data = await _api.get('/users/$userId/plans', auth: true);
    return (data as List).cast<Map<String, dynamic>>().map(_fromJson).toList();
  }

  Future<PlanCopyResult> copy(String planServerId, {required String clientId}) async {
    final data = await _api.post(
      '/training-plans/$planServerId/copy',
      {'clientId': clientId},
      auth: true,
    );
    return _copyResult(data);
  }

  Future<PlanCopyResult> copyFromPost(
    String sessionId, {
    required String clientId,
  }) async {
    final data = await _api.post(
      '/posts/$sessionId/copy-plan',
      {'clientId': clientId},
      auth: true,
    );
    return _copyResult(data);
  }
}

class PlanCopyResult {
  const PlanCopyResult({required this.plan, required this.skippedExercises});

  final CustomTrainingPlan plan;
  final int skippedExercises;
}
