import '../../../../core/units/weight_unit.dart';
import '../../../../core/utils/polish_plural.dart';
import '../../../training/presentation/widgets/stats/stats_format.dart';

/// Nadtytuł nad aktualną wagą: `DZIŚ · 12 PAŹ`, `WCZORAJ · 11 PAŹ`,
/// `PT · 9 PAŹ`.
String formatBodyWeightEyebrow(DateTime date, DateTime today) {
  final day = DateTime(date.year, date.month, date.day);
  final yesterday = DateTime(today.year, today.month, today.day - 1);
  final String prefix;
  if (day == today) {
    prefix = 'Dziś';
  } else if (day == yesterday) {
    prefix = 'Wczoraj';
  } else {
    prefix = statsWeekdaysShort[date.weekday - 1];
  }
  final year = date.year == today.year ? '' : ' ${date.year}';
  return '$prefix · ${formatStatsDayMonth(date)}$year'.toUpperCase();
}

/// `2 sierpnia` (z rokiem, gdy inny niż [today]).
String formatBodyWeightSince(DateTime date, DateTime today) {
  final base = '${date.day} ${statsMonthsGenitive[date.month - 1]}';
  return date.year == today.year ? base : '$base ${date.year}';
}

/// Tydzień na liście: `12–18 paź`, `28 wrz – 4 paź`.
String formatBodyWeightWeek(DateTime start, DateTime end) {
  if (start.month == end.month) {
    return '${start.day}–${end.day} ${statsMonthsShort[end.month - 1]}';
  }
  return '${formatStatsDayMonth(start)} – ${formatStatsDayMonth(end)}';
}

/// `1 pomiar`, `4 pomiary`, `42 pomiary`, `5 pomiarów`.
String formatBodyWeightCount(int count) =>
    '$count ${polishPlural(count, 'pomiar', 'pomiary', 'pomiarów')}';

/// Wartość zmiany bez znaku w aktualnej jednostce (`0,2`) — kierunek
/// pokazuje strzałka.
String formatBodyWeightDelta(double kg) => formatWeightNumber(kg.abs());

/// Tempo ze znakiem: `−0,4`, `+0,2`, `0`.
String formatBodyWeightPace(double kgPerWeek) {
  final value = formatWeightNumber(kgPerWeek.abs());
  if (value == '0') return value;
  return '${kgPerWeek < 0 ? '−' : '+'}$value';
}

/// Przewidywana data celu: `7 lis`, w innym roku `lut 2027`.
String formatBodyWeightGoalDate(DateTime date, DateTime today) {
  if (date.year == today.year) return formatStatsDayMonth(date);
  return '${statsMonthsShort[date.month - 1]} ${date.year}';
}
