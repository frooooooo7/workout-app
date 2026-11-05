import 'exercise.dart';

/// Partia ciała na ekranie startowym biblioteki: kafelek, a na manekinie —
/// obszar, który można stuknąć.
enum LibraryPart {
  chest('Klatka', MuscleGroup.chest, {'chest'}),
  back('Plecy', MuscleGroup.back, {'upper-back', 'trapezius', 'lower-back'}),
  shoulders('Barki', MuscleGroup.shoulders, {'deltoids'}),
  biceps('Biceps', MuscleGroup.biceps, {'biceps'}),
  triceps('Triceps', MuscleGroup.triceps, {'triceps'}),
  abs('Brzuch', MuscleGroup.abs, {'abs', 'obliques'}),
  legs('Nogi', MuscleGroup.legs, {'quadriceps', 'hamstring', 'adductors'}),
  glutes('Pośladki', MuscleGroup.glutes, {'gluteal'}),
  calves('Łydki', MuscleGroup.calves, {'calves'}),
  forearms('Przedramiona', MuscleGroup.forearms, {'forearm'});

  const LibraryPart(this.label, this.group, this.slugs);

  final String label;

  /// Grupa, którą ustawia filtr biblioteki po stuknięciu partii.
  final MuscleGroup group;

  /// Mięśnie manekina należące do tej partii.
  final Set<String> slugs;

  /// Partia stuknięta na manekinie; `null` — tam nie ma żadnej (głowa, dłonie).
  static LibraryPart? fromSlug(String slug) {
    for (final part in values) {
      if (part.slugs.contains(slug)) return part;
    }
    return null;
  }

  /// Ile ćwiczeń z [exercises] pokaże ta partia (tak samo jak filtr listy).
  int countIn(Iterable<Exercise> exercises) {
    final matches = group.filterMatches;
    return exercises.where((e) => e.muscles.any(matches.contains)).length;
  }
}

/// „1 ćwiczenie”, „3 ćwiczenia”, „12 ćwiczeń”.
String exerciseCountLabel(int n) {
  if (n == 1) return '1 ćwiczenie';
  final last = n % 10;
  final teen = n % 100 >= 12 && n % 100 <= 14;
  if (last >= 2 && last <= 4 && !teen) return '$n ćwiczenia';
  return '$n ćwiczeń';
}
