import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/training/domain/models/training_history_models.dart';
import 'package:gym/features/training/domain/repositories/training_history_repository.dart';
import 'package:gym/features/training/presentation/bloc/workout_history_cubit.dart';

void main() {
  group('WorkoutHistoryCubit', () {
    test('loads month data and calculates stats correctly', () async {
      final june2026 = DateTime(2026, 6, 1);
      final session1 = _session('s1', startedAt: DateTime.utc(2026, 6, 10, 10), durationSec: 3600, exercisesCount: 4, volume: 2000);
      final session2 = _session('s2', startedAt: DateTime.utc(2026, 6, 15, 14), durationSec: 5400, exercisesCount: 6, volume: 3500);

      final repository = _FakeTrainingHistoryRepository(sessions: [session1, session2]);
      final cubit = WorkoutHistoryCubit(repository);

      await cubit.loadMonthData(june2026);

      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.focusedMonth, DateTime(2026, 6, 1));
      expect(cubit.state.monthlyHistory, isNotNull);

      final stats = cubit.state.monthlyHistory!.stats;
      expect(stats.totalSessions, 2);
      expect(stats.totalDurationSec, 9000);
      expect(stats.totalExercises, 10);
      expect(stats.totalVolumeKg, 5500);
      expect(stats.avgSessionDurationSec, 4500);

      final days = cubit.state.monthlyHistory!.trainingDays;
      expect(days.length, 2);
      expect(days.contains(DateTime(2026, 6, 10)), isTrue);
      expect(days.contains(DateTime(2026, 6, 15)), isTrue);

      await cubit.close();
    });

    test('filters sessions by selected day', () async {
      final session1 = _session('s1', startedAt: DateTime.utc(2026, 7, 10, 10));
      final session2 = _session('s2', startedAt: DateTime.utc(2026, 7, 15, 14));

      final repository = _FakeTrainingHistoryRepository(sessions: [session1, session2]);
      final cubit = WorkoutHistoryCubit(repository);

      await cubit.loadMonthData(DateTime(2026, 7, 1));
      expect(cubit.state.filteredSessions.length, 2);

      // Select July 10th
      cubit.toggleDaySelection(DateTime(2026, 7, 10));
      expect(cubit.state.selectedDay, DateTime(2026, 7, 10));
      expect(cubit.state.filteredSessions.length, 1);
      expect(cubit.state.filteredSessions.first.id, 's1');

      // Toggling same day clears filter
      cubit.toggleDaySelection(DateTime(2026, 7, 10));
      expect(cubit.state.selectedDay, isNull);
      expect(cubit.state.filteredSessions.length, 2);

      await cubit.close();
    });

    test('never requests more than the backend page limit', () async {
      final repository = _FakeTrainingHistoryRepository(
        sessions: [_session('s1', startedAt: DateTime.utc(2026, 6, 10, 10))],
      );
      final cubit = WorkoutHistoryCubit(repository);

      await cubit.loadMonthData(DateTime(2026, 6, 1));

      expect(repository.requestedLimits, isNotEmpty);
      expect(
        repository.requestedLimits.every(
          (limit) => limit <= TrainingHistoryRepository.maxPageSize,
        ),
        isTrue,
        reason: 'większy limit backend odrzuca błędem 400 invalid_limit',
      );
      expect(cubit.state.monthlyHistory!.sessions, hasLength(1));
      expect(cubit.state.fromCache, isFalse);
      expect(cubit.state.error, isNull);

      await cubit.close();
    });

    test('pages through months with more sessions than one page', () async {
      final sessions = List.generate(
        120,
        (i) => _session('s$i', startedAt: DateTime.utc(2026, 6, 1 + (i % 28), 10)),
      );
      final repository = _FakeTrainingHistoryRepository(sessions: sessions);
      final cubit = WorkoutHistoryCubit(repository);

      await cubit.loadMonthData(DateTime(2026, 6, 1));

      expect(cubit.state.monthlyHistory!.sessions, hasLength(120));
      expect(cubit.state.monthlyHistory!.stats.totalSessions, 120);
      expect(cubit.state.fromCache, isFalse);

      await cubit.close();
    });

    test('surfaces an error instead of a fake offline state on failure',
        () async {
      final repository =
          _FakeTrainingHistoryRepository(sessions: [], failEverything: true);
      final cubit = WorkoutHistoryCubit(repository);

      await cubit.loadMonthData(DateTime(2026, 6, 1));

      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.error, isNotNull);
      expect(cubit.state.monthlyHistory, isNull);
      expect(cubit.state.fromCache, isFalse);

      await cubit.close();
    });

    test('switches focused month', () async {
      final repository = _FakeTrainingHistoryRepository(sessions: []);
      final cubit = WorkoutHistoryCubit(repository);

      final targetMonth = DateTime(2026, 5, 1);
      cubit.selectMonth(targetMonth);
      await Future.delayed(Duration.zero);

      expect(cubit.state.focusedMonth, targetMonth);

      await cubit.close();
    });
  });
}

TrainingSessionListItem _session(
  String id, {
  required DateTime startedAt,
  int durationSec = 3600,
  int exercisesCount = 5,
  double volume = 2500,
}) {
  return TrainingSessionListItem(
    id: id,
    startedAt: startedAt,
    endedAt: startedAt.add(Duration(seconds: durationSec)),
    durationSec: durationSec,
    status: TrainingSessionStatus.completed,
    plan: const TrainingPlanSummary(id: 'plan1', name: 'Plan A'),
    exercisesCount: exercisesCount,
    completedSetsCount: 15,
    hasNote: false,
    updatedAt: startedAt.add(const Duration(hours: 1)),
    totalVolumeKg: volume,
  );
}

/// Odwzorowuje kontrakt backendu: `limit > 50` kończy się błędem
/// `invalid_limit` (400), a wyniki są stronicowane kursorem.
class _FakeTrainingHistoryRepository implements TrainingHistoryRepository {
  _FakeTrainingHistoryRepository({
    required this.sessions,
    this.failEverything = false,
  });

  final List<TrainingSessionListItem> sessions;
  final bool failEverything;

  final List<int> requestedLimits = [];

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
    requestedLimits.add(limit);
    if (failEverything) throw Exception('network_error');
    if (limit > TrainingHistoryRepository.maxPageSize) {
      throw Exception('invalid_limit');
    }

    final offset = cursor == null ? 0 : int.parse(cursor);
    final slice = sessions.skip(offset).take(limit).toList();
    final nextOffset = offset + slice.length;
    final hasMore = nextOffset < sessions.length;

    return TrainingSessionPage(
      items: slice,
      nextCursor: hasMore ? '$nextOffset' : null,
      hasMore: hasMore,
      isFromCache: false,
    );
  }
}
