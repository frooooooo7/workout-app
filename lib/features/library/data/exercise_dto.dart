import 'dart:convert';
import '../domain/models/exercise.dart';

/// Raw DB row ↔ domain [Exercise] mapper.
class ExerciseDto {
  const ExerciseDto({
    required this.id,
    required this.name,
    required this.muscles,
    required this.category,
    required this.isFavourite,
    required this.isMine,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String muscles; // JSON-encoded list of MuscleGroup.name strings
  final String category; // ExerciseCategory.name
  final bool isFavourite;
  final bool isMine;
  final int createdAt; // millisecondsSinceEpoch

  // ── DB ──────────────────────────────────────

  factory ExerciseDto.fromMap(Map<String, dynamic> map) => ExerciseDto(
        id: map['id'] as String,
        name: map['name'] as String,
        muscles: map['muscles'] as String,
        category: map['category'] as String,
        isFavourite: (map['is_favourite'] as int) == 1,
        isMine: (map['is_mine'] as int) == 1,
        createdAt: map['created_at'] as int,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'muscles': muscles,
        'category': category,
        'is_favourite': isFavourite ? 1 : 0,
        'is_mine': isMine ? 1 : 0,
        'created_at': createdAt,
      };

  // ── Domain ───────────────────────────────────

  factory ExerciseDto.fromDomain(Exercise e) => ExerciseDto(
        id: e.id,
        name: e.name,
        muscles: jsonEncode(e.muscles.map((m) => m.name).toList()),
        category: e.category.name,
        isFavourite: e.isFavourite,
        isMine: e.isMine,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

  Exercise toDomain() => Exercise(
        id: id,
        name: name,
        muscles: (jsonDecode(muscles) as List)
            .map((s) => MuscleGroup.values.firstWhere((m) => m.name == s))
            .toList(),
        category: ExerciseCategory.values.firstWhere((c) => c.name == category),
        isFavourite: isFavourite,
        isMine: isMine,
      );
}
