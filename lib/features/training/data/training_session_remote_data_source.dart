import '../../../core/network/api_client.dart';
import '../domain/models/training_session.dart';

/// Sesja z `GET /training-sessions/history` razem z jej `updatedAt`
/// z serwera (znacznik dla przyrostowej synchronizacji).
class PulledTrainingSession {
  const PulledTrainingSession({required this.session, this.updatedAt});

  final TrainingSession session;
  final DateTime? updatedAt;
}

/// Nagrobek usuniętej sesji. `clientId` może być `null`; dla sesji usuniętej
/// po `clientId`, zanim dotarła na serwer, [id] jest losowe.
class TrainingSessionTombstone {
  const TrainingSessionTombstone({
    required this.id,
    this.clientId,
    this.deletedAt,
  });

  final String id;
  final String? clientId;
  final DateTime? deletedAt;
}

class TrainingSessionHistoryPage {
  const TrainingSessionHistoryPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
    this.deleted = const [],
  });

  final List<PulledTrainingSession> items;
  final String? nextCursor;
  final bool hasMore;
  final List<TrainingSessionTombstone> deleted;
}

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
      sharedToProfile: (json['sharedToProfile'] as bool?) ?? false,
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
      'sharedToProfile': session.sharedToProfile,
      'exercises': session.exercises.asMap().entries.map((entry) {
        final exercise = entry.value;
        final serverExerciseId =
            exerciseServerIdsByLocalId[exercise.exerciseId];
        return {
          'clientId': exercise.id,
          'exerciseId': serverExerciseId,
          // Sesja pobrana z serwera może nie mieć powiązania z ćwiczeniem
          // (usunięte) — pusty tekst nie jest poprawnym uuid.
          'exerciseClientId': exercise.exerciseId.isEmpty
              ? null
              : exercise.exerciseId,
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

  /// Aktualizacja samej flagi — używana, gdy sesji nie ma w lokalnej bazie
  /// (np. historia pobrana po reinstalacji).
  Future<TrainingSession> setSharedToProfile(
    String serverId,
    bool shared,
  ) async {
    final data = await _api.patch(
      '/training-sessions/$serverId/shared-to-profile',
      {'sharedToProfile': shared},
      auth: true,
    );
    return _fromJson(data as Map<String, dynamic>);
  }

  /// `DELETE /training-sessions/:id` → 204 (także powtórnie).
  Future<void> delete(String serverId) async {
    await _api.delete('/training-sessions/$serverId', auth: true);
  }

  /// `DELETE /training-sessions/by-client-id/:clientId` → zawsze 204 i zawsze
  /// zostawia nagrobek, więc zabija też zapis wciąż czekający w kolejce.
  Future<void> deleteByClientId(String clientId) async {
    await _api.delete(
      '/training-sessions/by-client-id/$clientId',
      auth: true,
    );
  }

  /// Zakończone / anulowane sesje, najnowsze najpierw. `deleted` przychodzi
  /// tylko na pierwszej stronie i tylko z [updatedSince].
  Future<TrainingSessionHistoryPage> history({
    int limit = 100,
    String? cursor,
    DateTime? updatedSince,
  }) async {
    final path = Uri(
      path: '/training-sessions/history',
      queryParameters: {
        'limit': '$limit',
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        if (updatedSince != null)
          'updatedSince': updatedSince.toUtc().toIso8601String(),
      },
    ).toString();
    final data = await _api.get(path, auth: true) as Map<String, dynamic>;
    return historyPageFromJson(data);
  }

  TrainingSessionHistoryPage historyPageFromJson(Map<String, dynamic> data) {
    final items = <PulledTrainingSession>[
      for (final raw in (data['items'] as List? ?? const []))
        PulledTrainingSession(
          session: _fromJson(raw as Map<String, dynamic>),
          updatedAt: _parseDate(raw['updatedAt']),
        ),
    ];
    final deleted = <TrainingSessionTombstone>[
      for (final raw in (data['deleted'] as List? ?? const []))
        if (raw is Map<String, dynamic> && raw['id'] is String)
          TrainingSessionTombstone(
            id: raw['id'] as String,
            clientId: raw['clientId'] as String?,
            deletedAt: _parseDate(raw['deletedAt']),
          ),
    ];
    return TrainingSessionHistoryPage(
      items: items,
      nextCursor: data['nextCursor'] as String?,
      hasMore: data['hasMore'] as bool? ?? false,
      deleted: deleted,
    );
  }

  static DateTime? _parseDate(Object? raw) =>
      raw is String ? DateTime.tryParse(raw)?.toUtc() : null;
}
