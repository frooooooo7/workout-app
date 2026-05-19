import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/models/training_history_models.dart';
import '../../domain/repositories/training_history_repository.dart';

enum HistoryViewMode { list, calendar }

class TrainingHistoryState {
  TrainingHistoryState({
    this.items = const [],
    this.loading = true,
    this.loadingMore = false,
    this.refreshing = false,
    this.error,
    this.nextCursor,
    this.hasMore = true,
    this.planFilter,
    this.query = '',
    this.fromCache = false,
    this.viewMode = HistoryViewMode.list,
    DateTime? focusedMonth,
    this.calendarSessions = const [],
    this.isCalendarLoading = false,
  }) : focusedMonth = focusedMonth ?? DateTime(DateTime.now().year, DateTime.now().month, 1);

  final List<TrainingSessionListItem> items;
  final bool loading;
  final bool loadingMore;
  final bool refreshing;
  final String? error;
  final String? nextCursor;
  final bool hasMore;
  final String? planFilter;
  final String query;
  final bool fromCache;
  final HistoryViewMode viewMode;
  final DateTime focusedMonth;
  final List<TrainingSessionListItem> calendarSessions;
  final bool isCalendarLoading;

  TrainingHistoryState copyWith({
    List<TrainingSessionListItem>? items,
    bool? loading,
    bool? loadingMore,
    bool? refreshing,
    String? error,
    bool clearError = false,
    String? nextCursor,
    bool clearNextCursor = false,
    bool? hasMore,
    String? planFilter,
    bool clearPlanFilter = false,
    String? query,
    bool? fromCache,
    HistoryViewMode? viewMode,
    DateTime? focusedMonth,
    List<TrainingSessionListItem>? calendarSessions,
    bool? isCalendarLoading,
  }) {
    return TrainingHistoryState(
      items: items ?? this.items,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      refreshing: refreshing ?? this.refreshing,
      error: clearError ? null : (error ?? this.error),
      nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
      hasMore: hasMore ?? this.hasMore,
      planFilter: clearPlanFilter ? null : (planFilter ?? this.planFilter),
      query: query ?? this.query,
      fromCache: fromCache ?? this.fromCache,
      viewMode: viewMode ?? this.viewMode,
      focusedMonth: focusedMonth ?? this.focusedMonth,
      calendarSessions: calendarSessions ?? this.calendarSessions,
      isCalendarLoading: isCalendarLoading ?? this.isCalendarLoading,
    );
  }
}

class TrainingHistoryCubit extends Cubit<TrainingHistoryState> {
  TrainingHistoryCubit(this._repository) : super(TrainingHistoryState()) {
    unawaited(refresh());
  }

  final TrainingHistoryRepository _repository;

  Future<void> refresh() async {
    if (state.viewMode == HistoryViewMode.calendar) {
      await loadCalendarSessions();
      return;
    }
    emit(state.copyWith(refreshing: true, loading: state.items.isEmpty));
    await _fetchInitialPage(showErrorStateWhenEmpty: true);
  }

  Future<void> retry() {
    if (state.viewMode == HistoryViewMode.calendar) {
      return loadCalendarSessions();
    }
    return _fetchInitialPage(showErrorStateWhenEmpty: true);
  }

  void toggleViewMode() {
    final nextMode = state.viewMode == HistoryViewMode.list
        ? HistoryViewMode.calendar
        : HistoryViewMode.list;
    emit(state.copyWith(viewMode: nextMode));
    if (nextMode == HistoryViewMode.calendar) {
      unawaited(loadCalendarSessions());
    } else {
      unawaited(refresh());
    }
  }

  void changeMonth(int offset) {
    final nextMonth = DateTime(state.focusedMonth.year, state.focusedMonth.month + offset, 1);
    emit(state.copyWith(focusedMonth: nextMonth));
    unawaited(loadCalendarSessions());
  }

  Future<void> loadCalendarSessions() async {
    emit(state.copyWith(isCalendarLoading: true, clearError: true));
    try {
      final from = DateTime(state.focusedMonth.year, state.focusedMonth.month, 1);
      final to = DateTime(state.focusedMonth.year, state.focusedMonth.month + 1, 0, 23, 59, 59, 999);

      final page = await _repository.getSessions(
        limit: 50,
        status: TrainingSessionStatus.completed,
        planId: state.planFilter,
        query: state.query,
        from: from,
        to: to,
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          calendarSessions: page.items,
          isCalendarLoading: false,
          fromCache: page.isFromCache,
          clearError: true,
        ),
      );
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isCalendarLoading: false,
          error: 'Nie udało się załadować sesji kalendarza.',
        ),
      );
    }
  }

  void setPlanFilter(String? planId) {
    emit(state.copyWith(planFilter: planId, clearError: true));
    if (state.viewMode == HistoryViewMode.calendar) {
      unawaited(loadCalendarSessions());
    } else {
      unawaited(_fetchInitialPage(showErrorStateWhenEmpty: true));
    }
  }

  void setQuery(String query) {
    emit(state.copyWith(query: query, clearError: true));
    if (state.viewMode == HistoryViewMode.calendar) {
      unawaited(loadCalendarSessions());
    } else {
      unawaited(_fetchInitialPage(showErrorStateWhenEmpty: true));
    }
  }

  Future<void> loadMore() async {
    if (state.viewMode == HistoryViewMode.calendar) return;
    if (state.loadingMore || state.loading || !state.hasMore) return;
    emit(state.copyWith(loadingMore: true));
    try {
      final page = await _repository.getSessions(
        cursor: state.nextCursor,
        limit: 20,
        status: TrainingSessionStatus.completed,
        planId: state.planFilter,
        query: state.query,
      );
      if (isClosed) return;
      final merged = List<TrainingSessionListItem>.from(state.items)
        ..addAll(page.items);
      emit(
        state.copyWith(
          items: merged,
          loadingMore: false,
          nextCursor: page.nextCursor,
          hasMore: page.hasMore,
          clearError: true,
          fromCache: state.fromCache || page.isFromCache,
        ),
      );
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          loadingMore: false,
          error: 'Nie udało się załadować starszych sesji.',
        ),
      );
    }
  }

  Future<void> _fetchInitialPage({
    required bool showErrorStateWhenEmpty,
  }) async {
    try {
      final page = await _repository.getSessions(
        limit: 20,
        status: TrainingSessionStatus.completed,
        planId: state.planFilter,
        query: state.query,
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          items: page.items,
          loading: false,
          refreshing: false,
          loadingMore: false,
          nextCursor: page.nextCursor,
          hasMore: page.hasMore,
          clearError: true,
          fromCache: page.isFromCache,
        ),
      );
    } catch (_) {
      if (isClosed) return;
      final shouldShowError = showErrorStateWhenEmpty && state.items.isEmpty;
      emit(
        state.copyWith(
          loading: false,
          refreshing: false,
          loadingMore: false,
          error: shouldShowError
              ? 'Brak połączenia. Pokażemy ostatnio zapisane sesje, gdy będą dostępne.'
              : state.error,
        ),
      );
    }
  }
}

