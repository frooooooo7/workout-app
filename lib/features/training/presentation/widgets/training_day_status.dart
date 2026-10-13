const List<String> kTrainingWeekdayFullNames = [
  'Poniedziałek',
  'Wtorek',
  'Środa',
  'Czwartek',
  'Piątek',
  'Sobota',
  'Niedziela',
];

const List<String> kTrainingWeekdayShortLabels = [
  'Pon',
  'Wt',
  'Śr',
  'Czw',
  'Pt',
  'Sob',
  'Ndz',
];

DateTime calendarDateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool isCalendarDateBefore(DateTime date, DateTime today) =>
    calendarDateOnly(date).isBefore(calendarDateOnly(today));

bool isCalendarDateAfter(DateTime date, DateTime today) =>
    calendarDateOnly(date).isAfter(calendarDateOnly(today));

/// Poniedziałek bieżącego tygodnia (date-only) względem [today].
DateTime startOfWeekContaining(DateTime today) {
  final d = calendarDateOnly(today);
  return d.subtract(Duration(days: d.weekday - 1));
}
