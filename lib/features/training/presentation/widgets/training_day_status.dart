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

/// [selectedDate] = data karty w bieżącym tygodniu; [today] wstrzykiwalne w testach.
String trainingDayHeroLabel(DateTime selectedDate, {DateTime? today}) {
  final now = calendarDateOnly(today ?? DateTime.now());
  final selected = calendarDateOnly(selectedDate);
  if (selected == now) return 'Na dziś';
  if (selected == now.subtract(const Duration(days: 1))) return 'Wczoraj';
  return kTrainingWeekdayFullNames[selected.weekday - 1];
}

/// Poniedziałek bieżącego tygodnia (date-only) względem [today].
DateTime startOfWeekContaining(DateTime today) {
  final d = calendarDateOnly(today);
  return d.subtract(Duration(days: d.weekday - 1));
}
