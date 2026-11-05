import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gym/core/services/service_locator.dart';
import 'package:gym/core/theme/app_localization.dart';
import 'package:gym/features/training/domain/models/training_history_models.dart';
import 'package:gym/features/training/domain/models/training_session.dart'
    as session;
import 'package:gym/features/training/domain/repositories/training_history_repository.dart';
import 'package:gym/features/training/domain/repositories/training_stats_repository.dart';
import 'package:gym/features/training/presentation/screens/history_screen.dart';
import 'package:gym/features/training/presentation/widgets/stats/stats_range_selector.dart';
import 'package:gym/features/training/presentation/widgets/workout_history/history_calendar_sheet.dart';
import 'package:gym/features/training/presentation/widgets/workout_history/history_formatters.dart';
import 'package:gym/features/training/presentation/widgets/workout_history/history_month_calendar.dart';
import 'package:gym/features/training/presentation/widgets/workout_history/history_month_navigator.dart';
import 'package:gym/features/training/presentation/widgets/workout_history/history_compact_row.dart';
import 'package:gym/features/training/presentation/widgets/workout_history/history_latest_card.dart';
import 'package:gym/features/training/presentation/widgets/workout_history/history_session_row.dart';
import 'package:shared_preferences/shared_preferences.dart';

session.TrainingSession _session(
  String id,
  DateTime startedAt, {
  String plan = 'Push',
  List<(String, String, String)> sets = const [('Wyciskanie', '90', '5')],
  String? note,
}) => session.TrainingSession(
  id: id,
  planName: plan,
  planLocalId: 'plan-$plan',
  status: session.TrainingSessionStatus.completed,
  startedAt: startedAt.toUtc(),
  finishedAt: startedAt.add(const Duration(hours: 1)).toUtc(),
  note: note,
  exercises: [
    for (final (name, weight, reps) in sets)
      session.TrainingSessionExercise(
        exerciseId: name,
        exerciseName: name,
        exerciseMuscles: const [],
        exerciseCategory: 'strength',
        sets: [
          session.TrainingSessionSet(
            actualWeight: weight,
            actualReps: reps,
            completed: true,
          ),
        ],
      ),
  ],
);

TrainingSessionListItem _serverItem(String id, DateTime startedAt) =>
    TrainingSessionListItem(
      id: id,
      startedAt: startedAt.toUtc(),
      endedAt: startedAt.add(const Duration(hours: 1)).toUtc(),
      durationSec: 3600,
      status: TrainingSessionStatus.completed,
      plan: TrainingPlanSummary(id: 'p-$id', name: 'Plan Serwer'),
      exercisesCount: 5,
      completedSetsCount: 15,
      hasNote: false,
      updatedAt: startedAt.toUtc(),
      totalVolumeKg: 4200,
    );

void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  // Dzisiejszy trening o 01:00 albo teraz, jeśli jest wcześniej — inaczej
  // tuż po północy wypadałby w przyszłości i znikał z historii.
  final todayWorkout = today.add(const Duration(hours: 1)).isAfter(now)
      ? now.subtract(const Duration(minutes: 1))
      : today.add(const Duration(hours: 1));

  // Stary Push z 80 kg, dzisiejszy z 100 kg (rekord), Legs tydzień temu.
  List<session.TrainingSession> localSessions() => [
    _session(
      'old',
      today.subtract(const Duration(days: 40)).add(const Duration(hours: 18)),
      sets: const [('Wyciskanie', '80', '5')],
    ),
    _session(
      'legs',
      today.subtract(const Duration(days: 7)).add(const Duration(hours: 18)),
      plan: 'Legs',
      sets: const [('Przysiad', '120', '5'), ('Martwy ciąg', '140', '3')],
      note: 'Kolana w porządku',
    ),
    _session(
      'today',
      todayWorkout,
      sets: const [
        ('Wyciskanie', '100', '5'),
        ('OHP', '50', '8'),
        ('Rozpiętki', '20', '12'),
        ('Dipy', '30', '6'),
      ],
    ),
  ];

  void setUpRepositories({
    List<session.TrainingSession>? local,
    List<TrainingSessionListItem> server = const [],
  }) {
    ServiceLocator.debugSetUserScopedRepositories(
      trainingHistoryRepository: _FakeTrainingHistoryRepository(
        sessions: server,
      ),
      trainingStatsRepository: _FakeStatsRepository(local ?? localSessions()),
    );
  }

  setUp(setUpRepositories);

  tearDown(() {
    ServiceLocator.debugSetUserScopedRepositories();
  });

  // Telefon wysoki na tyle, żeby kilka kart było na ekranie.
  void useTallPhone(WidgetTester tester, {double width = 390}) {
    tester.view.physicalSize = Size(width * 3, 1600 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Finder inLatest(String text) => find.descendant(
    of: find.byType(HistoryLatestCard),
    matching: find.text(text),
  );

  Future<void> openHistory(WidgetTester tester, {double width = 390}) async {
    useTallPhone(tester, width: width);
    await tester.pumpWidget(const MaterialApp(home: HistoryScreen()));
    await tester.pumpAndSettle();
  }

  Future<void> openCalendar(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Kalendarz'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the last workout as a card and earlier ones as rows', (
    tester,
  ) async {
    await openHistory(tester);

    expect(find.text('Historia'), findsOneWidget);
    // Kalendarza nie ma na liście — siedzi pod ikonką w nagłówku.
    expect(find.byType(HistoryMonthCalendar), findsNothing);
    expect(find.byType(HistoryMonthNavigator), findsNothing);
    expect(find.byTooltip('Kalendarz'), findsOneWidget);

    // Karta ostatniego treningu: plan, kiedy, trzy główne ćwiczenia.
    expect(find.byType(HistoryLatestCard), findsOneWidget);
    expect(inLatest('Push'), findsOneWidget);
    expect(find.text('OSTATNI TRENING · DZIŚ'), findsOneWidget);
    expect(inLatest('Wyciskanie'), findsOneWidget);
    expect(inLatest('OHP'), findsOneWidget);
    expect(inLatest('Rozpiętki'), findsOneWidget);
    expect(inLatest('Dipy'), findsNothing);
    // Rekord tylko na dzisiejszym Pushu.
    expect(find.text('rekord'), findsOneWidget);

    // Reszta to zwarte wiersze pod „Wcześniej”, bez dzisiejszego treningu.
    expect(find.text('Wcześniej'), findsOneWidget);
    expect(find.byType(HistoryCompactRow), findsNWidgets(2));
    expect(
      find.descendant(
        of: find.byType(HistoryCompactRow),
        matching: find.text('Legs'),
      ),
      findsOneWidget,
    );
    // Bez pasków filtrów i nagłówków tygodni.
    expect(find.text('Wszystkie'), findsNothing);
    expect(
      find.textContaining('Ten tydzień', findRichText: true),
      findsNothing,
    );
  });

  testWidgets('the card compares with the previous workout of the plan', (
    tester,
  ) async {
    await openHistory(tester);

    // Dziś 1,32 t, poprzedni Push 400 kg.
    expect(inLatest('1,32'), findsOneWidget);
    expect(inLatest('230%'), findsOneWidget);
    expect(find.byKey(const ValueKey('latest-footnote')), findsOneWidget);
    expect(
      find.textContaining('Zmiany względem poprzedniego Push'),
      findsOneWidget,
    );
    // Wyciskanie 100 zamiast 80 kg, OHP robione pierwszy raz.
    expect(inLatest('+20 kg'), findsOneWidget);
    expect(inLatest('nowe'), findsNWidgets(2));
  });

  testWidgets('month header names the month and sums the earlier trainings', (
    tester,
  ) async {
    await openHistory(tester);

    final legsDay = today.subtract(const Duration(days: 7));
    // Pierwszy miesiąc pod „Wcześniej” to miesiąc treningu Legs.
    expect(
      find.textContaining(formatMonthName(legsDay), findRichText: true),
      findsAtLeastNWidgets(1),
    );
  });

  testWidgets('a single workout has the card and no earlier list', (
    tester,
  ) async {
    setUpRepositories(local: [_session('only', todayWorkout)]);
    await openHistory(tester);

    expect(find.byType(HistoryLatestCard), findsOneWidget);
    expect(find.byType(HistoryCompactRow), findsNothing);
    expect(find.text('Wcześniej'), findsNothing);
    expect(find.text('Pierwszy trening tego planu'), findsOneWidget);
  });

  testWidgets('falls back to the server list when the phone has no sessions', (
    tester,
  ) async {
    setUpRepositories(
      local: const [],
      server: [_serverItem('srv', today.add(const Duration(hours: 9)))],
    );
    await openHistory(tester);

    expect(find.byType(HistoryLatestCard), findsOneWidget);
    expect(inLatest('Plan Serwer'), findsOneWidget);
    expect(inLatest('15'), findsOneWidget);
    expect(inLatest('Serii'), findsOneWidget);
    // Z samej listy serwera nie ma ćwiczeń ani porównania.
    expect(find.byKey(const ValueKey('latest-footnote')), findsNothing);
  });

  testWidgets('empty history shows a hint instead of an empty list', (
    tester,
  ) async {
    setUpRepositories(local: const []);
    await openHistory(tester);

    expect(find.text('Brak zarejestrowanych treningów'), findsOneWidget);
    expect(find.byType(HistoryLatestCard), findsNothing);
  });

  group('calendar sheet', () {
    testWidgets('opens from the header icon with month summary and calendar', (
      tester,
    ) async {
      await openHistory(tester);
      await openCalendar(tester);

      expect(find.byType(HistoryCalendarSheet), findsOneWidget);
      expect(find.byType(HistoryMonthNavigator), findsOneWidget);
      expect(find.byType(HistoryMonthCalendar), findsOneWidget);
      expect(find.text(formatMonthYear(today)), findsOneWidget);
      // Bieżący miesiąc — dalej nie ma dokąd iść.
      final next = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.chevron_right_rounded),
      );
      expect(next.onPressed, isNull);
      expect(
        find.text('Stuknij dzień z treningiem, żeby go zobaczyć.'),
        findsOneWidget,
      );
    });

    testWidgets('tapping a training day previews it with "Pokaż na liście"', (
      tester,
    ) async {
      await openHistory(tester);
      await openCalendar(tester);

      await tester.tap(
        find.descendant(
          of: find.byType(HistoryMonthCalendar),
          matching: find.text('${today.day}'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pokaż na liście'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(HistoryCalendarSheet),
          matching: find.byType(HistorySessionRow),
        ),
        findsOneWidget,
      );

      // Drugie stuknięcie zdejmuje podgląd.
      await tester.tap(
        find.descendant(
          of: find.byType(HistoryMonthCalendar),
          matching: find.text('${today.day}'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pokaż na liście'), findsNothing);
    });

    testWidgets('"Pokaż na liście" closes the sheet and highlights the day', (
      tester,
    ) async {
      await openHistory(tester);
      await openCalendar(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(HistoryMonthCalendar),
          matching: find.text('${today.day}'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pokaż na liście'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      expect(find.byType(HistoryCalendarSheet), findsNothing);
      // Dzień ostatniego treningu: podświetla się jego karta.
      expect(
        tester
            .widget<HistoryLatestCard>(find.byType(HistoryLatestCard))
            .highlighted,
        isTrue,
      );

      // Podświetlenie gaśnie samo.
      await tester.pump(const Duration(seconds: 3));
      expect(
        tester
            .widget<HistoryLatestCard>(find.byType(HistoryLatestCard))
            .highlighted,
        isFalse,
      );
    });

    testWidgets('arrow goes to the previous month', (tester) async {
      await openHistory(tester);
      await openCalendar(tester);

      await tester.tap(find.byTooltip('Poprzedni miesiąc'));
      await tester.pumpAndSettle();

      expect(
        find.text(formatMonthYear(DateTime(today.year, today.month - 1))),
        findsOneWidget,
      );
      final next = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.chevron_right_rounded),
      );
      expect(next.onPressed, isNotNull);
    });
  });

  group('statistics entry', () {
    Future<GoRouter> openWithRouter(WidgetTester tester) async {
      useTallPhone(tester);
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const HistoryScreen()),
          GoRoute(
            path: '/app/training/stats',
            builder: (_, _) => const Scaffold(body: Text('ekran statystyk')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      return router;
    }

    testWidgets('there is no sessions/statistics tab any more', (tester) async {
      await openHistory(tester);

      expect(find.text('Sesje'), findsNothing);
      expect(find.text('Statystyki'), findsNothing);
      expect(find.byType(StatsRangeSelector), findsNothing);
      expect(find.byType(HistoryLatestCard), findsOneWidget);
      // Obie ikony stoją w nagłówku listy.
      expect(find.byTooltip('Statystyki'), findsOneWidget);
      expect(find.byTooltip('Kalendarz'), findsOneWidget);
    });

    testWidgets('the chart icon opens the statistics screen', (tester) async {
      await openWithRouter(tester);

      await tester.tap(find.byTooltip('Statystyki'));
      await tester.pumpAndSettle();

      expect(find.text('ekran statystyk'), findsOneWidget);
    });

    testWidgets('a one-time bubble points to the new icon', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await openHistory(tester);
      await tester.pump();

      expect(find.text('Statystyki są teraz tutaj'), findsOneWidget);

      await tester.tap(find.text('Statystyki są teraz tutaj'));
      await tester.pumpAndSettle();
      expect(find.text('Statystyki są teraz tutaj'), findsNothing);

      // Pokazana raz — po ponownym otwarciu Historii jej nie ma.
      await openHistory(tester);
      await tester.pump();
      expect(find.text('Statystyki są teraz tutaj'), findsNothing);
    });

    testWidgets('the bubble goes away after a few seconds', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await openHistory(tester);
      await tester.pump();
      expect(find.text('Statystyki są teraz tutaj'), findsOneWidget);

      await tester.pump(const Duration(seconds: 8));
      expect(find.text('Statystyki są teraz tutaj'), findsNothing);
    });
  });

  group('month picker', () {
    Future<void> openPicker(WidgetTester tester, MaterialApp app) async {
      tester.view.physicalSize = const Size(390 * 3, 1600 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Kalendarz'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Wybierz rok/miesiąc'));
      await tester.pumpAndSettle();
    }

    testWidgets('opens in Polish with the app localization', (tester) async {
      await openPicker(
        tester,
        const MaterialApp(
          locale: AppLocalization.locale,
          supportedLocales: AppLocalization.supportedLocales,
          localizationsDelegates: AppLocalization.delegates,
          home: HistoryScreen(),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(DatePickerDialog), findsOneWidget);
      expect(find.text('Anuluj'), findsOneWidget);
    });

    // Wcześniej wymuszony `Locale('pl')` bez delegatów kończył się
    // „No MaterialLocalizations found”.
    testWidgets('does not crash without Polish delegates', (tester) async {
      await openPicker(tester, const MaterialApp(home: HistoryScreen()));

      expect(tester.takeException(), isNull);
      expect(find.byType(DatePickerDialog), findsOneWidget);
    });
  });
}

class _FakeStatsRepository implements TrainingStatsRepository {
  _FakeStatsRepository(this._sessions);

  final List<session.TrainingSession> _sessions;

  @override
  Future<List<session.TrainingSession>> completedSessionsSince(
    DateTime from,
  ) async => _sessions;

  @override
  Future<List<session.TrainingSession>> allCompletedSessions() async =>
      _sessions;
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
