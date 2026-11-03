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
import 'package:gym/features/training/presentation/widgets/workout_history/history_filter_bar.dart';
import 'package:gym/features/training/presentation/widgets/workout_history/history_formatters.dart';
import 'package:gym/features/training/presentation/widgets/workout_history/history_month_calendar.dart';
import 'package:gym/features/training/presentation/widgets/workout_history/history_month_navigator.dart';
import 'package:gym/features/training/presentation/widgets/workout_history/history_session_card.dart';
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
      today.add(const Duration(hours: 1)),
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

  Finder inCards(String text) => find.descendant(
    of: find.byType(HistorySessionCard),
    matching: find.text(text),
  );

  Finder chip(String label) => find.descendant(
    of: find.byType(HistoryFilterBar),
    matching: find.text(label),
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

  testWidgets('shows trainings as one list with weeks and exercises', (
    tester,
  ) async {
    await openHistory(tester);

    expect(find.text('Historia'), findsOneWidget);
    // Kalendarza nie ma na liście — siedzi pod ikonką w nagłówku.
    expect(find.byType(HistoryMonthCalendar), findsNothing);
    expect(find.byType(HistoryMonthNavigator), findsNothing);
    expect(find.byTooltip('Kalendarz'), findsOneWidget);

    expect(
      find.textContaining('Ten tydzień', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('Poprzedni tydzień', findRichText: true),
      findsOneWidget,
    );
    expect(find.byType(HistorySessionCard), findsNWidgets(3));

    // Karta dzisiejszego Pusha: 3 główne ćwiczenia, bez czwartego.
    expect(inCards('Wyciskanie'), findsNWidgets(2));
    expect(inCards('OHP'), findsOneWidget);
    expect(inCards('Rozpiętki'), findsOneWidget);
    expect(inCards('Dipy'), findsNothing);
    // Legs: obie pozycje i notatka.
    expect(inCards('Przysiad'), findsOneWidget);
    expect(inCards('Martwy ciąg'), findsOneWidget);
    expect(inCards('Kolana w porządku'), findsOneWidget);
    // Rekord tylko na dzisiejszym Pushu.
    expect(find.text('rekord'), findsOneWidget);
    expect(inCards('4 ćwiczenia'), findsNothing);
  });

  testWidgets('month header sums the month of the visible trainings', (
    tester,
  ) async {
    await openHistory(tester);

    expect(
      find.text(formatMonthYear(today).toUpperCase()),
      findsAtLeastNWidgets(1),
    );
  });

  testWidgets('plan chips narrow the list and Rekordy keeps record trainings', (
    tester,
  ) async {
    // Testowa czcionka jest szeroka — szerszy ekran, żeby wszystkie chipy
    // były widoczne.
    await openHistory(tester, width: 700);

    expect(find.text('Wszystkie'), findsOneWidget);
    expect(chip('Legs'), findsOneWidget);
    expect(chip('Rekordy'), findsOneWidget);

    await tester.tap(chip('Legs'));
    await tester.pumpAndSettle();
    expect(find.byType(HistorySessionCard), findsOneWidget);
    expect(inCards('Przysiad'), findsOneWidget);

    await tester.tap(chip('Rekordy'));
    await tester.pumpAndSettle();
    expect(find.byType(HistorySessionCard), findsOneWidget);
    expect(inCards('Wyciskanie'), findsOneWidget);

    await tester.tap(chip('Wszystkie'));
    await tester.pumpAndSettle();
    expect(find.byType(HistorySessionCard), findsNWidgets(3));
  });

  testWidgets('no filter bar when there is a single plan and no records', (
    tester,
  ) async {
    setUpRepositories(
      local: [_session('only', today.add(const Duration(hours: 1)))],
    );
    await openHistory(tester);

    expect(find.byType(HistorySessionCard), findsOneWidget);
    expect(find.text('Wszystkie'), findsNothing);
  });

  testWidgets('falls back to the server list when the phone has no sessions', (
    tester,
  ) async {
    setUpRepositories(
      local: const [],
      server: [_serverItem('srv', today.add(const Duration(hours: 9)))],
    );
    await openHistory(tester);

    expect(find.byType(HistorySessionCard), findsOneWidget);
    expect(inCards('Plan Serwer'), findsOneWidget);
    expect(inCards('15'), findsOneWidget);
    expect(inCards('ćwiczeń'), findsOneWidget);
  });

  testWidgets('empty history shows a hint instead of an empty list', (
    tester,
  ) async {
    setUpRepositories(local: const []);
    await openHistory(tester);

    expect(find.text('Brak zarejestrowanych treningów'), findsOneWidget);
    expect(find.byType(HistorySessionCard), findsNothing);
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
      final highlighted = tester
          .widgetList<HistorySessionCard>(find.byType(HistorySessionCard))
          .where((card) => card.highlighted);
      expect(highlighted.map((c) => c.entry.item.id), ['today']);

      // Podświetlenie gaśnie samo.
      await tester.pump(const Duration(seconds: 3));
      expect(
        tester
            .widgetList<HistorySessionCard>(find.byType(HistorySessionCard))
            .any((card) => card.highlighted),
        isFalse,
      );
    });

    testWidgets('"Pokaż na liście" drops a filter that hides the day', (
      tester,
    ) async {
      await openHistory(tester, width: 700);
      await tester.tap(chip('Legs'));
      await tester.pumpAndSettle();
      expect(find.byType(HistorySessionCard), findsOneWidget);

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

      expect(find.byType(HistorySessionCard), findsNWidgets(3));
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
      expect(find.byType(HistorySessionCard), findsNWidgets(3));
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
