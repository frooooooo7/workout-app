/// Rodzaj serii w treningu.
///
/// Rozgrzewka jest zapisywana w historii, ale nie wlicza się do objętości,
/// liczby serii, najlepszej serii ani rekordów — patrz [countsTowardStats].
enum SetType {
  normal,
  warmup,
  failure,
  drop;

  /// Wartość w API i w lokalnej bazie (`set_type`).
  String get apiName => name;

  /// Czy seria wlicza się do statystyk (objętość, liczba serii, rekordy).
  bool get countsTowardStats => this != SetType.warmup;

  String get label => switch (this) {
    SetType.normal => 'Seria robocza',
    SetType.warmup => 'Rozgrzewka',
    SetType.failure => 'Do upadku',
    SetType.drop => 'Drop set',
  };

  String get description => switch (this) {
    SetType.normal => 'Zwykła seria, liczona do statystyk i rekordów.',
    SetType.warmup => 'Nie wlicza się do objętości, liczby serii i rekordów.',
    SetType.failure => 'Seria wykonana do upadku mięśniowego.',
    SetType.drop => 'Seria z obniżonym ciężarem, tuż po poprzedniej.',
  };

  /// Znak w kolumnie SET zamiast numeru; `null` dla zwykłej serii, która
  /// dostaje kolejny numer.
  String? get badge => switch (this) {
    SetType.normal => null,
    SetType.warmup => 'W',
    SetType.failure => 'F',
    SetType.drop => 'D',
  };

  /// Nieznana lub pusta wartość (np. starszy klient, nowszy serwer) to zwykła
  /// seria — nigdy nie gubimy danych przez błąd parsowania.
  static SetType parse(Object? raw) {
    if (raw is! String) return SetType.normal;
    for (final type in SetType.values) {
      if (type.name == raw) return type;
    }
    return SetType.normal;
  }
}

/// Etykiety kolumny SET dla kolejnych serii ćwiczenia: zwykłe serie dostają
/// kolejne numery (1, 2, 3…), pozostałe literę typu (W, F, D). Rozgrzewka
/// przed pierwszą serią nie przesuwa więc numeracji: `W, 1, 2, 3`.
List<String> setRowLabels(Iterable<SetType> types) {
  var number = 0;
  return [for (final type in types) type.badge ?? '${++number}'];
}
