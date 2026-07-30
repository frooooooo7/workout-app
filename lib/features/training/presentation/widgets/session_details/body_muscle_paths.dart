import 'dart:math' as math;
import 'dart:ui';

import '../../../../library/domain/models/exercise.dart';

/// Geometria manekina używanego przez mapę mięśni.
///
/// Kształty są zapisane w stałej przestrzeni projektowej [bodyDesignSize]
/// (100 × 240, sylwetka wyśrodkowana na `x = 50`) i skalowane dopiero przy
/// rysowaniu — dzięki temu manekin jest ostry w każdym rozmiarze i nie wymaga
/// żadnych assetów.
///
/// Rysowanie jest dwuwarstwowe: najpierw [bodySilhouette] kładzie ciągłą,
/// neutralną sylwetkę (zachodzące na siebie części ciała zlewają się w jedną
/// postać), a dopiero na niej lądują obszary mięśniowe. Bez tej warstwy
/// pojedyncze mięśnie czytają się jako oderwane plamy, a nie jako człowiek.
///
/// Współrzędne opisują lewą połowę, prawa powstaje przez [_mirror] — poprawka
/// anatomiczna zawsze dotyka jednego miejsca.
const Size bodyDesignSize = Size(100, 240);

enum BodyView {
  front,
  back;

  String get label => switch (this) {
        BodyView.front => 'Przód',
        BodyView.back => 'Tył',
      };
}

/// Pojedynczy obszar mięśniowy na manekinie. Jeden [MuscleGroup] może mieć
/// kilka kształtów (lewa/prawa strona, oba widoki).
class MuscleShape {
  const MuscleShape(this.muscle, this.path);

  final MuscleGroup muscle;
  final Path path;
}

List<Offset> _mirror(List<Offset> points) =>
    points.map((p) => Offset(bodyDesignSize.width - p.dx, p.dy)).toList();

/// Wielokąt z zaokrąglonymi narożnikami o zadanym promieniu.
///
/// W przeciwieństwie do wygładzania krzywymi przez punkty środkowe krawędzi,
/// tutaj kształt zachowuje swoje proporcje — pięciokąt zostaje pięciokątem,
/// a nie zapada się w elipsę. To różnica między „mięsień" a „plama".
Path _rounded(List<Offset> points, double radius) {
  final path = Path();
  final n = points.length;
  if (n < 3) return path;

  for (var i = 0; i < n; i++) {
    final prev = points[(i - 1 + n) % n];
    final curr = points[i];
    final next = points[(i + 1) % n];

    final toPrev = prev - curr;
    final toNext = next - curr;
    final prevLen = toPrev.distance;
    final nextLen = toNext.distance;
    if (prevLen == 0 || nextLen == 0) continue;

    final entry = curr + toPrev / prevLen * math.min(radius, prevLen / 2);
    final exit = curr + toNext / nextLen * math.min(radius, nextLen / 2);

    if (i == 0) {
      path.moveTo(entry.dx, entry.dy);
    } else {
      path.lineTo(entry.dx, entry.dy);
    }
    path.quadraticBezierTo(curr.dx, curr.dy, exit.dx, exit.dy);
  }
  path.close();
  return path;
}

Path _pair(List<Offset> left, double radius) {
  final path = _rounded(left, radius);
  path.addPath(_rounded(_mirror(left), radius), Offset.zero);
  return path;
}

// ── Sylwetka ──────────────────────────────────────
// Części zachodzą na siebie z zapasem, żeby wypełnione jednym kolorem zlały
// się w ciągłą postać bez szczelin w stawach.

const _neck = [Offset(45, 22), Offset(55, 22), Offset(55, 38), Offset(45, 38)];

/// Tułów: najszerszy w barkach, zwężony w talii, ponownie szerszy w biodrach.
const _torso = [
  Offset(32, 38),
  Offset(68, 38),
  Offset(65, 62),
  Offset(61, 88),
  Offset(63, 112),
  Offset(37, 112),
  Offset(39, 88),
  Offset(35, 62),
];

const _pelvis = [
  Offset(36, 106),
  Offset(64, 106),
  Offset(65, 128),
  Offset(35, 128),
];

const _upperArmL = [
  Offset(19, 38),
  Offset(33, 38),
  Offset(31, 88),
  Offset(19, 88),
];

const _foreArmL = [
  Offset(17, 84),
  Offset(30, 84),
  Offset(29, 126),
  Offset(18, 126),
];

const _handL = [
  Offset(18, 122),
  Offset(29, 122),
  Offset(28, 140),
  Offset(19, 140),
];

const _thighL = [
  Offset(34, 118),
  Offset(50, 118),
  Offset(48, 186),
  Offset(35, 186),
];

const _calfL = [
  Offset(36, 180),
  Offset(48, 180),
  Offset(47, 222),
  Offset(37, 222),
];

const _footL = [
  Offset(35, 217),
  Offset(48, 217),
  Offset(48, 233),
  Offset(34, 233),
];

// ── Widok z przodu ────────────────────────────────

const _frontSideDeltL = [
  Offset(20, 39),
  Offset(28, 38),
  Offset(30, 46),
  Offset(29, 56),
  Offset(21, 55),
  Offset(18, 46),
];

const _frontDeltL = [
  Offset(29, 39),
  Offset(38, 39),
  Offset(40, 47),
  Offset(37, 56),
  Offset(30, 55),
  Offset(27, 46),
];

const _chestL = [
  Offset(35, 45),
  Offset(48, 43),
  Offset(49, 58),
  Offset(48, 70),
  Offset(38, 69),
  Offset(34, 58),
];

const _abs = [
  Offset(43, 73),
  Offset(57, 73),
  Offset(56, 94),
  Offset(54, 108),
  Offset(46, 108),
  Offset(44, 94),
];

const _obliquesL = [
  Offset(37, 74),
  Offset(43, 73),
  Offset(43, 102),
  Offset(39, 105),
  Offset(36, 92),
];

const _bicepsL = [
  Offset(20, 57),
  Offset(31, 56),
  Offset(31, 76),
  Offset(29, 86),
  Offset(20, 85),
  Offset(18, 70),
];

const _foreArmsL = [
  Offset(18, 87),
  Offset(30, 86),
  Offset(29, 108),
  Offset(28, 124),
  Offset(19, 124),
  Offset(17, 104),
];

const _quadsL = [
  Offset(34, 121),
  Offset(45, 120),
  Offset(45, 166),
  Offset(42, 183),
  Offset(36, 182),
  Offset(33, 146),
];

const _adductorsL = [
  Offset(46, 123),
  Offset(50, 122),
  Offset(50, 160),
  Offset(46, 158),
  Offset(45, 140),
];

const _calvesL = [
  Offset(37, 182),
  Offset(47, 181),
  Offset(46, 202),
  Offset(44, 219),
  Offset(38, 218),
  Offset(35, 197),
];

// ── Widok z tyłu ──────────────────────────────────

const _traps = [
  Offset(41, 36),
  Offset(59, 36),
  Offset(66, 48),
  Offset(56, 64),
  Offset(44, 64),
  Offset(34, 48),
];

const _rearDeltL = [
  Offset(20, 39),
  Offset(29, 38),
  Offset(31, 47),
  Offset(29, 57),
  Offset(21, 56),
  Offset(18, 47),
];

const _rhomboids = [
  Offset(44, 62),
  Offset(56, 62),
  Offset(56, 80),
  Offset(50, 85),
  Offset(44, 80),
];

const _latsL = [
  Offset(34, 58),
  Offset(43, 64),
  Offset(44, 90),
  Offset(39, 99),
  Offset(34, 88),
  Offset(32, 70),
];

const _lowerBack = [
  Offset(41, 92),
  Offset(59, 92),
  Offset(60, 106),
  Offset(50, 114),
  Offset(40, 106),
];

const _tricepsL = [
  Offset(20, 56),
  Offset(31, 55),
  Offset(31, 76),
  Offset(29, 86),
  Offset(20, 85),
  Offset(18, 69),
];

const _glutesL = [
  Offset(35, 115),
  Offset(49, 114),
  Offset(49, 138),
  Offset(43, 146),
  Offset(36, 143),
  Offset(33, 127),
];

const _hamstringsL = [
  Offset(34, 146),
  Offset(48, 145),
  Offset(47, 172),
  Offset(44, 184),
  Offset(37, 183),
  Offset(33, 163),
];

/// Ciągła sylwetka postaci rysowana pod mięśniami.
Path bodySilhouette(BodyView view) {
  return Path()
    ..addOval(
      Rect.fromCenter(center: const Offset(50, 15), width: 20, height: 24),
    )
    ..addPath(_rounded(_neck, 3), Offset.zero)
    ..addPath(_rounded(_torso, 7), Offset.zero)
    ..addPath(_rounded(_pelvis, 8), Offset.zero)
    ..addPath(_pair(_upperArmL, 7), Offset.zero)
    ..addPath(_pair(_foreArmL, 7), Offset.zero)
    ..addPath(_pair(_handL, 6), Offset.zero)
    ..addPath(_pair(_thighL, 8), Offset.zero)
    ..addPath(_pair(_calfL, 7), Offset.zero)
    ..addPath(_pair(_footL, 5), Offset.zero);
}

/// Obszary mięśniowe dla danego widoku, w kolejności rysowania.
List<MuscleShape> bodyMuscleShapes(BodyView view) {
  return switch (view) {
    BodyView.front => [
        MuscleShape(MuscleGroup.sideDelts, _pair(_frontSideDeltL, 4)),
        MuscleShape(MuscleGroup.frontDelts, _pair(_frontDeltL, 4)),
        MuscleShape(MuscleGroup.chest, _pair(_chestL, 5)),
        MuscleShape(MuscleGroup.obliques, _pair(_obliquesL, 4)),
        MuscleShape(MuscleGroup.abs, _rounded(_abs, 5)),
        MuscleShape(MuscleGroup.biceps, _pair(_bicepsL, 5)),
        MuscleShape(MuscleGroup.forearms, _pair(_foreArmsL, 5)),
        MuscleShape(MuscleGroup.quads, _pair(_quadsL, 6)),
        MuscleShape(MuscleGroup.adductors, _pair(_adductorsL, 4)),
        MuscleShape(MuscleGroup.calves, _pair(_calvesL, 6)),
      ],
    BodyView.back => [
        MuscleShape(MuscleGroup.traps, _rounded(_traps, 6)),
        MuscleShape(MuscleGroup.rearDelts, _pair(_rearDeltL, 4)),
        MuscleShape(MuscleGroup.lats, _pair(_latsL, 6)),
        MuscleShape(MuscleGroup.rhomboids, _rounded(_rhomboids, 5)),
        MuscleShape(MuscleGroup.lowerBack, _rounded(_lowerBack, 5)),
        MuscleShape(MuscleGroup.triceps, _pair(_tricepsL, 5)),
        MuscleShape(MuscleGroup.forearms, _pair(_foreArmsL, 5)),
        MuscleShape(MuscleGroup.glutes, _pair(_glutesL, 7)),
        MuscleShape(MuscleGroup.hamstrings, _pair(_hamstringsL, 6)),
        MuscleShape(MuscleGroup.calves, _pair(_calvesL, 6)),
      ],
  };
}
