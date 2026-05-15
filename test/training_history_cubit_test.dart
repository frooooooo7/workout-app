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
  });
}

TrainingSessionListItem _session(String id) {
  return TrainingSessionListItem(
    id: id,
    startedAt: DateTime.utc(2026, 5, 14, 10),
    endedAt: DateTime.utc(2026, 5, 14, 11),
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
  });

  final TrainingSessionPage firstPage;
  final TrainingSessionPage secondPage;

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
    return cursor == null ? firstPage : secondPage;
  }
}

