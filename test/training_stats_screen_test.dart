import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/training/domain/models/training_session.dart';
import 'package:gym/features/training/domain/repositories/training_stats_repository.dart';
import 'package:gym/features/training/presentation/screens/training_stats_screen.dart';
import 'package:gym/features/training/presentation/widgets/session_details/session_section_card.dart';
import 'package:gym/features/training/presentation/widgets/stats/stats_kpi_grid.dart';

class _FakeStatsRepository implements TrainingStatsRepository {
  _FakeStatsRepository(this.sessions, {this.fail = false});

  List<TrainingSession> sessions;
  bool fail;
  int allReads = 0;

  @override
  Future<List<TrainingSession>> completedSessionsSince(DateTime from) async =>
      sessions;

  @override
  Future<List<TrainingSession>> allCompletedSessions() async {
    allReads++;
    if (fail) throw Exception('db');
    return sessions;
  }
}

TrainingSession _session(DateTime startLocal, {String weight = '80'}) {
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
            actualWeight: weight,
            actualReps: '10',
            completed: true,
          ),
        ],
      ),
    ],
  );
}

Future<void> _pump(
  WidgetTester tester,
  _FakeStatsRepository repository, {
  ChangeNotifier? changes,
}) async {
  tester.view.physicalSize = const Size(390, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: TrainingStatsScreen(
        repository: repository,
        dataChanges: changes ?? ChangeNotifier(),
        clock: () => DateTime(2026, 9, 16, 12),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Finder _tile(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(StatsKpiTile));

void main() {
  testWidgets('shows KPIs for 30 days with change vs previous period', (
    tester,
  ) async {
    final repository = _FakeStatsRepository([
      _session(DateTime(2026, 9, 15, 18)),
      _session(DateTime(2026, 9, 3, 18)),
      _session(DateTime(2026, 8, 1, 18)), // poprzednie 30 dni
    ]);
    await _pump(tester, repository);

    expect(find.text('Statystyki'), findsOneWidget);
    expect(find.text('30 dni'), findsOneWidget);
    expect(find.textContaining('kcal'), findsNothing);

    expect(
      find.descendant(of: _tile('Treningi'), matching: find.text('+1')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: _tile('Objętość'), matching: find.text('+100%')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _tile('Czas'),
        matching: find.textContaining('1 h 30'),
      ),
      findsOneWidget,
    );
    // 80 kg × 10 × 2 sesje.
    expect(
      find.descendant(
        of: _tile('Objętość'),
        matching: find.textContaining('1 600'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('7 dni'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.descendant(of: _tile('Czas'), matching: find.textContaining('45')),
      findsOneWidget,
    );
    expect(repository.allReads, 1, reason: 'range change reuses loaded data');
  });

  testWidgets('renders every section card without layout errors', (
    tester,
  ) async {
    await _pump(
      tester,
      _FakeStatsRepository([
        _session(DateTime(2026, 9, 15, 18), weight: '85'),
        _session(DateTime(2026, 9, 10, 18)),
        _session(DateTime(2026, 9, 3, 18), weight: '75'),
      ]),
    );

    for (final title in [
      'Przebieg w czasie',
      'Rekordy',
      'Partie mięśni',
      'Progres ćwiczeń',
      'Najczęstsze ćwiczenia',
      'Aktywność',
      'Nawyki treningowe',
    ]) {
      // „Rekordy” to też etykieta kafelka — szukamy tytułu karty sekcji.
      final card = find.widgetWithText(SessionSectionCard, title);
      await tester.scrollUntilVisible(
        card,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(card, findsOneWidget, reason: title);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('chart metric survives a range change', (tester) async {
    await _pump(
      tester,
      _FakeStatsRepository([
        _session(DateTime(2026, 9, 15, 18)),
        _session(DateTime(2026, 9, 3, 18)),
      ]),
    );
    final trend = find.widgetWithText(SessionSectionCard, 'Przebieg w czasie');
    await tester.scrollUntilVisible(
      trend,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.descendant(of: trend, matching: find.text('Serie')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('serie łącznie'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('3 mies.'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('3 mies.'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('serie łącznie'), findsOneWidget);
  });

  testWidgets('"all" range has no comparison, shows captions instead', (
    tester,
  ) async {
    await _pump(
      tester,
      _FakeStatsRepository([_session(DateTime(2026, 9, 15, 18))]),
    );

    await tester.tap(find.text('Całość'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('vs poprz.'), findsNothing);
    expect(find.text('1 dzień z treningiem'), findsOneWidget);
  });

  testWidgets('empty range suggests the whole history', (tester) async {
    await _pump(
      tester,
      _FakeStatsRepository([_session(DateTime(2026, 3, 1, 18))]),
    );

    expect(find.text('Brak treningów w tym okresie.'), findsOneWidget);
    await tester.tap(find.text('Pokaż całość'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Brak treningów w tym okresie.'), findsNothing);
  });

  testWidgets('no history shows an invitation instead of zeros', (
    tester,
  ) async {
    await _pump(tester, _FakeStatsRepository([]));

    expect(find.text('Tu pojawią się Twoje statystyki'), findsOneWidget);
    expect(find.text('Rozpocznij trening'), findsOneWidget);
    expect(find.byType(StatsKpiTile), findsNothing);
  });

  testWidgets('failure offers a retry that reloads', (tester) async {
    final repository = _FakeStatsRepository([
      _session(DateTime(2026, 9, 15, 18)),
    ], fail: true);
    await _pump(tester, repository);

    expect(find.text('Nie udało się policzyć statystyk.'), findsOneWidget);

    repository.fail = false;
    await tester.tap(find.text('Spróbuj ponownie'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(StatsKpiTile), findsNWidgets(6));
  });

  testWidgets('reloads when session data changes', (tester) async {
    final changes = ChangeNotifier();
    final repository = _FakeStatsRepository([
      _session(DateTime(2026, 9, 15, 18)),
    ]);
    await _pump(tester, repository, changes: changes);

    repository.sessions = [
      _session(DateTime(2026, 9, 15, 18)),
      _session(DateTime(2026, 9, 16, 8)),
    ];
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    changes.notifyListeners();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repository.allReads, 2);
    expect(
      find.descendant(of: _tile('Treningi'), matching: find.text('2')),
      findsOneWidget,
    );
  });
}
