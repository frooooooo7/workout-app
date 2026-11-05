import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:gym/features/training/data/warmup_stores.dart';
import 'package:gym/features/training/domain/models/custom_training_plan.dart';
import 'package:gym/features/training/domain/models/warmup.dart';
import 'package:gym/features/training/domain/repositories/training_plan_repository.dart';
import 'package:gym/features/training/domain/services/warmup_goal_scheduler.dart';
import 'package:gym/features/training/presentation/screens/warmup_screen.dart';
import 'package:gym/features/training/presentation/utils/warmup_gate.dart';
import 'package:gym/features/training/presentation/widgets/training_active_warmup_card.dart';
import 'package:gym/features/training/presentation/widgets/warmup_first_start_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeScheduler implements WarmupGoalScheduler {
  final scheduled = <Duration>[];
  var cancelled = 0;

  @override
  Future<void> scheduleGoalReached({required Duration after}) async =>
      scheduled.add(after);

  @override
  Future<void> cancelGoalReached() async => cancelled++;
}

class _PlanRepo implements TrainingPlanRepository {
  _PlanRepo({this.plan, this.fail = false});

  final CustomTrainingPlan? plan;
  final bool fail;
  var lookups = 0;

  @override
  Future<CustomTrainingPlan?> getById(String id) async {
    lookups++;
    if (fail) throw StateError('db');
    return plan;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Clock {
  DateTime now = DateTime(2026, 11, 5, 18);

  DateTime call() => now;
}

CustomTrainingPlan _plan() => CustomTrainingPlan(
  id: 'plan-1',
  name: 'Push A',
  exercises: [
    PlanExercise(
      exercise: Exercise(
        id: 'bench',
        name: 'Wyciskanie sztangi na ławce',
        muscles: const [MuscleGroup.chest],
        category: ExerciseCategory.compound,
      ),
      sets: [
        ExerciseSet(weight: '60', reps: '8'),
        ExerciseSet(weight: '60', reps: '8'),
        ExerciseSet(weight: '60', reps: '8'),
      ],
    ),
  ],
);

void main() {
  const userId = 'user-1';

  late WarmupSettingsStore settings;
  late WarmupSessionStore session;
  late _FakeScheduler scheduler;
  late _Clock clock;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    clock = _Clock();
    settings = WarmupSettingsStore();
    session = WarmupSessionStore(clock: clock.call);
    scheduler = _FakeScheduler();
    await settings.attach(userId);
    await session.attach(userId);
  });

  group('stores', () {
    test('settings start empty, a choice is saved per account', () async {
      expect(settings.current.shouldAsk, isTrue);
      expect(settings.current.isOn, isFalse);
      expect(settings.current.targetMinutes, 8);

      await settings.setEnabled(true);
      await settings.setTargetMinutes(10);

      final reloaded = WarmupSettingsStore();
      await reloaded.attach(userId);
      expect(reloaded.current.enabled, isTrue);
      expect(reloaded.current.targetMinutes, 10);

      await reloaded.attach('user-2');
      expect(reloaded.current.shouldAsk, isTrue);
      await reloaded.attach(null);
      expect(reloaded.current.shouldAsk, isTrue);
    });

    test('a refusal is remembered too', () async {
      await settings.setEnabled(false);

      final reloaded = WarmupSettingsStore();
      await reloaded.attach(userId);
      expect(reloaded.current.enabled, isFalse);
      expect(reloaded.current.shouldAsk, isFalse);
    });

    test('a warm-up in progress survives a restart, per account', () async {
      await session.begin(
        const WarmupTarget.plan(planId: 'plan-1', name: 'Push A'),
        8,
      );
      clock.now = clock.now.add(const Duration(minutes: 5));

      final reloaded = WarmupSessionStore(clock: clock.call);
      await reloaded.attach(userId);
      final running = reloaded.active!;
      expect(running.target.name, 'Push A');
      expect(running.target.refId, 'plan-1');
      expect(running.elapsed(clock.now), const Duration(minutes: 5));

      await reloaded.attach('user-2');
      expect(reloaded.active, isNull);
    });

    test('a forgotten warm-up (over 60 min) is dropped', () async {
      await session.begin(const WarmupTarget.custom(), 8);
      clock.now = clock.now.add(const Duration(minutes: 61));

      expect(session.active, isNull);
      final reloaded = WarmupSessionStore(clock: clock.call);
      await reloaded.attach(userId);
      expect(reloaded.current, isNull);
    });

    test('clear and a goal change are saved', () async {
      await session.begin(const WarmupTarget.custom(), 8);
      await session.setTargetMinutes(15);
      expect(session.current!.targetMinutes, 15);

      final reloaded = WarmupSessionStore(clock: clock.call);
      await reloaded.attach(userId);
      expect(reloaded.current!.targetMinutes, 15);

      await session.clear();
      final cleared = WarmupSessionStore(clock: clock.call);
      await cleared.attach(userId);
      expect(cleared.current, isNull);
    });
  });

  group('gate and panel', () {
    final results = <bool>[];
    int? lastSeconds;

    /// Zapis ustawień idzie w tle — po teście pozwalamy mu się skończyć.
    void gateTest(
      String description,
      Future<void> Function(WidgetTester tester) body,
    ) {
      testWidgets(description, (tester) async {
        await body(tester);
        await tester.pump(const Duration(seconds: 2));
      });
    }

    Future<void> pumpApp(
      WidgetTester tester, {
      WarmupRequest? request,
      bool sessionInProgress = false,
    }) async {
      await tester.binding.setSurfaceSize(const Size(412, 892));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      results.clear();
      lastSeconds = null;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    key: const ValueKey('begin'),
                    onPressed: () async {
                      final go = await runWarmupGate(
                        context,
                        request ?? WarmupRequest.plan(_plan()),
                        sessionInProgress: sessionInProgress,
                        settings: settings,
                        session: session,
                        scheduler: scheduler,
                      );
                      results.add(go.proceed);
                      lastSeconds = go.seconds;
                    },
                    child: const Text('Rozpocznij'),
                  ),
                ),
              ),
            ),
          ),
          GoRoute(
            path: kWarmupRoute,
            builder: (_, state) {
              final args = state.extra! as WarmupArgs;
              return WarmupScreen(
                args: WarmupArgs(
                  request: args.request,
                  session: args.session,
                  scheduler: args.scheduler,
                  clock: clock.call,
                ),
              );
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    }

    /// Panel ma stoper tykający co 250 ms, więc `pumpAndSettle` by nie wrócił.
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> enable(WidgetTester tester) async {
      await tester.runAsync(() => settings.setEnabled(true));
    }

    Future<void> disable(WidgetTester tester) async {
      await tester.runAsync(() => settings.setEnabled(false));
    }

    Future<void> tapBegin(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('begin')));
      await settle(tester);
    }

    Future<void> elapse(WidgetTester tester, Duration by) async {
      clock.now = clock.now.add(by);
      await tester.pump(const Duration(milliseconds: 300));
    }

    gateTest('first start asks; "yes" saves the choice and opens the panel', (
      tester,
    ) async {
      await pumpApp(tester);
      await tapBegin(tester);

      expect(find.text('Zaczynasz od rozgrzewki?'), findsOneWidget);
      expect(find.textContaining('Profil → Ustawienia'), findsOneWidget);

      await tester.tap(find.byKey(warmupFirstStartYesKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(settings.current.enabled, isTrue);
      expect(session.current!.target.key, 'plan:plan-1');
      expect(scheduler.scheduled, [const Duration(minutes: 8)]);
      expect(find.byKey(warmupTimerKey), findsOneWidget);
      expect(find.text('00:00'), findsOneWidget);
      expect(find.text('przed: Push A'), findsOneWidget);
      expect(results, isEmpty);
    });

    gateTest('first start: "no" saves the choice and starts straight away', (
      tester,
    ) async {
      await pumpApp(tester);
      await tapBegin(tester);

      await tester.tap(find.byKey(warmupFirstStartNoKey));
      await settle(tester);

      expect(settings.current.enabled, isFalse);
      expect(session.current, isNull);
      expect(results, [true]);
      expect(find.byKey(warmupTimerKey), findsNothing);

      // Odpowiedź już zapisana — kolejny start nie pyta.
      await tapBegin(tester);
      expect(find.text('Zaczynasz od rozgrzewki?'), findsNothing);
      expect(results, [true, true]);
    });

    gateTest('closing the question saves nothing and starts nothing', (
      tester,
    ) async {
      await pumpApp(tester);
      await tapBegin(tester);

      await tester.tapAt(const Offset(206, 40));
      await settle(tester);

      expect(results, [false]);
      expect(settings.current.shouldAsk, isTrue);
      expect(session.current, isNull);
    });

    gateTest('a disabled warm-up starts the workout like before', (
      tester,
    ) async {
      await disable(tester);
      await pumpApp(tester);
      await tapBegin(tester);

      expect(results, [true]);
      expect(find.byKey(warmupTimerKey), findsNothing);
    });

    gateTest('a running workout skips the gate', (tester) async {
      await pumpApp(tester, sessionInProgress: true);
      await tapBegin(tester);

      expect(results, [true]);
      expect(find.text('Zaczynasz od rozgrzewki?'), findsNothing);
      expect(session.current, isNull);
    });

    gateTest('the stopwatch counts up from the saved start time', (
      tester,
    ) async {
      await enable(tester);
      await pumpApp(tester);
      await tapBegin(tester);

      await elapse(tester, const Duration(minutes: 3, seconds: 12));
      expect(find.text('03:12'), findsOneWidget);
      expect(find.text('z 8:00 min'), findsOneWidget);
      expect(find.byKey(const ValueKey('warmup-goal-8')), findsOneWidget);
      expect(find.text('ROZGRZEWKA'), findsOneWidget);
    });

    gateTest('the panel shows what comes after, with no suggestions', (
      tester,
    ) async {
      await enable(tester);
      await pumpApp(tester);
      await tapBegin(tester);

      expect(find.textContaining('Rozgrzej się po swojemu'), findsOneWidget);
      expect(find.byKey(const ValueKey('warmup-after-card')), findsOneWidget);
      expect(find.text('1 ćwiczenie · 3 serie · Klatka'), findsOneWidget);
      expect(find.text('Wyciskanie sztangi na ławce'), findsOneWidget);
      expect(find.text('Rozpocznij trening'), findsOneWidget);
    });

    gateTest('a free workout has no "after" card', (tester) async {
      await enable(tester);
      await pumpApp(tester, request: const WarmupRequest.custom());
      await tapBegin(tester);

      expect(find.byKey(const ValueKey('warmup-after-card')), findsNothing);
      expect(find.text('przed: Trening bez planu'), findsOneWidget);
    });

    gateTest('reaching the goal turns the panel green, counting goes on', (
      tester,
    ) async {
      await enable(tester);
      await pumpApp(tester);
      await tapBegin(tester);

      await elapse(tester, const Duration(minutes: 8, seconds: 24));
      expect(find.text('CEL OSIĄGNIĘTY'), findsOneWidget);
      expect(find.text('08:24'), findsOneWidget);
      expect(find.text('stoper liczy dalej'), findsOneWidget);
      expect(find.text('Zacznij trening, kiedy chcesz'), findsOneWidget);
      expect(find.byKey(warmupStartButtonKey), findsOneWidget);

      await elapse(tester, const Duration(seconds: 6));
      expect(find.text('08:30'), findsOneWidget);
    });

    gateTest('"Rozpocznij trening" closes the panel and ends the warm-up', (
      tester,
    ) async {
      await enable(tester);
      await pumpApp(tester);
      await tapBegin(tester);
      await elapse(tester, const Duration(minutes: 2));

      await tester.tap(find.byKey(warmupStartButtonKey));
      await settle(tester);

      expect(results, [true]);
      expect(session.current, isNull);
      expect(scheduler.cancelled, greaterThan(0));
      expect(find.byKey(warmupTimerKey), findsNothing);
    });

    gateTest('"Rozpocznij trening" returns the measured warm-up time', (
      tester,
    ) async {
      await enable(tester);
      await pumpApp(tester);
      await tapBegin(tester);
      await elapse(tester, const Duration(minutes: 8, seconds: 24));

      await tester.tap(find.byKey(warmupStartButtonKey));
      await settle(tester);

      expect(results, [true]);
      expect(lastSeconds, 504);
    });

    gateTest('a warm-up under a minute is not reported', (tester) async {
      await enable(tester);
      await pumpApp(tester);
      await tapBegin(tester);
      await elapse(tester, const Duration(seconds: 40));

      await tester.tap(find.byKey(warmupStartButtonKey));
      await settle(tester);

      expect(results, [true]);
      expect(lastSeconds, isNull);
    });

    gateTest('hiding the panel keeps the warm-up running, start aborts', (
      tester,
    ) async {
      await enable(tester);
      await pumpApp(tester);
      await tapBegin(tester);

      await tester.tap(find.byKey(warmupHideKey));
      await settle(tester);

      expect(results, [false]);
      expect(session.current, isNotNull);

      // Ten sam trening: stuknięcie wraca do tej samej rozgrzewki.
      final startedAt = session.current!.startedAt;
      await elapse(tester, const Duration(minutes: 1));
      await tapBegin(tester);
      expect(find.byKey(warmupTimerKey), findsOneWidget);
      expect(find.text('01:00'), findsOneWidget);
      expect(session.current!.startedAt, startedAt);
      expect(scheduler.scheduled, hasLength(1));
    });

    gateTest('"Przerwij rozgrzewkę" clears it without starting', (
      tester,
    ) async {
      await enable(tester);
      await pumpApp(tester);
      await tapBegin(tester);

      await tester.tap(find.byTooltip('Więcej'));
      await settle(tester);
      await tester.tap(find.byKey(warmupCancelMenuKey));
      await settle(tester);

      expect(results, [false]);
      expect(session.current, isNull);
      expect(scheduler.cancelled, greaterThan(0));
    });

    gateTest('another workout cannot start during a warm-up', (tester) async {
      await enable(tester);
      await tester.runAsync(
        () => session.begin(
          const WarmupTarget.plan(planId: 'plan-2', name: 'Pull B'),
          8,
        ),
      );
      await pumpApp(tester);
      await tapBegin(tester);

      expect(results, [false]);
      expect(find.textContaining('Trwa rozgrzewka przed „Pull B”'), findsOne);
      expect(find.byKey(warmupTimerKey), findsNothing);
    });

    gateTest('the goal can be changed for today only', (tester) async {
      await enable(tester);
      await pumpApp(tester);
      await tapBegin(tester);
      await elapse(tester, const Duration(minutes: 1));

      await tester.tap(find.byKey(const ValueKey('warmup-goal-10')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(session.current!.targetMinutes, 10);
      expect(settings.current.targetMinutes, 8);
      expect(find.text('z 10:00 min'), findsOneWidget);
      expect(scheduler.scheduled.last, const Duration(minutes: 9));
    });
  });

  testWidgets('the "warm-up in progress" card shows time and resumes', (
    tester,
  ) async {
    var resumed = 0;
    final warmup = WarmupInProgress(
      target: const WarmupTarget.plan(planId: 'plan-1', name: 'Push A'),
      startedAt: clock.now.subtract(const Duration(minutes: 3, seconds: 12)),
      targetMinutes: 8,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainingActiveWarmupCard(
            warmup: warmup,
            onResume: () => resumed++,
            clock: clock.call,
          ),
        ),
      ),
    );

    expect(find.text('Trwa rozgrzewka · 03:12'), findsOneWidget);
    expect(find.text('Push A'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('active-warmup-resume')));
    expect(resumed, 1);
  });

  group('findWarmupPlan', () {
    test(
      'takes the plan from the view list without asking the repository',
      () async {
        final repo = _PlanRepo();
        expect(await findWarmupPlan('plan-1', [_plan()], repo), isNotNull);
        expect(repo.lookups, 0);
      },
    );

    test('empty (still loading) list falls back to the repository', () async {
      final repo = _PlanRepo(plan: _plan());
      expect((await findWarmupPlan('plan-1', const [], repo))?.id, 'plan-1');
      expect(repo.lookups, 1);
    });

    test('null only when the repository confirms the plan is gone', () async {
      expect(await findWarmupPlan('plan-1', const [], _PlanRepo()), isNull);
      expect(await findWarmupPlan(null, [_plan()], _PlanRepo()), isNull);
    });

    test('a read error propagates so the warm-up is not cleared', () {
      expect(
        findWarmupPlan('plan-1', const [], _PlanRepo(fail: true)),
        throwsStateError,
      );
    });
  });
}
