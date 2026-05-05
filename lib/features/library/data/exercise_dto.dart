import 'dart:convert';
import 'dart:typed_data';

import '../domain/models/exercise.dart';

/// Raw DB row ↔ domain [Exercise] mapper (SQLite v3: `local_id` primary key).
class ExerciseDto {
  const ExerciseDto({
    required this.localId,
    this.serverId,
    required this.name,
    required this.muscles,
    required this.category,
    required this.description,
    this.imageUrl,
    required this.isFavourite,
    required this.isMine,
    required this.createdAtMs,
    this.pendingOp,
    this.isFavouriteDirty = false,
    this.localImageBytes,
    this.localImageFilename,
  });

  final String localId;
  final String? serverId;
  final String name;
  final String muscles;
  final String category;
  final String description;
  final String? imageUrl;
  final bool isFavourite;
  final bool isMine;
  final int createdAtMs;
  final String? pendingOp;
  final bool isFavouriteDirty;
  final Uint8List? localImageBytes;
  final String? localImageFilename;

  // ── DB ──────────────────────────────────────

  factory ExerciseDto.fromMap(Map<String, dynamic> map) {
    final rawLocal = map['local_id'] as String?;
    if (rawLocal == null || rawLocal.isEmpty) {
      throw FormatException('ExerciseDto.fromMap: missing local_id');
    }
    return ExerciseDto(
      localId: rawLocal,
      serverId: map['server_id'] as String?,
      name: map['name'] as String,
      muscles: map['muscles'] as String,
      category: map['category'] as String,
      description: map['description'] as String? ?? '',
      imageUrl: map['image_url'] as String?,
      isFavourite: (map['is_favourite'] as int) == 1,
      isMine: (map['is_mine'] as int) == 1,
      createdAtMs: map['created_at'] as int,
      pendingOp: map['pending_op'] as String?,
      isFavouriteDirty: ((map['is_favourite_dirty'] as int?) ?? 0) == 1,
      localImageBytes: map['local_image_bytes'] as Uint8List?,
      localImageFilename: map['local_image_filename'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'local_id': localId,
        'server_id': serverId,
        'name': name,
        'muscles': muscles,
        'category': category,
        'description': description,
        'image_url': imageUrl,
        'is_favourite': isFavourite ? 1 : 0,
        'is_mine': isMine ? 1 : 0,
        'created_at': createdAtMs,
        'pending_op': pendingOp,
        'is_favourite_dirty': isFavouriteDirty ? 1 : 0,
        'local_image_bytes': localImageBytes,
        'local_image_filename': localImageFilename,
      };

  // ── Domain ───────────────────────────────────

  static String encodeMusclesToJson(List<MuscleGroup> muscles) =>
      jsonEncode(muscles.map((m) => m.name).toList());

  factory ExerciseDto.fromDomain(
    Exercise e, {
    String? localIdOverride,
    String? serverIdOverride,
    String? pendingOp,
    bool isFavouriteDirty = false,
    Uint8List? localImageBytes,
    String? localImageFilename,
  }) =>
      ExerciseDto(
        localId: localIdOverride ?? e.id,
        serverId: serverIdOverride,
        name: e.name,
        muscles: encodeMusclesToJson(e.muscles),
        category: e.category.name,
        description: e.description,
        imageUrl: e.imageUrl,
        isFavourite: e.isFavourite,
        isMine: e.isMine,
        createdAtMs: e.createdAt?.millisecondsSinceEpoch ??
            DateTime.now().millisecondsSinceEpoch,
        pendingOp: pendingOp,
        isFavouriteDirty: isFavouriteDirty,
        localImageBytes: localImageBytes,
        localImageFilename: localImageFilename,
      );

  /// Row shaped after a successful pull from API (`Exercise.id` is server id).
  factory ExerciseDto.fromPulledServer(
    Exercise serverExercise,
    String newLocalId,
  ) =>
      ExerciseDto(
        localId: newLocalId,
        serverId: serverExercise.id,
        name: serverExercise.name,
        muscles: encodeMusclesToJson(serverExercise.muscles),
        category: serverExercise.category.name,
        description: serverExercise.description,
        imageUrl: serverExercise.imageUrl,
        isFavourite: serverExercise.isFavourite,
        isMine: serverExercise.isMine,
        createdAtMs: serverExercise.createdAt?.millisecondsSinceEpoch ??
            DateTime.now().millisecondsSinceEpoch,
        pendingOp: null,
        isFavouriteDirty: false,
      );

  bool get isPendingSync =>
      (pendingOp != null && pendingOp!.isNotEmpty) || isFavouriteDirty;

  Exercise toDomain() => Exercise(
        id: localId,
        name: name,
        muscles: (jsonDecode(muscles) as List)
            .map((s) => MuscleGroup.values.firstWhere((m) => m.name == s))
            .toList(),
        category:
            ExerciseCategory.values.firstWhere((c) => c.name == category),
        description: description,
        imageUrl: imageUrl,
        isFavourite: isFavourite,
        isMine: isMine,
        createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtMs, isUtc: true),
        isPendingSync: isPendingSync,
      );
}
