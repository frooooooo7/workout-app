import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/training/domain/models/training_history_models.dart';
import 'package:gym/features/training/domain/repositories/training_history_repository.dart';
import 'package:gym/features/training/presentation/bloc/training_history_cubit.dart';

void main() {
  group('TrainingHistoryCubit', () {
    test('loads initial page and appends next page', () async {
      final repository = _FakeTrainingHistoryRepository(
        firstPage: TrainingSessionPage(
          items: [_session('s1')],
          nextCursor: 'cursor-2',
          hasMore: true,
          isFromCache: false,
        ),
        secondPage: TrainingSessionPage(
          items: [_session('s2')],
          nextCursor: null,
          hasMore: false,
          isFromCache: false,
        ),
      );

      final cubit = TrainingHistoryCubit(repository);
      await cubit.refresh();
      expect(cubit.state.items.map((e) => e.id), ['s1']);

      await cubit.loadMore();
      expect(cubit.state.items.map((e) => e.id), ['s1', 's2']);
      expect(cubit.state.hasMore, isFalse);

      await cubit.close();
    });

    test('derives current week markers from a dedicated range query', () async {
      final weekSession = _session('week', startedAt: DateTime.now());
      final repository = _FakeTrainingHistoryRepository(
        firstPage: TrainingSessionPage(
          items: [_session('s1')],
          nextCursor: null,
          hasMore: false,
          isFromCache: false,
        ),
        secondPage: TrainingSessionPage(
          items: const [],
          nextCursor: null,
          hasMore: false,
          isFromCache: false,
        ),
        rangePage: TrainingSessionPage(
          items: [weekSession],
          nextCursor: null,
          hasMore: false,
          isFromCache: false,
        ),
      );

      final cubit = TrainingHistoryCubit(repository);
      await cubit.refresh();
      await Future.delayed(Duration.zero);

      expect(
        cubit.state.weekCompletedWeekdays,
        {weekSession.startedAt.toLocal().weekday},
      );
      expect(repository.lastRangeFrom, isNotNull);

      await cubit.close();
    });

    test('handles viewMode toggling and calendar session loading', () async {
      final repository = _FakeTrainingHistoryRepository(
        firstPage: TrainingSessionPage(
          items: [_session('s1')],
          nextCursor: null,
          hasMore: false,
          isFromCache: false,
        ),
        secondPage: TrainingSessionPage(
          items: [],
          nextCursor: null,
          hasMore: false,
          isFromCache: false,
        ),
      );

      final cubit = TrainingHistoryCubit(repository);
      expect(cubit.state.viewMode, HistoryViewMode.list);

      // Przełączenie widoku na kalendarz
      cubit.toggleViewMode();
      expect(cubit.state.viewMode, HistoryViewMode.calendar);
      expect(cubit.state.isCalendarLoading, isTrue);

      // Oczekiwanie na załadowanie danych kalendarza
      await Future.delayed(Duration.zero);
      expect(cubit.state.calendarSessions, isNotEmpty);
      expect(cubit.state.calendarSessions.first.id, 's1');
      expect(cubit.state.isCalendarLoading, isFalse);

      // Zmiana miesiąca w przód
      final initialMonth = cubit.state.focusedMonth;
      cubit.changeMonth(1);
      expect(cubit.state.focusedMonth.month, (initialMonth.month % 12) + 1);

      await cubit.close();
    });
  });
}

TrainingSessionListItem _session(String id, {DateTime? startedAt}) {
  final start = startedAt ?? DateTime.utc(2026, 5, 14, 10);
  return TrainingSessionListItem(
    id: id,
    startedAt: start,
    endedAt: start.add(const Duration(hours: 1)),
    durationSec: 3600,
    status: TrainingSessionStatus.completed,
    plan: const TrainingPlanSummary(id: 'plan1', name: 'Plan A'),
    exercisesCount: 5,
    completedSetsCount: 15,
    hasNote: false,
    progressHighlight: const TrainingProgressHighlight(
      type: TrainingProgressHighlightType.weightIncrease,
      label: '+2.5kg',
    ),
    updatedAt: DateTime.utc(2026, 5, 14, 11, 5),
  );
}

class _FakeTrainingHistoryRepository implements TrainingHistoryRepository {
  _FakeTrainingHistoryRepository({
    required this.firstPage,
    required this.secondPage,
    this.rangePage,
  });

  final TrainingSessionPage firstPage;
  final TrainingSessionPage secondPage;
  final TrainingSessionPage? rangePage;

  DateTime? lastRangeFrom;

  @override
  Future<TrainingSessionDetail> getSessionDetail(String sessionId) {
    throw UnimplementedError();
  }

  @override
  Future<TrainingSessionPage> getSessions({
    String? cursor,
    int limit = 20,
    TrainingSessionStatus? status,
    String? planId,
    String? query,
    DateTime? from,
    DateTime? to,
  }) async {
    if (from != null) {
      lastRangeFrom = from;
      if (rangePage != null) return rangePage!;
    }
    return cursor == null ? firstPage : secondPage;
  }
}

