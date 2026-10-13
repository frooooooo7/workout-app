import '../../../../../core/utils/polish_plural.dart';
import '../session_details/session_details_formatters.dart';

const _monthNames = [
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

/// `Październik 2026`.
String formatMonthYear(DateTime month) =>
    '${_monthNames[month.month - 1]} ${month.year}';

/// Czas treningu: `52 min`, `1 h 02 min`, `9 h 20 min`.
String formatHoursMinutes(int seconds) {
  final totalMinutes = seconds ~/ 60;
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (hours == 0) return '$minutes min';
  return '$hours h ${minutes.toString().padLeft(2, '0')} min';
}

/// `9 treningów`, `1 trening`, `3 treningi`.
String formatWorkoutCount(int count) =>
    '$count ${polishPlural(count, 'trening', 'treningi', 'treningów')}';

/// Zakres tygodnia: `12–18 paź`, a na przełomie miesięcy `28 wrz – 4 paź`.
String formatWeekRange(DateTime start, DateTime end) {
  if (start.month == end.month && start.day == end.day) {
    return '${end.day} ${formatMonthShort(end)}';
  }
  if (start.month == end.month) {
    return '${start.day}–${end.day} ${formatMonthShort(end)}';
  }
  return '${start.day} ${formatMonthShort(start)} – '
      '${end.day} ${formatMonthShort(end)}';
}

/// Dzień sesji: `śr 14 paź`.
String formatSessionDay(DateTime date) =>
    '${formatWeekdayShort(date)} ${formatDayNumber(date)} '
    '${formatMonthShort(date)}';
