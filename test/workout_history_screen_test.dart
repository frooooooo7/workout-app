import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/services/service_locator.dart';
import 'package:gym/core/theme/app_localization.dart';
import 'package:gym/features/training/domain/models/training_history_models.dart';
import 'package:gym/features/training/domain/models/training_session.dart'
    as session;
import 'package:gym/features/training/domain/repositories/training_history_repository.dart';
import 'package:gym/features/training/domain/repositories/training_stats_repository.dart';
import 'package:gym/features/training/presentation/screens/history_screen.dart';
import 'package:gym/features/training/presentation/widgets/stats/stats_range_selector.dart';
import 'package:gym/features/training/presentation/widgets/workout_history/history_formatters.dart';
import 'package:gym/features/training/presentation/widgets/workout_history/history_month_calendar.dart';
import 'package:gym/features/training/presentation/widgets/workout_history/history_month_navigator.dart';
import 'package:gym/features/training/presentation/widgets/workout_history/history_session_row.dart';

TrainingSessionListItem _item(
  String id,
  DateTime startedAt, {
  String plan = 'Plan Góra',
  double volumeKg = 4200,
}) => TrainingSessionListItem(
  id: id,
  startedAt: startedAt.toUtc(),
  endedAt: startedAt.add(const Duration(hours: 1)).toUtc(),
  durationSec: 3600,
  status: TrainingSessionStatus.completed,
  plan: TrainingPlanSummary(id: 'p-$id', name: plan),
  exercisesCount: 5,
  completedSetsCount: 15,
  hasNote: false,
  updatedAt: startedAt.toUtc(),
  totalVolumeKg: volumeKg,
);

void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  setUp(() {
    ServiceLocator.debugSetUserScopedRepositories(
      trainingHistoryRepository: _FakeTrainingHistoryRepository(
        sessions: [
          _item('s1', today.add(const Duration(hours: 10))),
          _item(
            's2',
            today
                .subtract(const Duration(days: 7))
                .add(const Duration(hours: 18)),
            plan: 'Legs',
            volumeKg: 8290,
          ),
        ],
      ),
      trainingStatsRepository: _FakeStatsRepository(),
    );
  });

  tearDown(() {
    ServiceLocator.debugSetUserScopedRepositories();
  });

  // Telefon wysoki na tyle, żeby kalendarz i obie sesje były na ekranie.
  void useTallPhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390 * 3, 1200 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Finder inRows(String text) => find.descendant(
    of: find.byType(HistorySessionRow),
    matching: find.text(text),
  );

  testWidgets('renders month summary, plan calendar and sessions by week', (
    tester,
  ) async {
    useTallPhone(tester);
    await tester.pumpWidget(const MaterialApp(home: HistoryScreen()));
    expect(find.byType(HistoryScreen), findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.text('Historia'), findsOneWidget);

    // Miesiąc z podsumowaniem w jednej linii (liczby już się doliczyły).
    expect(find.byType(HistoryMonthNavigator), findsOneWidget);
    expect(find.text(formatMonthYear(today)), findsOneWidget);
    expect(find.text('2 treningi'), findsOneWidget);
    expect(find.text('2 h 00 min'), findsOneWidget);
    expect(find.text('12,5 t'), findsOneWidget);
    // Bieżący miesiąc — dalej nie ma dokąd iść.
    final next = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_right_rounded),
    );
    expect(next.onPressed, isNull);

    expect(find.byType(HistoryMonthCalendar), findsOneWidget);

    // Tygodnie: bieżący i poprzedni, każdy z sumą.
    expect(
      find.textContaining('Ten tydzień', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('Poprzedni tydzień', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('1 trening · 4,20 t'), findsOneWidget);
    expect(find.text('1 trening · 8,29 t'), findsOneWidget);

    // Wiersz sesji: litera planu, nazwa, tonaż i serie.
    expect(find.byType(HistorySessionRow), findsNWidgets(2));
    expect(inRows('Plan Góra'), findsOneWidget);
    expect(inRows('P'), findsOneWidget);
    expect(inRows('L'), findsOneWidget);
    expect(inRows('4,20 t'), findsOneWidget);
    expect(inRows('15 serii'), findsNWidgets(2));
  });

  testWidgets('tapping a training day filters the list to that day', (
    tester,
  ) async {
    useTallPhone(tester);
    await tester.pumpWidget(const MaterialApp(home: HistoryScreen()));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(HistoryMonthCalendar),
        matching: find.text('${today.day}'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pokaż cały miesiąc'), findsOneWidget);
    expect(find.byType(HistorySessionRow), findsOneWidget);
    expect(inRows('Plan Góra'), findsOneWidget);

    await tester.tap(find.text('Pokaż cały miesiąc'));
    await tester.pumpAndSettle();
    expect(find.byType(HistorySessionRow), findsNWidgets(2));
  });

  testWidgets('arrow goes to the previous month', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HistoryScreen()));
    await tester.pumpAndSettle();

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

  testWidgets('switches between sessions and statistics', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HistoryScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Sesje'), findsOneWidget);
    expect(find.byType(StatsRangeSelector), findsNothing);

    await tester.tap(find.text('Statystyki'));
    await tester.pumpAndSettle();

    expect(find.byType(StatsRangeSelector), findsOneWidget);
    expect(find.byType(HistoryMonthNavigator), findsNothing);
    expect(find.byTooltip('Wybierz rok/miesiąc'), findsNothing);

    await tester.tap(find.text('Sesje'));
    await tester.pumpAndSettle();
    expect(find.byType(HistoryMonthNavigator), findsOneWidget);
  });

  testWidgets('session row shows the record badge', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              HistorySessionRow(session: _item('a', today), recordsCount: 2),
              HistorySessionRow(session: _item('b', today), recordsCount: 1),
              HistorySessionRow(session: _item('c', today)),
            ],
          ),
        ),
      ),
    );

    expect(find.text('2 rekordy'), findsOneWidget);
    expect(find.text('rekord'), findsOneWidget);
    expect(find.byIcon(Icons.emoji_events_outlined), findsNWidgets(2));
  });

  group('month picker', () {
    Future<void> openPicker(WidgetTester tester, MaterialApp app) async {
      await tester.pumpWidget(app);
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
  final _sessions = [
    session.TrainingSession(
      planName: 'Plan Góra',
      status: session.TrainingSessionStatus.completed,
      startedAt: DateTime.now().toUtc().subtract(const Duration(days: 1)),
      finishedAt: DateTime.now().toUtc().subtract(const Duration(hours: 23)),
      exercises: const [],
    ),
  ];

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
