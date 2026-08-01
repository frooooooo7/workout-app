import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/services/service_locator.dart';
import 'package:gym/features/training/domain/models/training_history_models.dart';
import 'package:gym/features/training/domain/repositories/training_history_repository.dart';
import 'package:gym/features/training/presentation/screens/history_screen.dart';
import 'package:gym/features/training/presentation/widgets/workout_history/month_selector_bar.dart';
import 'package:gym/features/training/presentation/widgets/workout_history/monthly_sessions_list.dart';
import 'package:gym/features/training/presentation/widgets/workout_history/monthly_stats_card.dart';

void main() {
  setUp(() {
    ServiceLocator.debugSetUserScopedRepositories(
      trainingHistoryRepository: _FakeTrainingHistoryRepository(
        sessions: [
          TrainingSessionListItem(
            id: 's1',
            startedAt: DateTime.utc(2026, 7, 10, 10),
            endedAt: DateTime.utc(2026, 7, 10, 11),
            durationSec: 3600,
            status: TrainingSessionStatus.completed,
            plan: const TrainingPlanSummary(id: 'p1', name: 'Plan Góra'),
            exercisesCount: 5,
            completedSetsCount: 15,
            hasNote: false,
            updatedAt: DateTime.utc(2026, 7, 10, 11),
            totalVolumeKg: 4200,
          ),
        ],
      ),
    );
  });

  tearDown(() {
    ServiceLocator.debugSetUserScopedRepositories();
  });

  testWidgets('HistoryScreen renders universal header, month selector, stats card and session list', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HistoryScreen(),
      ),
    );

    // Initial frame loading skeleton
    expect(find.byType(HistoryScreen), findsOneWidget);
    await tester.pumpAndSettle();

    // Verify Header
    expect(find.text('Historia'), findsOneWidget);
    expect(find.text('Twoje zakończone treningi'), findsOneWidget);

    // Verify Month Selector Bar
    expect(find.byType(MonthSelectorBar), findsOneWidget);

    // Verify Stats Card — „Serie" pada też w wierszu sesji, więc finder musi
    // być zawężony do karty.
    expect(find.byType(MonthlyStatsCard), findsOneWidget);
    Finder inStatsCard(String text) => find.descendant(
          of: find.byType(MonthlyStatsCard),
          matching: find.text(text),
        );
    expect(inStatsCard('Łączny czas'), findsOneWidget);
    expect(inStatsCard('Trening'), findsOneWidget);
    expect(inStatsCard('Ćwiczenia'), findsOneWidget);
    expect(inStatsCard('Serie'), findsOneWidget);

    // Verify Sessions List
    expect(find.byType(MonthlySessionsList), findsOneWidget);
    expect(find.text('Treningi w miesiącu'), findsOneWidget);
    expect(find.text('Plan Góra'), findsOneWidget);

    // Verify per-session metrics row (czas / ćwiczenia / serie / objętość)
    Finder inSessionsList(String text) => find.descendant(
          of: find.byType(MonthlySessionsList),
          matching: find.text(text),
        );
    expect(inSessionsList('Czas'), findsOneWidget);
    expect(inSessionsList('Ćwiczenia'), findsOneWidget);
    expect(inSessionsList('Serie'), findsOneWidget);
    expect(inSessionsList('Objętość'), findsOneWidget);
    expect(inSessionsList('1:00:00'), findsOneWidget); // 3600 s
    expect(inSessionsList('5'), findsOneWidget); // exercisesCount
    expect(inSessionsList('15'), findsOneWidget); // completedSetsCount
    expect(inSessionsList('4,20 t'), findsOneWidget); // 4200 kg
    expect(find.text('Zobacz wszystkie'), findsNothing);
  });
}

class _FakeTrainingHistoryRepository implements TrainingHistoryRepository {
  _FakeTrainingHistoryRepository({required this.sessions});

  final List<TrainingSessionListItem> sessions;

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
    return TrainingSessionPage(
      items: sessions,
      nextCursor: null,
      hasMore: false,
      isFromCache: false,
    );
  }
}
