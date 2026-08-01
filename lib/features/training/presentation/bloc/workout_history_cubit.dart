import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/models/monthly_training_history.dart';
import '../../domain/models/training_history_models.dart';
import '../../domain/repositories/training_history_repository.dart';

class WorkoutHistoryState {
  WorkoutHistoryState({
    DateTime? focusedMonth,
    List<DateTime>? availableMonths,
    this.selectedDay,
    this.isLoading = true,
    this.isMonthChanging = false,
    this.error,
    this.monthlyHistory,
    this.fromCache = false,
  })  : focusedMonth = focusedMonth ??
            DateTime(DateTime.now().year, DateTime.now().month, 1),
        availableMonths = availableMonths ?? _generateAvailableMonths();

  final DateTime focusedMonth;
  final List<DateTime> availableMonths;
  final DateTime? selectedDay;
  final bool isLoading;
  final bool isMonthChanging;
  final String? error;
  final MonthlyTrainingHistory? monthlyHistory;
  final bool fromCache;

  List<TrainingSessionListItem> get filteredSessions {
    final history = monthlyHistory;
    if (history == null) return const [];
    if (selectedDay == null) return history.sessions;

    final targetYear = selectedDay!.year;
    final targetMonth = selectedDay!.month;
    final targetDay = selectedDay!.day;

    return history.sessions.where((s) {
      final local = s.startedAt.toLocal();
      return local.year == targetYear &&
          local.month == targetMonth &&
          local.day == targetDay;
    }).toList();
  }

  WorkoutHistoryState copyWith({
    DateTime? focusedMonth,
    List<DateTime>? availableMonths,
    DateTime? selectedDay,
    bool clearSelectedDay = false,
    bool? isLoading,
    bool? isMonthChanging,
    String? error,
    bool clearError = false,
    MonthlyTrainingHistory? monthlyHistory,
    bool clearMonthlyHistory = false,
    bool? fromCache,
  }) {
    return WorkoutHistoryState(
      focusedMonth: focusedMonth ?? this.focusedMonth,
      availableMonths: availableMonths ?? this.availableMonths,
      selectedDay:
          clearSelectedDay ? null : (selectedDay ?? this.selectedDay),
      isLoading: isLoading ?? this.isLoading,
      isMonthChanging: isMonthChanging ?? this.isMonthChanging,
      error: clearError ? null : (error ?? this.error),
      monthlyHistory:
          clearMonthlyHistory ? null : (monthlyHistory ?? this.monthlyHistory),
      fromCache: fromCache ?? this.fromCache,
    );
  }

  static List<DateTime> _generateAvailableMonths() {
    final now = DateTime.now();
    final months = <DateTime>[];
    // Generate 24 months back up to current month
    for (int i = 23; i >= 0; i--) {
      months.add(DateTime(now.year, now.month - i, 1));
    }
    return months;
  }
}

class _MonthSessions {
  const _MonthSessions({required this.items, required this.isFromCache});

  final List<TrainingSessionListItem> items;
  final bool isFromCache;
}

class WorkoutHistoryCubit extends Cubit<WorkoutHistoryState> {
  WorkoutHistoryCubit(this._repository) : super(WorkoutHistoryState()) {
    unawaited(loadMonthData(state.focusedMonth));
  }

  final TrainingHistoryRepository _repository;

  /// Ile stron maksymalnie ciągniemy na jeden miesiąc — zabezpieczenie przed
  /// pętlą, gdyby backend zwracał kursor w nieskończoność.
  static const int _maxPagesPerMonth = 6;

  Future<void> loadMonthData(DateTime month, {bool showFullLoading = false}) async {
    final normalizedMonth = DateTime(month.year, month.month, 1);
    final from = normalizedMonth;
    final to = DateTime(month.year, month.month + 1, 0, 23, 59, 59, 999);

    emit(state.copyWith(
      focusedMonth: normalizedMonth,
      clearSelectedDay: true,
      isLoading: showFullLoading || state.monthlyHistory == null,
      isMonthChanging: !showFullLoading && state.monthlyHistory != null,
      clearError: true,
    ));

    List<TrainingSessionListItem> sessions;
    bool isFromCache;

    try {
      // Primary attempt: fetch sessions for exact month range
      final result = await _fetchAllPages(from: from, to: to);
      sessions = result.items;
      isFromCache = result.isFromCache;
    } on Object catch (error, stackTrace) {
      developer.log(
        'Month range request failed, falling back to unfiltered list',
        name: 'WorkoutHistoryCubit',
        error: error,
        stackTrace: stackTrace,
      );
      try {
        // Fallback: fetch general sessions list and filter locally for target month
        final result = await _fetchAllPages();
        sessions = result.items.where((s) {
          final local = s.startedAt.toLocal();
          return local.year == normalizedMonth.year &&
              local.month == normalizedMonth.month;
        }).toList();
        isFromCache = result.isFromCache;
      } on Object catch (error, stackTrace) {
        // Both attempts failed — pokaż ekran błędu z „Spróbuj ponownie”
        // zamiast pustego miesiąca udającego dane z cache'u.
        developer.log(
          'Training history load failed',
          name: 'WorkoutHistoryCubit',
          error: error,
          stackTrace: stackTrace,
        );
        if (isClosed) return;
        emit(state.copyWith(
          isLoading: false,
          isMonthChanging: false,
          clearMonthlyHistory: true,
          fromCache: false,
          error: 'Nie udało się pobrać historii treningów. '
              'Sprawdź połączenie i spróbuj ponownie.',
        ));
        return;
      }
    }

    if (isClosed) return;

    final stats = MonthlyTrainingStats.fromSessions(sessions);
    final trainingDays = <DateTime>{};

    for (final s in sessions) {
      final local = s.startedAt.toLocal();
      trainingDays.add(DateTime(local.year, local.month, local.day));
    }

    final monthlyHistory = MonthlyTrainingHistory(
      month: normalizedMonth,
      stats: stats,
      trainingDays: trainingDays,
      sessions: sessions,
    );

    emit(state.copyWith(
      isLoading: false,
      isMonthChanging: false,
      monthlyHistory: monthlyHistory,
      fromCache: isFromCache,
      clearError: true,
    ));
  }

  /// Zbiera wszystkie ukończone sesje z zakresu, chodząc po stronach kursorem.
  /// Pojedynczy request nie może przekroczyć
  /// [TrainingHistoryRepository.maxPageSize] — większy `limit` backend odrzuca
  /// błędem 400, przez co ekran lądował w fałszywym „trybie offline”.
  Future<_MonthSessions> _fetchAllPages({DateTime? from, DateTime? to}) async {
    final items = <TrainingSessionListItem>[];
    var isFromCache = false;
    String? cursor;

    for (var page = 0; page < _maxPagesPerMonth; page++) {
      final result = await _repository.getSessions(
        cursor: cursor,
        limit: TrainingHistoryRepository.maxPageSize,
        status: TrainingSessionStatus.completed,
        from: from,
        to: to,
      );
      items.addAll(result.items);
      isFromCache = isFromCache || result.isFromCache;
      cursor = result.nextCursor;
      if (!result.hasMore || cursor == null || cursor.isEmpty) break;
    }

    return _MonthSessions(items: items, isFromCache: isFromCache);
  }

  void selectMonth(DateTime month) {
    if (state.focusedMonth.year == month.year &&
        state.focusedMonth.month == month.month) {
      return;
    }
    unawaited(loadMonthData(month));
  }

  void toggleDaySelection(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    if (state.selectedDay != null &&
        state.selectedDay!.year == normalizedDay.year &&
        state.selectedDay!.month == normalizedDay.month &&
        state.selectedDay!.day == normalizedDay.day) {
      // Unselect if already selected
      emit(state.copyWith(clearSelectedDay: true));
    } else {
      emit(state.copyWith(selectedDay: normalizedDay));
    }
  }

  void clearDaySelection() {
    emit(state.copyWith(clearSelectedDay: true));
  }

  Future<void> openMonthPicker(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: state.focusedMonth,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(now.year, now.month + 1, 0),
      initialDatePickerMode: DatePickerMode.year,
      locale: const Locale('pl', 'PL'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: Theme.of(context).colorScheme.primary,
              surface: Theme.of(context).colorScheme.surface,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      selectMonth(DateTime(picked.year, picked.month, 1));
    }
  }

  Future<void> refresh() async {
    await loadMonthData(state.focusedMonth, showFullLoading: false);
  }
}
