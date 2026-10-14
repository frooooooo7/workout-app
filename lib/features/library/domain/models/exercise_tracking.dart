/// Co zapisuje seria ćwiczenia. Wartość w API: [apiName].
enum ExerciseTracking {
  /// Ciężar × powtórzenia (domyślny, jak przed kardio).
  weightReps('weight_reps', 'Ciężar × powt.', 'np. przysiad'),

  /// Same powtórzenia (masa ciała).
  reps('reps', 'Powtórzenia', 'np. podciąganie'),

  /// Sam czas.
  duration('duration', 'Czas', 'np. deska'),

  /// Czas i dystans, z tempem liczonym z obu.
  durationDistance(
    'duration_distance',
    'Czas + dystans',
    'bieżnia, rower, wioślarz',
  );

  const ExerciseTracking(this.apiName, this.label, this.example);

  final String apiName;
  final String label;

  /// Podpowiedź pod nazwą trybu w formularzu ćwiczenia.
  final String example;

  bool get tracksWeight => this == ExerciseTracking.weightReps;

  bool get tracksReps =>
      this == ExerciseTracking.weightReps || this == ExerciseTracking.reps;

  bool get tracksDuration =>
      this == ExerciseTracking.duration ||
      this == ExerciseTracking.durationDistance;

  bool get tracksDistance => this == ExerciseTracking.durationDistance;

  /// Starszy serwer (albo sesja sprzed kardio) nie wysyła trybu — to
  /// zawsze był ciężar × powtórzenia.
  static ExerciseTracking fromApi(String? value) {
    for (final tracking in values) {
      if (tracking.apiName == value) return tracking;
    }
    return ExerciseTracking.weightReps;
  }
}

/// Jednostka dystansu ćwiczenia: kilometry (bieżnia, rower) albo metry
/// (wioślarz). W bazie dystans zawsze jest w metrach.
enum DistanceUnit {
  km('km'),
  m('m');

  const DistanceUnit(this.label);

  final String label;

  String get apiName => name;

  static DistanceUnit fromApi(String? value) =>
      value == DistanceUnit.m.name ? DistanceUnit.m : DistanceUnit.km;
}

extension DistanceUnitFormat on DistanceUnit {
  /// Dystans w tej jednostce: `2,1` (km, do 2 miejsc), `2000` (m).
  String format(int meters) {
    if (this == DistanceUnit.m) return '$meters';
    final km = (meters / 10).round() / 100;
    if (km == km.roundToDouble()) return km.toInt().toString();
    var text = km.toStringAsFixed(2);
    if (text.endsWith('0')) text = text.substring(0, text.length - 1);
    return text.replaceAll('.', ',');
  }

  /// `2,1 km` / `2000 m`.
  String formatWithUnit(int meters) => '${format(meters)} $label';

  /// Wpisany dystans w metrach; `null` — puste albo nie liczba.
  int? parse(String? raw) {
    final text = raw?.trim().replaceAll(',', '.') ?? '';
    if (text.isEmpty) return null;
    final value = double.tryParse(text);
    if (value == null || value < 0 || !value.isFinite) return null;
    final meters = (this == DistanceUnit.km ? value * 1000 : value).round();
    return meters > maxDistanceMeters ? null : meters;
  }

  /// Odcinek, na który liczymy tempo: kilometr albo 500 m (wioślarz).
  int get paceMeters => this == DistanceUnit.km ? 1000 : 500;

  /// `/km` albo `/500 m`.
  String get paceSuffix => this == DistanceUnit.km ? '/km' : '/500 m';

  /// Tempo `6:05` (bez dopisku) albo `null`, gdy brakuje czasu lub dystansu.
  String? pace({required int? seconds, required int? meters}) {
    if (seconds == null || meters == null || seconds <= 0 || meters <= 0) {
      return null;
    }
    return formatSetDuration((seconds * paceMeters / meters).round());
  }
}

/// Najdłuższy czas i dystans serii, jakie przyjmuje API.
const maxDurationSeconds = 86400;
const maxDistanceMeters = 1000000;

/// `12:47`, `1:02:03`.
String formatSetDuration(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  final ss = s.toString().padLeft(2, '0');
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$ss';
  return '$m:$ss';
}

/// Wpisany czas w sekundach: `12:47`, `1:02:03`, albo same minuty (`15`,
/// `7,5`). `null` — puste albo nie da się odczytać.
int? parseSetDuration(String? raw) {
  final text = raw?.trim() ?? '';
  if (text.isEmpty) return null;
  int? seconds;
  if (text.contains(':')) {
    final parts = text.split(':');
    if (parts.length > 3 || parts.any((p) => p.trim().isEmpty)) return null;
    final numbers = parts.map((p) => int.tryParse(p.trim())).toList();
    if (numbers.any((n) => n == null || n < 0)) return null;
    // Sekundy i (przy h:mm:ss) minuty muszą być poniżej 60.
    if (numbers.skip(1).any((n) => n! >= 60)) return null;
    seconds = numbers.fold<int>(0, (total, n) => total * 60 + n!);
  } else {
    final minutes = double.tryParse(text.replaceAll(',', '.'));
    if (minutes == null || minutes < 0 || !minutes.isFinite) return null;
    seconds = (minutes * 60).round();
  }
  return seconds > maxDurationSeconds ? null : seconds;
}
