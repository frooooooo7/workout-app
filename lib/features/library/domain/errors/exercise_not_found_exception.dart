/// Thrown when an exercise row no longer exists locally (e.g. reconciled away).
class ExerciseNotFoundException implements Exception {
  ExerciseNotFoundException(this.id);

  final String id;

  @override
  String toString() => 'ExerciseNotFoundException($id)';
}
