import '../../../library/domain/models/exercise.dart';
import '../models/muscle_role.dart';

export '../models/muscle_role.dart';

// To jedyne miejsce, które mówi, co znaczy „główny” — mapa sesji i statystyki
// okresu korzystają z tych samych reguł, żeby nie pokazywać dwóch różnych
// „Głównych”.

/// Mięsień jest główny, jeśli jako pierwszy tag ćwiczeń dostał co najmniej tę
/// część „celowych” serii lidera. Odsiewa pojedynczą serię izolacji, która nie
/// robi z mięśnia celu całego treningu.
const double primaryMinShareOfLeader = 0.25;

/// Tagi jednego ćwiczenia w kolejności, bez sentinela `all` i bez powtórzeń.
/// Pierwszy wynik jest celem ćwiczenia. Ćwiczenie z tagiem podanym dwa razy
/// to wciąż jedna praca, więc nie wolno liczyć jej podwójnie.
List<MuscleGroup> distinctMuscleTags(Iterable<MuscleGroup> tags) => [
  ...{
    for (final tag in tags)
      if (tag != MuscleGroup.all) tag,
  },
];

/// Czy pierwszy tag ćwiczenia jest jego celem w rolach.
///
/// Odcinki na czas (kardio, deska) to nie serie z obciążeniem: pół godziny na
/// rowerze nie jest „jedną serią nóg”. Gdy jest też praca na powtórzenia,
/// czasowe ćwiczenia tylko wspomagają. Gdy to wszystko, co zrobiono, liczą się
/// normalnie — inaczej nic nie byłoby celem.
bool targetsItsFirstMuscle(
  ExerciseTracking tracking, {
  required bool hasRepBasedWork,
}) => !tracking.isCardio || !hasRepBasedWork;

/// Klucz do składania ćwiczeń o tej samej nazwie w jedno źródło mięśnia.
String muscleSourceKey(String exerciseName) =>
    exerciseName.trim().toLowerCase();

/// Rola każdego mięśnia po liczbie jego „celowych” serii.
Map<MuscleGroup, MuscleRole> assignMuscleRoles(
  Map<MuscleGroup, int> targetSets,
  Iterable<MuscleGroup> muscles,
) {
  final leader = targetSets.values.fold<int>(0, (a, b) => a > b ? a : b);
  return {
    for (final muscle in muscles)
      muscle: (targetSets[muscle] ?? 0) > 0 &&
              (targetSets[muscle]!) >= leader * primaryMinShareOfLeader
          ? MuscleRole.primary
          : MuscleRole.secondary,
  };
}

/// Dlaczego mięsień dostał taką rolę — pokazywane użytkownikowi, żeby wiedział,
/// skąd się to bierze.
String muscleRoleReason({
  required MuscleRole role,
  required int targetSets,
  required int leaderTargetSets,
}) {
  if (role == MuscleRole.primary) {
    return 'Główny: był celem ćwiczenia w $targetSets ${_inSets(targetSets)}.';
  }
  if (targetSets == 0) {
    return 'Wspomagający: w żadnym ćwiczeniu nie był na pierwszym miejscu '
        'listy mięśni, tylko pomagał.';
  }
  final needed = (leaderTargetSets * primaryMinShareOfLeader).ceil();
  return 'Wspomagający: był celem tylko w $targetSets '
      '${_inSets(targetSets)}, a do głównych trzeba co najmniej $needed.';
}

String _inSets(int n) => n == 1 ? 'serii' : 'seriach';
