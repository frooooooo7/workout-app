/// Talerze na jednej stronie gryfu dla danego ciężaru.
class PlateLoadout {
  const PlateLoadout({required this.barWeight, required this.perSide});

  final double barWeight;

  /// Talerze na każdą stronę, od najcięższego (od środka gryfu).
  final List<double> perSide;

  double get perSideTotal => perSide.fold(0, (sum, plate) => sum + plate);

  double get total => barWeight + perSideTotal * 2;

  /// `{20: 2, 5: 1}` — ile sztuk każdego nominału na stronę, od najcięższego.
  Map<double, int> get counts {
    final result = <double, int>{};
    for (final plate in perSide) {
      result[plate] = (result[plate] ?? 0) + 1;
    }
    return result;
  }
}

/// Wynik kalkulatora: dokładny układ albo dwa najbliższe możliwe ciężary.
class PlateCalculation {
  const PlateCalculation._({
    required this.target,
    required this.barWeight,
    this.exact,
    this.lower,
    this.upper,
  });

  final double target;
  final double barWeight;

  /// Układ dający dokładnie [target]; `null`, gdy się nie da.
  final PlateLoadout? exact;

  /// Najcięższy możliwy ciężar poniżej [target] (gdy brak [exact]).
  final PlateLoadout? lower;

  /// Najlżejszy możliwy ciężar powyżej [target] (gdy brak [exact]); `null`
  /// bez żadnych talerzy.
  final PlateLoadout? upper;

  /// Ciężar mniejszy niż sam gryf.
  bool get belowBar => target < barWeight - _epsilon;

  bool get isExact => exact != null;

  /// Co pokazać na rysunku: dokładny układ, a bez niego — najbliższy niższy.
  PlateLoadout? get shown => exact ?? lower;
}

const _epsilon = 1e-6;

/// Dobiera talerze na gryf. Liczba talerzy każdego nominału jest
/// nieograniczona; spośród układów o tym samym ciężarze wybiera ten z
/// najmniejszą liczbą talerzy (przy remisie — z cięższymi).
///
/// Zachłanne „bierz największy” nie wystarcza przy nietypowych zestawach:
/// przy talerzach 15 i 10 kg na 20 kg na stronę potrzeba 10 + 10, a nie
/// 15 + reszta. Dlatego programowanie dynamiczne w jednostkach 0,05.
abstract final class PlateCalculator {
  /// Dokładność obliczeń: 1/20 jednostki (0,05 kg / 0,05 lb).
  static const _scale = 20;

  /// Górna granica, żeby wpisane przez pomyłkę 10 000 nie zawiesiło UI.
  static const maxTarget = 1000.0;

  static PlateCalculation calculate({
    required double target,
    required double barWeight,
    required List<double> plates,
  }) {
    final clamped = target.clamp(0, maxTarget).toDouble();
    if (clamped < barWeight - _epsilon) {
      return PlateCalculation._(target: clamped, barWeight: barWeight);
    }
    final units = <int>{
      for (final plate in plates)
        if ((plate * _scale).round() > 0) (plate * _scale).round(),
    }.toList()..sort((a, b) => b.compareTo(a));

    // Ciężar na stronę w jednostkach obliczeń.
    final side = ((clamped - barWeight) / 2 * _scale).round();
    final maxPlate = units.isEmpty ? 0 : units.first;
    final limit = side + maxPlate;

    const unreachable = 1 << 30;
    final count = List<int>.filled(limit + 1, unreachable);
    final choice = List<int>.filled(limit + 1, 0);
    count[0] = 0;
    for (var s = 1; s <= limit; s++) {
      // Od najcięższego: przy remisie zostaje cięższy talerz.
      for (final plate in units) {
        if (plate > s || count[s - plate] == unreachable) continue;
        final candidate = count[s - plate] + 1;
        if (candidate < count[s]) {
          count[s] = candidate;
          choice[s] = plate;
        }
      }
    }

    PlateLoadout loadout(int s) {
      final perSide = <double>[];
      var rest = s;
      while (rest > 0) {
        perSide.add(choice[rest] / _scale);
        rest -= choice[rest];
      }
      perSide.sort((a, b) => b.compareTo(a));
      return PlateLoadout(barWeight: barWeight, perSide: perSide);
    }

    if (count[side] != unreachable) {
      return PlateCalculation._(
        target: clamped,
        barWeight: barWeight,
        exact: loadout(side),
      );
    }
    var low = side;
    while (count[low] == unreachable) {
      low--;
    }
    int? high;
    for (var s = side + 1; s <= limit; s++) {
      if (count[s] != unreachable) {
        high = s;
        break;
      }
    }
    return PlateCalculation._(
      target: clamped,
      barWeight: barWeight,
      lower: loadout(low),
      upper: high == null ? null : loadout(high),
    );
  }
}
