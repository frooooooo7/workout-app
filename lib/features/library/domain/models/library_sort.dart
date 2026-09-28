/// Kolejność ćwiczeń w bibliotece. Sortowanie odbywa się w Dart, po
/// odfiltrowaniu listy — repozytorium zwraca ćwiczenia w kolejności bazy.
enum LibrarySort {
  /// Najczęściej wykonywane w Twoich treningach; remisy zostają w kolejności
  /// z repozytorium.
  popular,
  alphabetical,
  newest,
  favouritesFirst;

  /// Krótka etykieta do paska wyników („Sortuj: Popularne”).
  String get label => switch (this) {
    LibrarySort.popular => 'Popularne',
    LibrarySort.alphabetical => 'A–Z',
    LibrarySort.newest => 'Najnowsze',
    LibrarySort.favouritesFirst => 'Ulubione',
  };

  /// Pełny opis opcji w arkuszu sortowania.
  String get title => switch (this) {
    LibrarySort.popular => 'Najczęściej wykonywane',
    LibrarySort.alphabetical => 'Nazwa A–Z',
    LibrarySort.newest => 'Najnowsze',
    LibrarySort.favouritesFirst => 'Ulubione najpierw',
  };

  String get subtitle => switch (this) {
    LibrarySort.popular => 'Na podstawie Twoich treningów',
    LibrarySort.alphabetical => 'Alfabetycznie według nazwy',
    LibrarySort.newest => 'Ostatnio dodane na górze',
    LibrarySort.favouritesFirst => 'Oznaczone gwiazdką na górze',
  };
}
