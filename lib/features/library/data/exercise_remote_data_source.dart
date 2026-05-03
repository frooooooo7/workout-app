import '../../../core/network/api_client.dart';
import '../domain/models/exercise.dart';

/// Wraps the backend `/exercises` REST endpoints and returns domain [Exercise]
/// objects. All methods throw [ApiException] on network or server errors.
class ExerciseRemoteDataSource {
  const ExerciseRemoteDataSource(this._api);

  final ApiClient _api;

  // ── Helpers ───────────────────────────────────────────────────────────────

  Exercise _fromJson(Map<String, dynamic> j) => Exercise(
        id: j['id'] as String,
        name: j['name'] as String,
        muscles: (j['muscles'] as List)
            .map((s) => MuscleGroup.values.firstWhere(
                  (m) => m.name == s,
                  orElse: () => MuscleGroup.abs, // unknown muscle → safe fallback
                ))
            .toList(),
        category: ExerciseCategory.values.firstWhere(
          (c) => c.name == j['category'] as String,
          orElse: () => ExerciseCategory.compound,
        ),
        createdAt: j['createdAt'] != null
            ? DateTime.tryParse(j['createdAt'] as String)?.toUtc()
            : null,
        isFavourite: j['isFavourite'] as bool,
        isMine: j['isMine'] as bool,
      );

  String _buildPath({
    required MuscleGroup? muscleGroup,
    required LibraryFilter? filter,
    required String? query,
  }) {
    final params = <String, String>{};

    if (query != null && query.isNotEmpty) params['q'] = query;

    if (muscleGroup != null && muscleGroup != MuscleGroup.all) {
      params['muscle'] = muscleGroup.name;
    }

    if (filter != null && filter != LibraryFilter.all) {
      params['filter'] = filter.name;
    }

    // Use Uri to properly encode query parameters.
    return Uri(path: '/exercises', queryParameters: params.isEmpty ? null : params)
        .toString();
  }

  // ── Read ──────────────────────────────────────────────────────────────────

  Future<List<Exercise>> getAll({
    MuscleGroup? muscleGroup,
    LibraryFilter? filter,
    String? query,
  }) async {
    final path = _buildPath(
      muscleGroup: muscleGroup,
      filter: filter,
      query: query,
    );
    final data = await _api.get(path, auth: true);
    return (data as List)
        .cast<Map<String, dynamic>>()
        .map(_fromJson)
        .toList();
  }

  // ── Favourite toggle ──────────────────────────────────────────────────────

  /// Calls `POST /exercises/:id/favourite` (toggle) and returns the **server's**
  /// authoritative new favourite state.
  Future<bool> toggleFavourite(String id) async {
    final data = await _api.post(
      '/exercises/$id/favourite',
      {},
      auth: true,
    );
    return (data as Map<String, dynamic>)['isFavourite'] as bool;
  }

  // ── Create ────────────────────────────────────────────────────────────────

  Future<Exercise> create({
    required String name,
    required List<MuscleGroup> muscles,
    required ExerciseCategory category,
  }) async {
    final data = await _api.post(
      '/exercises',
      {
        'name': name,
        'muscles': muscles.map((m) => m.name).toList(),
        'category': category.name,
      },
      auth: true,
    );
    return _fromJson(data as Map<String, dynamic>);
  }

  // ── Update ────────────────────────────────────────────────────────────────

  Future<Exercise> update({
    required String id,
    required String name,
    required List<MuscleGroup> muscles,
    required ExerciseCategory category,
  }) async {
    final data = await _api.put(
      '/exercises/$id',
      {
        'name': name,
        'muscles': muscles.map((m) => m.name).toList(),
        'category': category.name,
      },
      auth: true,
    );
    return _fromJson(data as Map<String, dynamic>);
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> delete(String id) async {
    await _api.delete('/exercises/$id', auth: true);
  }
}
