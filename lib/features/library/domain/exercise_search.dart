import 'models/exercise.dart';

/// Szukanie ćwiczeń w pamięci telefonu (działa offline).
///
/// Zasady:
/// - małe litery i bez polskich znaków, w zapytaniu i w danych,
/// - każde wpisane słowo musi pasować do początku któregoś słowa ćwiczenia,
///   w dowolnej kolejności; od 6 liter porównujemy rdzeń bez dwóch ostatnich
///   liter, min. 4 litery („sztanga” łapie „sztangi” i „sztangą”),
/// - przeszukuje nazwę, dodatkowe nazwy, mięśnie (z partią) i dodatkowe hasła
///   (np. sprzęt), a wynik dostaje ocenę do sortowania.
abstract final class ExerciseSearch {
  static const _diacritics = {
    'ą': 'a',
    'ć': 'c',
    'ę': 'e',
    'ł': 'l',
    'ń': 'n',
    'ó': 'o',
    'ś': 's',
    'ź': 'z',
    'ż': 'z',
  };

  /// Małe litery, bez polskich znaków.
  static String normalize(String input) {
    final lower = input.toLowerCase();
    final buffer = StringBuffer();
    for (final rune in lower.runes) {
      final ch = String.fromCharCode(rune);
      buffer.write(_diacritics[ch] ?? ch);
    }
    return buffer.toString();
  }

  /// Słowa tekstu po normalizacji (litery i cyfry).
  static final _wordPattern = RegExp(r'[a-z0-9]+');

  static List<String> tokens(String input) => _wordPattern
      .allMatches(normalize(input))
      .map((m) => m.group(0)!)
      .toList(growable: false);

  static bool _wordMatches(String word, String token) {
    // Od 6 liter ucinamy końcówkę, ale zostaje co najmniej 4 litery rdzenia.
    if (token.length >= 6) {
      return word.startsWith(token.substring(0, token.length - 2));
    }
    return word.startsWith(token);
  }

  /// Ocena dopasowania najsłabszego słowa zapytania; `null` — brak dopasowania.
  ///
  /// Skala: początek nazwy 100, słowo w nazwie 80, inna nazwa 60,
  /// mięsień główny 40, mięsień wspomagający lub hasło dodatkowe 30.
  static int? score(
    Exercise exercise,
    String query, {
    Iterable<String> aliases = const [],
    Iterable<String> extraTerms = const [],
  }) {
    final queryTokens = tokens(query);
    if (queryTokens.isEmpty) return null;

    final nameWords = tokens(exercise.name);
    final aliasWords = [for (final a in aliases) ...tokens(a)];
    final muscles = exercise.workingMuscles;
    List<String> muscleWords(MuscleGroup m) => [
      ...tokens(m.label),
      ...tokens(m.shortLabel),
      // Zbiorcza etykieta tylko dla grup zbiorczych (plecy, nogi, barki);
      // przedramiona nie mają być „bicepsem”.
      if (m.broadGroup.isCoarse) ...tokens(m.broadGroup.label),
      if (m.region != null) ...tokens(m.region!.label),
    ];
    final primaryWords = muscles.isEmpty ? <String>[] : muscleWords(muscles[0]);
    final secondaryWords = [for (final m in muscles.skip(1)) ...muscleWords(m)];
    final extraWords = [for (final t in extraTerms) ...tokens(t)];

    var weakest = 100;
    var total = 0;
    for (final token in queryTokens) {
      var best = 0;
      for (var i = 0; i < nameWords.length; i++) {
        if (_wordMatches(nameWords[i], token)) {
          // Pierwsze słowo nazwy liczy się jak początek nazwy.
          best = best < (i == 0 ? 100 : 80) ? (i == 0 ? 100 : 80) : best;
        }
      }
      if (best < 60 && aliasWords.any((w) => _wordMatches(w, token))) {
        best = 60;
      }
      if (best < 40 && primaryWords.any((w) => _wordMatches(w, token))) {
        best = 40;
      }
      if (best < 30 &&
          (secondaryWords.any((w) => _wordMatches(w, token)) ||
              extraWords.any((w) => _wordMatches(w, token)))) {
        best = 30;
      }
      if (best == 0) return null;
      if (best < weakest) weakest = best;
      total += best;
    }
    return weakest * 1000 + total;
  }

  /// Ćwiczenia pasujące do [query], od najlepiej dopasowanych. Remisy zostają
  /// w kolejności wejściowej.
  static List<Exercise> rank(List<Exercise> exercises, String query) {
    final scored = <(int, int, Exercise)>[];
    for (final (index, exercise) in exercises.indexed) {
      final s = score(exercise, query);
      if (s != null) scored.add((s, index, exercise));
    }
    scored.sort((a, b) {
      final byScore = b.$1.compareTo(a.$1);
      return byScore != 0 ? byScore : a.$2.compareTo(b.$2);
    });
    return [for (final item in scored) item.$3];
  }
}
