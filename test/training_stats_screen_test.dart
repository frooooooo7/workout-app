import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/widgets/app_tab_header.dart';
import 'package:gym/features/profile/domain/models/body_weight_entry.dart';
import 'package:gym/features/profile/domain/repositories/body_weight_repository.dart';
import 'package:gym/features/training/domain/models/training_session.dart';
import 'package:gym/features/training/domain/repositories/training_stats_repository.dart';
import 'package:gym/features/training/presentation/screens/training_stats_screen.dart';
import 'package:gym/features/training/presentation/widgets/session_details/session_section_card.dart';

import 'body_weight_test.dart' show FakeBodyWeightRepository;

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
  int? weeklyGoal,
  BodyWeightRepository? bodyWeight,
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
        weeklyGoalLoader: () async => weeklyGoal,
        bodyWeightRepository: bodyWeight,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// Wejście w kartę pulpitu: stuknięcie w jej nagłówek otwiera szczegóły.
Future<void> _openCard(WidgetTester tester, String title) async {
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
}

Finder _inHeader(String title) =>
    find.descendant(of: find.byType(AppTabHeader), matching: find.text(title));

void main() {
  testWidgets('body weight card shows the change within the stats range', (
    tester,
  ) async {
    final repository = _FakeStatsRepository([
      _session(DateTime(2026, 9, 15, 18)),
    ]);
    final bodyWeight = FakeBodyWeightRepository([
      BodyWeightEntry(date: DateTime(2026, 7, 1), weightKg: 90),
      BodyWeightEntry(date: DateTime(2026, 8, 20), weightKg: 84),
      BodyWeightEntry(date: DateTime(2026, 9, 14), weightKg: 82.8),
    ]);
    await _pump(tester, repository, bodyWeight: bodyWeight);
    await tester.pumpAndSettle();

    expect(find.text('MASA CIAŁA'), findsOneWidget);
    expect(find.text('82,8 kg'), findsOneWidget);
    expect(find.text('−1,2 kg w tym okresie'), findsOneWidget);
  });

  testWidgets('body weight card hides when weights cannot load', (
    tester,
  ) async {
    final repository = _FakeStatsRepository([
      _session(DateTime(2026, 9, 15, 18)),
    ]);
    final bodyWeight = FakeBodyWeightRepository()..listError = Exception('x');
    await _pump(tester, repository, bodyWeight: bodyWeight);
    await tester.pumpAndSettle();

    expect(find.text('MASA CIAŁA'), findsNothing);
  });

  testWidgets('summary shows the count, the change and three totals', (
    tester,
  ) async {
    final repository = _FakeStatsRepository([
      _session(DateTime(2026, 9, 15, 18)),
      _session(DateTime(2026, 9, 3, 18)),
      _session(DateTime(2026, 8, 1, 18)), // poprzednie 30 dni
    ]);
    await _pump(tester, repository);

    expect(find.text('Statystyki'), findsOneWidget);
    expect(find.text('OSTATNIE 30 DNI'), findsOneWidget);
    expect(find.text('vs poprzednie 30 dni'), findsOneWidget);
    expect(find.textContaining('kcal'), findsNothing);
    expect(find.text('2'), findsWidgets);
    expect(find.text('treningi'), findsOneWidget);
    // 80 kg × 10 × 2 sesje, 2 × 45 min.
    expect(find.textContaining('1 600', findRichText: true), findsOneWidget);
    expect(find.textContaining('1 h 30', findRichText: true), findsOneWidget);
    expect(find.text('objętość'), findsOneWidget);
    expect(find.text('na treningach'), findsOneWidget);
    expect(find.text('serii'), findsOneWidget);

    await tester.tap(find.text('7 dni'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('OSTATNIE 7 DNI'), findsOneWidget);
    expect(find.text('1'), findsWidgets);
    expect(find.text('trening'), findsOneWidget);
    expect(find.textContaining('45', findRichText: true), findsWidgets);
    expect(repository.allReads, 1, reason: 'range change reuses loaded data');
  });

  testWidgets('the dashboard has six cards and no tabs', (tester) async {
    await _pump(
      tester,
      _FakeStatsRepository([
        _session(DateTime(2026, 9, 15, 18), weight: '85'),
        _session(DateTime(2026, 9, 10, 18)),
        _session(DateTime(2026, 9, 3, 18), weight: '75'),
      ]),
      weeklyGoal: 3,
      bodyWeight: FakeBodyWeightRepository([
        BodyWeightEntry(date: DateTime(2026, 9, 14), weightKg: 82.8),
      ]),
    );
    // Cel z profilu dociąga się po pierwszym rysunku.
    await tester.pump(const Duration(milliseconds: 300));

    for (final title in [
      'OSTATNIE 30 DNI',
      'SIŁA',
      'REKORDY',
      'MIĘŚNIE',
      'REGULARNOŚĆ',
      'MASA CIAŁA',
    ]) {
      final card = find.text(title);
      await tester.scrollUntilVisible(
        card,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(card, findsOneWidget, reason: title);
    }
    // Żadnych zakładek, kafelków i mapy aktywności.
    for (final old in [
      'Przegląd',
      'Postępy',
      'Ciało',
      'Aktywność',
      'Wnioski',
    ]) {
      expect(find.text(old), findsNothing, reason: old);
    }
    // Cel w profilu: pigułka celu pod liczbą treningów.
    expect(find.textContaining('cel w '), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('each card opens its own details screen', (tester) async {
    await _pump(
      tester,
      _FakeStatsRepository([
        _session(DateTime(2026, 9, 15, 18), weight: '85'),
        _session(DateTime(2026, 9, 10, 18)),
        _session(DateTime(2026, 9, 3, 18), weight: '75'),
      ]),
      weeklyGoal: 3,
    );
    await tester.pump(const Duration(milliseconds: 300));

    Future<void> back() async {
      await tester.tap(find.byTooltip('Wstecz'));
      await tester.pumpAndSettle();
    }

    await _openCard(tester, 'Przebieg w czasie');
    expect(_inHeader('Przebieg'), findsOneWidget);
    expect(find.text('Objętość'), findsOneWidget);
    await back();

    await _openCard(tester, 'SIŁA');
    expect(_inHeader('Siła'), findsOneWidget);
    expect(find.text('Szac. 1RM'), findsOneWidget);
    expect(find.text('Wszystkie ćwiczenia'), findsOneWidget);
    expect(find.text('Jak trenujesz'), findsOneWidget);
    await back();

    await _openCard(tester, 'REKORDY');
    expect(_inHeader('Rekordy'), findsOneWidget);
    expect(find.text('Rekordy w tym okresie'), findsOneWidget);
    expect(find.text('Najlepsze treningi'), findsOneWidget);
    await back();

    await _openCard(tester, 'MIĘŚNIE');
    expect(_inHeader('Mięśnie'), findsOneWidget);
    expect(find.text('Serie w tygodniu'), findsOneWidget);
    expect(find.text('Ranking mięśni'), findsOneWidget);
    await back();

    await _openCard(tester, 'REGULARNOŚĆ');
    expect(_inHeader('Regularność'), findsOneWidget);
    expect(find.text('Cel tygodnia'), findsOneWidget);
    expect(find.text('Kiedy trenujesz'), findsOneWidget);
    // Jedna passa — dawne „Seria celu”/„Seria tygodni” znikają.
    expect(find.textContaining('Seria celu'), findsNothing);
    await back();
    expect(tester.takeException(), isNull);
  });

  testWidgets('without a weekly goal the streak card stands in for it', (
    tester,
  ) async {
    await _pump(
      tester,
      _FakeStatsRepository([_session(DateTime(2026, 9, 15, 18))]),
    );
    expect(find.textContaining('cel w '), findsNothing);

    await _openCard(tester, 'REGULARNOŚĆ');
    expect(
      find.widgetWithText(SessionSectionCard, 'Cel tygodnia'),
      findsNothing,
    );
    expect(find.widgetWithText(SessionSectionCard, 'Passa'), findsOneWidget);
  });

  testWidgets('the calendar button opens the range picker', (tester) async {
    await _pump(
      tester,
      _FakeStatsRepository([_session(DateTime(2026, 9, 15, 18))]),
    );

    // Nagłówek wbudowanego kalendarza nie mieści się w wąskim oknie przy
    // szerokiej czcionce testowej — to jego, nie nasz układ.
    tester.view.physicalSize = const Size(800, 1600);
    await tester.tap(find.byIcon(Icons.date_range_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(DateRangePickerDialog), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byType(DateRangePickerDialog), findsNothing);
    expect(find.text('Statystyki'), findsOneWidget);
  });

  testWidgets('details share the range with the dashboard', (tester) async {
    final repository = _FakeStatsRepository([
      _session(DateTime(2026, 9, 15, 18)),
      _session(DateTime(2026, 9, 3, 18)),
    ]);
    await _pump(tester, repository);

    await _openCard(tester, 'Przebieg w czasie');
    final chip = find.byKey(const ValueKey('stats-range-chip-button'));
    expect(
      find.descendant(of: chip, matching: find.text('30 dni')),
      findsOneWidget,
    );

    // Miara wykresu zostaje po zmianie zakresu na tym samym ekranie.
    await tester.tap(find.text('Serie'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('serie łącznie'), findsOneWidget);

    await tester.tap(chip);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stats-range-quarter')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: chip, matching: find.text('3 mies.')),
      findsOneWidget,
    );
    expect(find.text('serie łącznie'), findsOneWidget, reason: 'metric kept');

    // Pulpit pod spodem ma ten sam zakres.
    await tester.tap(find.byTooltip('Wstecz'));
    await tester.pumpAndSettle();
    expect(find.text('OSTATNIE 3 MIESIĄCE'), findsOneWidget);
    expect(repository.allReads, 1, reason: 'range change reuses loaded data');
  });

  testWidgets('empty range keeps whole-history cards, hides the rest', (
    tester,
  ) async {
    await _pump(tester, _FakeStatsRepository([_session(DateTime(2026, 1, 5))]));

    expect(find.text('Brak treningów w tym okresie.'), findsOneWidget);
    expect(find.text('SIŁA'), findsNothing);
    expect(find.text('MIĘŚNIE'), findsNothing);
    expect(find.text('REKORDY'), findsOneWidget);
    expect(find.text('REGULARNOŚĆ'), findsOneWidget);

    // Na ekranie Mięśnie zostaje regeneracja z całej historii.
    await _openCard(tester, 'REKORDY');
    expect(find.text('Rekordy w tym okresie'), findsOneWidget);
  });

  testWidgets('"all" range has no comparison', (tester) async {
    await _pump(
      tester,
      _FakeStatsRepository([_session(DateTime(2026, 9, 15, 18))]),
    );

    await tester.tap(find.text('Całość'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('CAŁA HISTORIA'), findsOneWidget);
    expect(find.textContaining('vs poprzednie'), findsNothing);
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
    expect(find.text('OSTATNIE 30 DNI'), findsNothing);
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

    expect(find.text('OSTATNIE 30 DNI'), findsOneWidget);
  });

  testWidgets('reloads when session data changes', (tester) async {
    final changes = ChangeNotifier();
    final repository = _FakeStatsRepository([
      _session(DateTime(2026, 9, 15, 18)),
    ]);
    await _pump(tester, repository, changes: changes);
    expect(find.text('trening'), findsOneWidget);

    repository.sessions = [
      _session(DateTime(2026, 9, 15, 18)),
      _session(DateTime(2026, 9, 16, 8)),
    ];
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    changes.notifyListeners();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repository.allReads, 2);
    expect(find.text('treningi'), findsOneWidget);
  });
}
