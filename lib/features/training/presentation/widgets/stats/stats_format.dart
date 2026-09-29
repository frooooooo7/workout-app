import '../../../domain/models/training_stats.dart';
import '../../../domain/models/training_summary_stats.dart'
    show formatTrainingVolumeKg;

/// Liczba i jednostka osobno — kafelki pokazują jednostkę mniejszą czcionką.
typedef StatsValue = ({String value, String unit});

const statsMonthsShort = [
  'sty',
  'lut',
  'mar',
  'kwi',
  'maj',
  'cze',
  'lip',
  'sie',
  'wrz',
  'paź',
  'lis',
  'gru',
];

const statsMonthsGenitive = [
  'stycznia',
  'lutego',
  'marca',
  'kwietnia',
  'maja',
  'czerwca',
  'lipca',
  'sierpnia',
  'września',
  'października',
  'listopada',
  'grudnia',
];

/// Indeks 0 = poniedziałek.
const statsWeekdaysShort = ['Pn', 'Wt', 'Śr', 'Cz', 'Pt', 'So', 'Nd'];

const statsWeekdaysLong = [
  'poniedziałek',
  'wtorek',
  'środa',
  'czwartek',
  'piątek',
  'sobota',
  'niedziela',
];

/// `82,5` / `80` — ułamek tylko wtedy, gdy coś wnosi.
String formatStatsDecimal(double value, {int digits = 1}) {
  final rounded = double.parse(value.toStringAsFixed(digits));
  if (rounded == rounded.roundToDouble()) {
    return formatTrainingVolumeKg(rounded.round());
  }
  final whole = rounded.truncate();
  final fraction = rounded
      .abs()
      .toStringAsFixed(digits)
      .split('.')
      .last
      .replaceFirst(RegExp(r'0+$'), '');
  final sign = rounded < 0 && whole == 0 ? '-' : '';
  return '$sign${formatTrainingVolumeKg(whole)},$fraction';
}

/// Objętość: do 10 t w kilogramach (`8 450 kg`), wyżej w tonach (`48,2 t`).
StatsValue formatStatsVolume(double kg) {
  if (kg.abs() < 10000) {
    return (value: formatTrainingVolumeKg(kg.round()), unit: 'kg');
  }
  return (value: formatStatsDecimal(kg / 1000), unit: 't');
}

/// Czas w kafelku: `45 min`, `17 h 40 min`, powyżej 100 h same godziny.
StatsValue formatStatsDuration(int seconds) {
  final minutes = seconds ~/ 60;
  if (minutes < 60) return (value: '$minutes', unit: 'min');
  final hours = minutes ~/ 60;
  if (hours >= 100) return (value: formatTrainingVolumeKg(hours), unit: 'h');
  final rest = minutes % 60;
  return (value: '$hours h ${rest.toString().padLeft(2, '0')}', unit: 'min');
}

/// Krótki czas do podpisów: `45 min`, `1 h 05 min`.
String formatStatsDurationShort(int seconds) {
  final v = formatStatsDuration(seconds);
  return '${v.value} ${v.unit}';
}

/// `12 wrz`
String formatStatsDayMonth(DateTime date) =>
    '${date.day} ${statsMonthsShort[date.month - 1]}';

/// `12 września 2026`
String formatStatsLongDate(DateTime date) =>
    '${date.day} ${statsMonthsGenitive[date.month - 1]} ${date.year}';

/// „dziś”, „wczoraj”, „3 dni temu”, „2 tyg. temu”, dalej data.
String formatStatsRelativeDay(DateTime date, DateTime now) {
  final a = DateTime.utc(date.year, date.month, date.day);
  final b = DateTime.utc(now.year, now.month, now.day);
  final days = b.difference(a).inDays;
  if (days <= 0) return 'dziś';
  if (days == 1) return 'wczoraj';
  if (days < 7) return '$days dni temu';
  if (days < 28) return '${days ~/ 7} tyg. temu';
  return formatStatsDayMonth(date);
}

/// Podpis słupka na osi X.
String formatStatsBucketLabel(DateTime start, StatsBucket bucket) =>
    switch (bucket) {
      StatsBucket.day => '${start.day}',
      StatsBucket.week => formatStatsDayMonth(start),
      StatsBucket.month => statsMonthsShort[start.month - 1],
      StatsBucket.year => '${start.year}',
    };

/// Pełny opis słupka w dymku: „12 wrz”, „tydz. od 8 wrz”, „wrzesień 2026”.
String formatStatsBucketTitle(
  DateTime start,
  StatsBucket bucket,
) => switch (bucket) {
  StatsBucket.day =>
    '${statsWeekdaysShort[start.weekday - 1]}, ${formatStatsDayMonth(start)}',
  StatsBucket.week => 'Tydzień od ${formatStatsDayMonth(start)}',
  StatsBucket.month => '${_monthsNominative[start.month - 1]} ${start.year}',
  StatsBucket.year => '${start.year}',
};

const _monthsNominative = [
  'Styczeń',
  'Luty',
  'Marzec',
  'Kwiecień',
  'Maj',
  'Czerwiec',
  'Lipiec',
  'Sierpień',
  'Wrzesień',
  'Październik',
  'Listopad',
  'Grudzień',
];

/// Zmiana względem poprzedniego okresu.
class StatsDelta {
  const StatsDelta._(this.text, this.direction);

  /// `+12%`, `−3`, `bez zmian`.
  final String text;

  /// 1 wzrost, -1 spadek, 0 bez zmian.
  final int direction;

  /// Procentowa — dla sum, które rosną z długością okresu (objętość, czas).
  /// Przy zerze w poprzednim okresie procent nie istnieje: pokazujemy
  /// „nowość”, a przy zerze w obu — nic.
  static StatsDelta? percent(num current, num previous) {
    if (current == 0 && previous == 0) return null;
    if (previous == 0) return const StatsDelta._('nowe', 1);
    final change = (current - previous) / previous * 100;
    final rounded = change.round();
    if (rounded == 0) return const StatsDelta._('bez zmian', 0);
    return StatsDelta._(
      '${rounded > 0 ? '+' : '−'}${rounded.abs()}%',
      rounded.sign,
    );
  }

  /// Bezwzględna — dla małych liczników (treningi, rekordy).
  static StatsDelta? absolute(int current, int previous) {
    if (current == 0 && previous == 0) return null;
    final diff = current - previous;
    if (diff == 0) return const StatsDelta._('bez zmian', 0);
    return StatsDelta._('${diff > 0 ? '+' : '−'}${diff.abs()}', diff.sign);
  }
}

/// Procenty z udziałów 0..1 zaokrąglone tak, żeby dawały razem 100 (metoda
/// największej reszty) — trzy równe części to 34 + 33 + 33, nie 33 × 3.
/// Przy sumie udziałów innej niż 1 (albo samych zerach) zwykłe zaokrąglenie.
List<int> roundedPercents(List<double> shares) {
  final total = shares.fold<double>(0, (a, b) => a + b);
  if (total <= 0 || (total - 1).abs() > 1e-6) {
    return [for (final s in shares) (s * 100).round()];
  }
  final floors = [for (final s in shares) (s * 100).floor()];
  final order = List<int>.generate(shares.length, (i) => i)
    ..sort((a, b) {
      final ra = shares[a] * 100 - floors[a];
      final rb = shares[b] * 100 - floors[b];
      final byRemainder = rb.compareTo(ra);
      return byRemainder != 0 ? byRemainder : a.compareTo(b);
    });
  final missing = 100 - floors.fold<int>(0, (a, b) => a + b);
  for (var i = 0; i < missing && i < order.length; i++) {
    floors[order[i]]++;
  }
  return floors;
}

/// `34%`; niezerowy udział, który zaokrągla się do zera, to `<1%`, żeby obok
/// niepustego paska nie stało „0%”.
String formatStatsPercent(int percent, {required bool nonZero}) =>
    nonZero && percent == 0 ? '<1%' : '$percent%';
