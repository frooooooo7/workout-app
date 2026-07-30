import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/training/domain/models/training_history_models.dart';
import 'package:gym/features/training/presentation/bloc/training_history_cubit.dart';
import 'package:gym/features/training/presentation/widgets/training_last_session_section.dart';

void main() {
  testWidgets('shows last session with actions', (tester) async {
    final item = _session('s1', 'Push Power', '+320 kg objętości');
    TrainingSessionListItem? opened;
    TrainingSessionListItem? repeated;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainingLastSessionSection(
            state: TrainingHistoryState(loading: false, items: [item]),
            onOpenDetails: (value) => opened = value,
            onRepeat: (value) => repeated = value,
          ),
        ),
      ),
    );

    expect(find.text('Push Power'), findsOneWidget);
    expect(find.text('Czas'), findsOneWidget);
    expect(find.text('Ćwiczenia'), findsOneWidget);
    expect(find.text('Serie'), findsOneWidget);
    expect(find.text('Klatka'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('last-session-details')));
    await tester.pump();
    expect(opened, same(item));

    await tester.tap(find.byKey(const ValueKey('last-session-repeat')));
    await tester.pump();
    expect(repeated, same(item));
  });

  testWidgets('shows empty state when there are no completed sessions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainingLastSessionSection(
            state: TrainingHistoryState(loading: false, items: const []),
            onOpenDetails: (_) {},
            onRepeat: (_) {},
          ),
        ),
      ),
    );

    expect(
      find.text('Ukończ pierwszy trening, a tutaj go zobaczysz.'),
      findsOneWidget,
    );
  });

  test('relativeTrainingDayLabel formats recent days', () {
    final now = DateTime(2026, 7, 29);
    expect(
      relativeTrainingDayLabel(DateTime(2026, 7, 29, 10), now: now),
      'Dzisiaj',
    );
    expect(
      relativeTrainingDayLabel(DateTime(2026, 7, 28, 10), now: now),
      'Wczoraj',
    );
    expect(
      relativeTrainingDayLabel(DateTime(2026, 7, 27, 10), now: now),
      '2 dni temu',
    );
  });
}

TrainingSessionListItem _session(String id, String name, String highlight) {
  return TrainingSessionListItem(
    id: id,
    startedAt: DateTime.utc(2026, 7, 27, 16),
    endedAt: DateTime.utc(2026, 7, 27, 17),
    durationSec: 3120,
    status: TrainingSessionStatus.completed,
    plan: TrainingPlanSummary(id: 'p-$id', name: name),
    exercisesCount: 6,
    completedSetsCount: 18,
    hasNote: false,
    progressHighlight: TrainingProgressHighlight(
      type: TrainingProgressHighlightType.volumeIncrease,
      label: highlight,
    ),
    updatedAt: DateTime.utc(2026, 7, 27, 17),
  );
}
