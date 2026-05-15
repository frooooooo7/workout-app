import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/models/training_history_models.dart';
import '../../domain/repositories/training_history_repository.dart';

class TrainingHistoryState {
  const TrainingHistoryState({
    this.items = const [],
    this.loading = true,
    this.loadingMore = false,
    this.refreshing = false,
    this.error,
    this.nextCursor,
    this.hasMore = true,
    this.statusFilter,
    this.planFilter,
    this.query = '',
    this.fromCache = false,
  });

  final List<TrainingSessionListItem> items;
  final bool loading;
  final bool loadingMore;
  final bool refreshing;
  final String? error;
  final String? nextCursor;
  final bool hasMore;
  final TrainingSessionStatus? statusFilter;
  final String? planFilter;
  final String query;
  final bool fromCache;

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
    TrainingSessionStatus? statusFilter,
    bool clearStatusFilter = false,
    String? planFilter,
    bool clearPlanFilter = false,
    String? query,
    bool? fromCache,
  }) {
    return TrainingHistoryState(
      items: items ?? this.items,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      refreshing: refreshing ?? this.refreshing,
      error: clearError ? null : (error ?? this.error),
      nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
      hasMore: hasMore ?? this.hasMore,
      statusFilter:
          clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
      planFilter: clearPlanFilter ? null : (planFilter ?? this.planFilter),
      query: query ?? this.query,
      fromCache: fromCache ?? this.fromCache,
    );
  }
}

class TrainingHistoryCubit extends Cubit<TrainingHistoryState> {
  TrainingHistoryCubit(this._repository) : super(const TrainingHistoryState()) {
    unawaited(refresh());
  }

  final TrainingHistoryRepository _repository;

  Timer? _queryDebounce;

  @override
  Future<void> close() async {
    _queryDebounce?.cancel();
    return super.close();
  }

  Future<void> refresh() async {
    emit(state.copyWith(refreshing: true, loading: state.items.isEmpty));
    await _fetchInitialPage(showErrorStateWhenEmpty: true);
  }

  Future<void> retry() => _fetchInitialPage(showErrorStateWhenEmpty: true);

  void setStatusFilter(TrainingSessionStatus? status) {
    emit(state.copyWith(statusFilter: status, clearError: true));
    unawaited(_fetchInitialPage(showErrorStateWhenEmpty: true));
  }

  void setPlanFilter(String? planId) {
    emit(state.copyWith(planFilter: planId, clearError: true));
    unawaited(_fetchInitialPage(showErrorStateWhenEmpty: true));
  }

  void setQuery(String query) {
    emit(state.copyWith(query: query, clearError: true));
    _queryDebounce?.cancel();
    _queryDebounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(_fetchInitialPage(showErrorStateWhenEmpty: true));
    });
  }

  Future<void> loadMore() async {
    if (state.loadingMore || state.loading || !state.hasMore) return;
    emit(state.copyWith(loadingMore: true));
    try {
      final page = await _repository.getSessions(
        cursor: state.nextCursor,
        limit: 20,
        status: state.statusFilter,
        planId: state.planFilter,
        query: state.query,
      );
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
        status: state.statusFilter,
        planId: state.planFilter,
        query: state.query,
      );
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

