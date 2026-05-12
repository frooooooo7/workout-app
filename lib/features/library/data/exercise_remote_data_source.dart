import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

import '../../../core/network/api_client.dart';
import '../domain/models/exercise.dart';

/// Wraps the backend `/exercises` REST endpoints and returns domain [Exercise]
/// objects. All methods throw [ApiException] on network or server errors.
class ExerciseRemoteDataSource {
  const ExerciseRemoteDataSource(this._api);

  final ApiClient _api;

  // ── Helpers ───────────────────────────────────────────────────────────────

  static Exercise fromJson(Map<String, dynamic> j) => Exercise(
    id: j['id'] as String,
    name: j['name'] as String,
    muscles: (j['muscles'] as List)
        .map(
          (s) => MuscleGroup.values.firstWhere(
            (m) => m.name == s,
            orElse: () => MuscleGroup.abs, // unknown muscle → safe fallback
          ),
        )
        .toList(),
    category: ExerciseCategory.values.firstWhere(
      (c) => c.name == j['category'] as String,
      orElse: () => ExerciseCategory.compound,
    ),
    description: j['description'] as String? ?? '',
    imageUrl: j['imageUrl'] as String?,
    createdAt: j['createdAt'] != null
        ? DateTime.tryParse(j['createdAt'] as String)?.toUtc()
        : null,
    isFavourite: (j['isFavourite'] as bool?) ?? false,
    isMine: (j['isMine'] as bool?) ?? true,
    isPendingSync: false,
  );

  /// Web clients often use filenames like `blob` without an extension — backend
  /// and MIME detection need a real extension.
  String _normalizeExerciseImageFilename(String filename) {
    var name = filename.trim();
    if (name.isEmpty || name.toLowerCase() == 'blob') {
      name = 'upload.jpg';
    }
    final lower = name.toLowerCase();
    final hasExt =
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp');
    if (!hasExt) {
      name = '$name.jpg';
    }
    return name;
  }

  MediaType _mediaTypeForExerciseImage(String filename) {
    final typed = lookupMimeType(filename);
    if (typed != null) return MediaType.parse(typed);
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.webp')) return MediaType('image', 'webp');
    return MediaType('image', 'jpeg');
  }

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
    return Uri(
      path: '/exercises',
      queryParameters: params.isEmpty ? null : params,
    ).toString();
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
        .map(ExerciseRemoteDataSource.fromJson)
        .toList();
  }

  // ── Favourite toggle ──────────────────────────────────────────────────────

  /// Calls `POST /exercises/:id/favourite` (toggle) and returns the **server's**
  /// authoritative new favourite state.
  Future<bool> toggleFavourite(String id) async {
    final data = await _api.post('/exercises/$id/favourite', {}, auth: true);
    return (data as Map<String, dynamic>)['isFavourite'] as bool;
  }

  // ── Create ────────────────────────────────────────────────────────────────

  Future<Exercise> create({
    required String name,
    required List<MuscleGroup> muscles,
    required ExerciseCategory category,
    required String description,
    String? clientId,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'muscles': muscles.map((m) => m.name).toList(),
      'category': category.name,
      'description': description,
    };
    if (clientId != null) {
      body['clientId'] = clientId;
    }
    final data = await _api.post('/exercises', body, auth: true);
    return ExerciseRemoteDataSource.fromJson(data as Map<String, dynamic>);
  }

  /// Multipart `POST /exercises/:id/image` — updates `imageUrl` on the server.
  Future<Exercise> uploadExerciseImage(
    String exerciseId,
    Uint8List bytes,
    String filename,
  ) async {
    final safeName = _normalizeExerciseImageFilename(filename);
    final file = http.MultipartFile.fromBytes(
      'image',
      bytes,
      filename: safeName,
      contentType: _mediaTypeForExerciseImage(safeName),
    );
    final data = await _api.postMultipart(
      '/exercises/$exerciseId/image',
      files: [file],
      auth: true,
    );
    return ExerciseRemoteDataSource.fromJson(data as Map<String, dynamic>);
  }

  // ── Update ────────────────────────────────────────────────────────────────

  Future<Exercise> update({
    required String id,
    required String name,
    required List<MuscleGroup> muscles,
    required ExerciseCategory category,
    required String description,
  }) async {
    final data = await _api.put('/exercises/$id', {
      'name': name,
      'muscles': muscles.map((m) => m.name).toList(),
      'category': category.name,
      'description': description,
    }, auth: true);
    return ExerciseRemoteDataSource.fromJson(data as Map<String, dynamic>);
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> delete(String id) async {
    await _api.delete('/exercises/$id', auth: true);
  }
}
