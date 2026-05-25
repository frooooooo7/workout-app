import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/training/domain/models/training_history_models.dart';
import 'package:gym/features/training/presentation/bloc/training_history_cubit.dart';
import 'package:gym/features/training/presentation/widgets/training_recent_progress_section.dart';

void main() {
  testWidgets('shows up to three recent progress items with highlights', (
    tester,
  ) async {
    final items = [
      _session('s1', 'Push Power', '+2.5kg bench'),
      _session('s2', 'Pull Volume', '+800kg volume'),
      _session('s3', 'Leg Day', '+5kg squat'),
      _session('s4', 'Mobility', '+10 min'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainingRecentProgressSection(
            state: TrainingHistoryState(loading: false, items: items),
            onOpenSession: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Ostatnie postepy'), findsOneWidget);
    expect(find.text('Push Power'), findsOneWidget);
    expect(find.text('Pull Volume'), findsOneWidget);
    expect(find.text('Leg Day'), findsOneWidget);
    expect(find.text('Mobility'), findsNothing);
    expect(find.text('+2.5kg bench'), findsOneWidget);
    expect(find.text('+800kg volume'), findsOneWidget);
    expect(find.text('+5kg squat'), findsOneWidget);
  });

  testWidgets('opens selected session', (tester) async {
    final item = _session('s1', 'Push Power', '+2.5kg bench');
    TrainingSessionListItem? opened;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainingRecentProgressSection(
            state: TrainingHistoryState(loading: false, items: [item]),
            onOpenSession: (item) => opened = item,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Push Power'));
    await tester.pump();

    expect(opened, same(item));
  });

  testWidgets('shows empty state when there are no completed sessions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainingRecentProgressSection(
            state: TrainingHistoryState(loading: false, items: const []),
            onOpenSession: (_) {},
          ),
        ),
      ),
    );

    expect(
      find.text('Ukoncz pierwszy trening, a tutaj zobaczysz postepy.'),
      findsOneWidget,
    );
  });
}

TrainingSessionListItem _session(String id, String planName, String highlight) {
  return TrainingSessionListItem(
    id: id,
    startedAt: DateTime.utc(2026, 5, 14, 10),
    endedAt: DateTime.utc(2026, 5, 14, 11),
    durationSec: 3600,
    status: TrainingSessionStatus.completed,
    plan: TrainingPlanSummary(id: 'plan-$id', name: planName),
    exercisesCount: 5,
    completedSetsCount: 15,
    hasNote: false,
    progressHighlight: TrainingProgressHighlight(
      type: TrainingProgressHighlightType.weightIncrease,
      label: highlight,
    ),
    updatedAt: DateTime.utc(2026, 5, 14, 11, 5),
  );
}
