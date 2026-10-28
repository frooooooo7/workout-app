import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/services/service_locator.dart';
import 'package:gym/features/training/domain/models/progression_settings.dart';
import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:gym/features/training/domain/models/custom_training_plan.dart';
import 'package:gym/features/training/domain/models/training_home_insights.dart';
import 'package:gym/features/training/domain/models/training_stats.dart';
import 'package:gym/features/training/presentation/widgets/training_today_plan_section.dart';

// Środa 2026-07-29.
final _today = DateTime(2026, 7, 29, 9);

CustomTrainingPlan _plan(
  String name,
  List<int> days, {
  int exercisesCount = 1,
  int setsPerExercise = 3,
}) {
  return CustomTrainingPlan(
    name: name,
    selectedDays: days,
    exercises: [
      for (var i = 0; i < exercisesCount; i++)
        PlanExercise(
          exercise: mockExercises[i],
          sets: [for (var s = 0; s < setsPerExercise; s++) ExerciseSet()],
        ),
    ],
  );
}

String _key(Exercise e) => homeExerciseKey(e.name, e.id);

Future<void> _pump(
  WidgetTester tester, {
  required int selectedDay,
  required List<CustomTrainingPlan> plans,
  bool isLoading = false,
  TrainingHomeInsights insights = TrainingHomeInsights.empty,
  ValueChanged<CustomTrainingPlan>? onOpenPlan,
  Future<void> Function(CustomTrainingPlan)? onStartPlan,
  ValueChanged<int>? onCreatePlanForDay,
  VoidCallback? onStartCustom,
  bool sessionInProgress = false,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: TrainingTodayPlanSection(
            selectedDay: selectedDay,
            plans: plans,
            isLoading: isLoading,
            insights: insights,
            today: _today,
            onOpenPlan: onOpenPlan ?? (_) {},
            onStartPlan: onStartPlan ?? (_) async {},
            onCreatePlanForDay: onCreatePlanForDay ?? (_) {},
            onStartCustom: onStartCustom ?? () {},
            sessionInProgress: sessionInProgress,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('a workout in progress greys out the start button', (
    tester,
  ) async {
    final scheduled = _plan('Legs', const [3]);
    var started = 0;
    var custom = 0;

    await _pump(
      tester,
      selectedDay: 3,
      plans: [scheduled],
      sessionInProgress: true,
      onStartPlan: (_) async => started++,
      onStartCustom: () => custom++,
    );

    expect(find.text('Rozpocznij Legs'), findsOneWidget);
    expect(find.byKey(const ValueKey('start-disabled-hint')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('start-workout-button')));
    await tester.pumpAndSettle();
    expect(started, 0);

    // „Trening bez planu” w menu też jest nieaktywny.
    await tester.tap(find.byKey(const ValueKey('plan-card-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trening bez planu'));
    await tester.pumpAndSettle();
    expect(custom, 0);
  });

  testWidgets('training day: plan summary, opens details and starts', (
    tester,
  ) async {
    final scheduled = _plan('Push Power', const [3], exercisesCount: 2);
    CustomTrainingPlan? opened;
    CustomTrainingPlan? started;

    await _pump(
      tester,
      selectedDay: 3,
      plans: [scheduled],
      onOpenPlan: (p) => opened = p,
      onStartPlan: (p) async => started = p,
    );

    expect(find.text('DZIŚ'), findsOneWidget);
    expect(find.text('Plan na środę'), findsOneWidget);
    expect(find.text('Push Power'), findsOneWidget);
    expect(find.text('Klatka · Plecy'), findsOneWidget);
    expect(find.text('2 ćwiczenia'), findsOneWidget);
    expect(find.text('6 serii'), findsOneWidget);
    // Bez historii nie ma czasu ani rekordu do pobicia.
    expect(find.textContaining('min'), findsNothing);
    expect(find.textContaining('Do pobicia'), findsNothing);
    expect(find.text('—'), findsNWidgets(2));
    expect(find.text('Rozpocznij Push Power'), findsOneWidget);

    await tester.tap(find.text('Push Power'));
    await tester.pump();
    expect(opened, same(scheduled));

    await tester.tap(find.byKey(const ValueKey('start-workout-button')));
    await tester.pumpAndSettle();
    expect(started, same(scheduled));
  });

  testWidgets('shows last results, record to beat and typical duration', (
    tester,
  ) async {
    final scheduled = _plan('Push', const [3], exercisesCount: 2);
    final bench = mockExercises[0];
    final pullUp = mockExercises[1];

    await _pump(
      tester,
      selectedDay: 3,
      plans: [scheduled],
      insights: TrainingHomeInsights(
        lastResults: {
          _key(bench): const ExerciseLastResult(weightKg: 92.5, reps: 6),
          _key(pullUp): const ExerciseLastResult(reps: 12),
        },
        bests: {
          _key(bench): ExerciseBest(
            exerciseKey: _key(bench),
            exerciseName: bench.name,
            exerciseId: bench.id,
            sessions: 4,
            lastImprovedAt: DateTime(2026, 7, 20),
            bestWeightKg: 92.5,
            bestWeightReps: 6,
          ),
        },
        planDurationsSec: const {'push': 3540},
      ),
    );

    expect(find.text('92,5 × 6'), findsOneWidget);
    expect(find.text('12 powt.'), findsOneWidget);
    expect(find.text('~60 min'), findsOneWidget);
    // Progresja domyślnie wyłączona: ten sam ciężar, powtórzenie więcej.
    expect(
      find.bySemanticsLabel(
        'Do pobicia: Wyciskanie sztangi na ławce 92,5 kg × 7, rekord 92,5',
      ),
      findsOneWidget,
    );

    // Stały krok z ustawień: o krok więcej przy tych samych powtórzeniach.
    ServiceLocator.progressionSettings.notifier.value =
        const ProgressionSettings(method: ProgressionMethod.fixed);
    addTearDown(
      () => ServiceLocator.progressionSettings.notifier.value =
          ProgressionSettings.off,
    );
    await tester.pump();
    expect(
      find.bySemanticsLabel(
        'Do pobicia: Wyciskanie sztangi na ławce 95 kg × 6, rekord 92,5',
      ),
      findsOneWidget,
    );
  });

  testWidgets('lists three exercises and expands the rest in place', (
    tester,
  ) async {
    await _pump(
      tester,
      selectedDay: 3,
      plans: [
        _plan('Push', const [3], exercisesCount: 5),
      ],
    );

    expect(find.text(mockExercises[2].name), findsOneWidget);
    expect(find.text(mockExercises[3].name), findsNothing);
    expect(find.text('+ 2 kolejne ćwiczenia'), findsOneWidget);

    await tester.tap(find.text('+ 2 kolejne ćwiczenia'));
    await tester.pumpAndSettle();
    expect(find.text(mockExercises[4].name), findsOneWidget);
    expect(find.text('Zwiń listę'), findsOneWidget);
  });

  testWidgets('menu offers plan details, other plans and a custom workout', (
    tester,
  ) async {
    final push = _plan('Push Power', const [1]);
    final pull = _plan('Pull Volume', const [1, 3]);
    CustomTrainingPlan? opened;
    CustomTrainingPlan? started;
    var custom = false;

    await _pump(
      tester,
      selectedDay: 1,
      plans: [push, pull],
      onOpenPlan: (p) => opened = p,
      onStartPlan: (p) async => started = p,
      onStartCustom: () => custom = true,
    );

    expect(find.text('Plan na poniedziałek'), findsOneWidget);
    expect(find.text('PONIEDZIAŁEK'), findsOneWidget);

    Future<void> choose(String label) async {
      await tester.tap(find.byKey(const ValueKey('plan-card-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    await choose('Szczegóły planu');
    expect(opened, same(push));
    await choose('Rozpocznij Pull Volume');
    expect(started, same(pull));
    await choose('Trening bez planu');
    expect(custom, isTrue);
  });

  testWidgets('rest day: next workout and plan-this-day action', (
    tester,
  ) async {
    int? requestedDay;

    await _pump(
      tester,
      selectedDay: 2,
      plans: [
        _plan('Push Power', const [5]),
      ],
      onCreatePlanForDay: (day) => requestedDay = day,
    );

    expect(find.text('WCZORAJ'), findsOneWidget);
    expect(find.byKey(const ValueKey('monk-rest-icon')), findsOneWidget);
    expect(find.text('Dzień wolny'), findsOneWidget);
    expect(find.text('Następny trening: Push Power · piątek'), findsOneWidget);
    expect(find.byKey(const ValueKey('start-workout-button')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('plan-day-button')));
    await tester.pumpAndSettle();
    expect(requestedDay, 2);
  });

  testWidgets('without plans offers creating one', (tester) async {
    int? requestedDay;

    await _pump(
      tester,
      selectedDay: 4,
      plans: const [],
      onCreatePlanForDay: (day) => requestedDay = day,
    );

    expect(find.text('JUTRO'), findsOneWidget);
    expect(find.text('Brak planu'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('create-plan-button')));
    await tester.pumpAndSettle();
    expect(requestedDay, 4);
  });

  testWidgets('shows a skeleton while plans load', (tester) async {
    await _pump(tester, selectedDay: 3, plans: const [], isLoading: true);

    expect(find.bySemanticsLabel('Ładowanie planu'), findsOneWidget);
    expect(find.byKey(const ValueKey('monk-rest-icon')), findsNothing);
    expect(find.byKey(const ValueKey('start-workout-button')), findsNothing);
  });
}
