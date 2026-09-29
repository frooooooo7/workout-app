import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../domain/models/training_stats.dart';

/// Kalendarz z wyborem zakresu dat dla statystyk; `null`, gdy użytkownik
/// zamknął go bez zatwierdzenia.
///
/// [initial] (np. poprzednio wybrany zakres) jest dociskany do
/// [firstDate]..[lastDate] — kalendarz wywraca się na starcie, gdy zaznaczenie
/// wystaje poza dozwolone dni, a historia mogła się od tamtej pory zmienić.
Future<StatsDateRange?> pickStatsDateRange(
  BuildContext context, {
  StatsDateRange? initial,
  required DateTime firstDate,
  required DateTime lastDate,
}) async {
  final first = DateUtils.dateOnly(firstDate);
  final last = DateUtils.dateOnly(lastDate);

  DateTimeRange? initialRange;
  if (initial != null) {
    // Docisk jest monotoniczny, więc początek nadal nie wyprzedza końca.
    initialRange = DateTimeRange(
      start: _clamp(initial.start, first, last),
      end: _clamp(initial.end, first, last),
    );
  }

  final picked = await showDateRangePicker(
    context: context,
    firstDate: first,
    lastDate: last,
    initialDateRange: initialRange,
    helpText: 'Wybierz zakres',
    saveText: 'Zastosuj',
    // Język bierze się z aplikacji (AppLocalization), tak jak w kalendarzu
    // miesiąca w historii — wymuszony tu `Locale` wywracałby kalendarz.
    builder: (context, child) =>
        Theme(data: _pickerTheme(Theme.of(context)), child: child!),
  );
  if (picked == null) return null;
  return StatsDateRange(picked.start, picked.end);
}

DateTime _clamp(DateTime day, DateTime first, DateTime last) {
  if (day.isBefore(first)) return first;
  if (day.isAfter(last)) return last;
  return day;
}

ThemeData _pickerTheme(ThemeData base) {
  return base.copyWith(
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.border,
    ),
    datePickerTheme: DatePickerThemeData(
      // Domyślny kolor środka zakresu to `secondaryContainer`, czyli w naszym
      // schemacie jaskrawy turkus — dni w środku byłyby nieczytelne. Półprzezroczysty
      // kolor główny łączy zakres z zaznaczonymi końcami.
      rangeSelectionBackgroundColor: AppColors.primary.withValues(alpha: 0.22),
      rangePickerHeaderForegroundColor: AppColors.textPrimary,
      // Ciemny niebieski `primary` na tle powierzchni ma za mały kontrast
      // dla cyfry dnia — dzisiejszy dzień dostaje jaśniejszy wariant.
      todayBorder: const BorderSide(color: AppColors.primaryVariant),
      todayForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.onPrimary;
        if (states.contains(WidgetState.disabled)) {
          return AppColors.primaryVariant.withValues(alpha: 0.38);
        }
        return AppColors.primaryVariant;
      }),
    ),
  );
}
