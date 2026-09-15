import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/training/domain/models/training_session.dart';
import 'package:gym/features/training/domain/repositories/training_stats_repository.dart';
import 'package:gym/features/training/presentation/screens/training_stats_screen.dart';

class _FakeStatsRepository implements TrainingStatsRepository {
  _FakeStatsRepository(this.sessions);

  final List<TrainingSession> sessions;
  DateTime? requestedFrom;

  @override
  Future<List<TrainingSession>> completedSessionsSince(DateTime from) async {
    requestedFrom = from;
    return sessions;
  }
}

TrainingSession _session(DateTime startLocal) {
  return TrainingSession(
    planName: 'Push',
    status: TrainingSessionStatus.completed,
    startedAt: startLocal.toUtc(),
    finishedAt: startLocal.add(const Duration(minutes: 45)).toUtc(),
    exercises: [
      TrainingSessionExercise(
        exerciseId: 'bench',
        exerciseName: 'Wyciskanie',
        exerciseMuscles: const ['chest'],
        exerciseCategory: 'compound',
        sets: [
          TrainingSessionSet(
            actualWeight: '80',
            actualReps: '10',
            completed: true,
          ),
        ],
      ),
    ],
  );
}

void main() {
  testWidgets('shows real week/month stats without calories', (tester) async {
    final repository = _FakeStatsRepository([
      _session(DateTime(2026, 9, 15, 18)),
      _session(DateTime(2026, 9, 3, 18)),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: TrainingStatsScreen(
          repository: repository,
          dataChanges: ChangeNotifier(),
          clock: () => DateTime(2026, 9, 16, 12),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Statystyki'), findsOneWidget);
    expect(find.text('Podsumowanie aktywności'), findsOneWidget);
    expect(find.text('Tydzień'), findsOneWidget);
    expect(find.text('Miesiąc'), findsOneWidget);
    expect(find.text('Spalone kalorie'), findsNothing);
    expect(find.textContaining('kcal'), findsNothing);
    expect(repository.requestedFrom, DateTime(2026, 9));

    // Tydzień: 1 trening, 45 min, 800 kg.
    expect(find.text('trening'), findsOneWidget);
    expect(find.text('45 min'), findsOneWidget);
    expect(find.text('800'), findsOneWidget);

    await tester.tap(find.text('Miesiąc'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('treningi'), findsOneWidget);
    expect(find.text('1h 30 min'), findsOneWidget);
    expect(find.text('1 600'), findsOneWidget);
  });
}
