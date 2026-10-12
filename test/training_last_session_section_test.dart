import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/training/domain/models/training_history_models.dart';
import 'package:gym/features/training/presentation/bloc/training_history_cubit.dart';
import 'package:gym/features/training/presentation/widgets/training_last_session_section.dart';

void main() {
  testWidgets('shows the last session in one row and opens details', (
    tester,
  ) async {
    final item = _session('s1', 'Push Power', volumeKg: 8290);
    TrainingSessionListItem? opened;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainingLastSessionSection(
            state: TrainingHistoryState(loading: false, items: [item]),
            recordsBySession: const {'s1': 2},
            onOpenDetails: (value) => opened = value,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ostatnio: Push Power'), findsOneWidget);
    expect(find.text('pn 27 lip · 52 min · 18 serii'), findsOneWidget);
    expect(find.text('8,29 t'), findsOneWidget);
    expect(find.text('2 rekordy'), findsOneWidget);
    expect(find.text('P'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('last-session-details')));
    await tester.pump();
    expect(opened, same(item));
  });

  testWidgets('omits volume and records when unknown', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainingLastSessionSection(
            state: TrainingHistoryState(
              loading: false,
              items: [_session('s1', 'Pull')],
            ),
            onOpenDetails: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ostatnio: Pull'), findsOneWidget);
    expect(find.byKey(const ValueKey('last-session-volume')), findsNothing);
    expect(find.textContaining('rekord'), findsNothing);
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
          ),
        ),
      ),
    );

    expect(
      find.text('Ukończ pierwszy trening, a tutaj go zobaczysz.'),
      findsOneWidget,
    );
  });

  testWidgets('shows an error row when loading failed', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainingLastSessionSection(
            state: TrainingHistoryState(loading: false, error: 'offline'),
            onOpenDetails: (_) {},
          ),
        ),
      ),
    );

    expect(
      find.text('Nie udało się załadować ostatniego treningu.'),
      findsOneWidget,
    );
  });

  test('volume formatter keeps one unit while counting up', () {
    final tonnes = volumeFormatterFor(8290);
    expect(tonnes(8290), '8,29 t');
    expect(tonnes(500), '0,5 t');
    expect(volumeFormatterFor(850)(850), '850 kg');
  });
}

TrainingSessionListItem _session(String id, String name, {double? volumeKg}) {
  return TrainingSessionListItem(
    id: id,
    startedAt: DateTime(2026, 7, 27, 16),
    endedAt: DateTime(2026, 7, 27, 17),
    durationSec: 3120,
    status: TrainingSessionStatus.completed,
    plan: TrainingPlanSummary(id: 'p-$id', name: name),
    exercisesCount: 6,
    completedSetsCount: 18,
    hasNote: false,
    totalVolumeKg: volumeKg,
    updatedAt: DateTime(2026, 7, 27, 17),
  );
}
