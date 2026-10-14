import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gym/core/network/api_client.dart';
import 'package:gym/features/library/data/exercise_database.dart';
import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:gym/features/training/data/plan_sharing_repository.dart';
import 'package:gym/features/training/data/sync/training_plan_sync_engine.dart';
import 'package:gym/features/training/data/training_plan_remote_data_source.dart';
import 'package:gym/features/training/domain/models/custom_training_plan.dart';
import 'package:gym/features/training/presentation/screens/user_plan_screen.dart';

void main() {
  Exercise exercise(String name) => Exercise(
    id: name,
    name: name,
    muscles: const [MuscleGroup.back],
    category: ExerciseCategory.compound,
  );

  final plan = CustomTrainingPlan(
    id: 'plan-1',
    name: 'Pull B',
    selectedDays: const [],
    copyCount: 12,
    defaultRestSeconds: 90,
    exercises: [
      PlanExercise(
        exercise: exercise('Martwy ciąg'),
        restSeconds: 180,
        sets: List.generate(4, (_) => ExerciseSet(reps: '5')),
      ),
      PlanExercise(
        exercise: exercise('Wiosłowanie sztangą'),
        supersetGroup: 'A',
        sets: List.generate(3, (_) => ExerciseSet(reps: '10')),
      ),
      PlanExercise(
        exercise: exercise('Uginanie ramion'),
        supersetGroup: 'A',
        sets: [
          ExerciseSet(reps: '10'),
          ExerciseSet(reps: '12'),
          ExerciseSet(reps: '12'),
        ],
      ),
    ],
  );

  const owner = PlanOwner(
    id: 'u-anna',
    firstName: 'Anna',
    lastName: 'Kowalska',
    handle: 'anna',
    isFollowing: true,
  );

  Future<_SpySharing> pump(WidgetTester tester, {bool online = true}) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final sharing = _SpySharing();
    final router = GoRouter(
      initialLocation: '/preview',
      routes: [
        GoRoute(
          path: '/app/plans',
          builder: (_, _) => const Scaffold(body: Text('PLANY')),
        ),
        GoRoute(
          path: '/preview',
          builder: (_, _) => UserPlanScreen(
            args: UserPlanArgs(plan: plan, owner: owner),
            repository: sharing,
            connectivity: _FakeConnectivity(online: online),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    return sharing;
  }

  testWidgets('shows the author, the plan and its supersets', (tester) async {
    await pump(tester);

    expect(find.text('Anna Kowalska'), findsOneWidget);
    expect(find.text('@anna · obserwujesz'), findsOneWidget);
    expect(find.text('skopiowany 12 razy'), findsOneWidget);
    expect(find.text('Pull B'), findsOneWidget);
    expect(find.text('4 × 5'), findsOneWidget);
    expect(find.text('przerwa 3:00'), findsOneWidget);
    expect(find.text('SUPERSERIA A'), findsOneWidget);
    expect(find.text('po rundzie 1:30'), findsOneWidget);
    expect(find.text('3 × 10–12'), findsOneWidget);
    expect(
      find.text('Ciężary @anna nie są kopiowane, dobierzesz swoje.'),
      findsOneWidget,
    );
  });

  testWidgets('copying opens the plans tab', (tester) async {
    final sharing = await pump(tester);

    await tester.tap(find.byKey(const ValueKey('user-plan-copy')));
    await tester.pumpAndSettle();

    expect(sharing.copied, ['plan-1']);
    expect(find.text('PLANY'), findsOneWidget);
  });

  testWidgets('a failed copy explains why and lets you retry', (tester) async {
    final sharing = await pump(tester);
    sharing.error = const ApiException(
      'no_copyable_exercises',
      statusCode: 400,
    );

    await tester.tap(find.byKey(const ValueKey('user-plan-copy')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('tylko własne ćwiczenia autora'),
      findsOneWidget,
    );
    final button = tester.widget<ButtonStyleButton>(
      find.byKey(const ValueKey('user-plan-copy')),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('offline the copy button is disabled', (tester) async {
    await pump(tester, online: false);

    final button = tester.widget<ButtonStyleButton>(
      find.byKey(const ValueKey('user-plan-copy')),
    );
    expect(button.onPressed, isNull);
    expect(find.text('Kopiowanie planu wymaga internetu.'), findsOneWidget);
  });
}

class _SpySharing extends PlanSharingRepository {
  _SpySharing()
    : super(
        remote: TrainingPlanRemoteDataSource(ApiClient(baseUrl: 'http://x')),
        syncEngine: TrainingPlanSyncEngine(
          remote: TrainingPlanRemoteDataSource(ApiClient(baseUrl: 'http://x')),
          localDb: ExerciseDatabase('unused.db'),
        )..stop(),
      );

  final copied = <String>[];
  Object? error;

  @override
  Future<PlanCopyOutcome> copyPlan(String planServerId) async {
    if (error case final e?) throw e;
    copied.add(planServerId);
    return (
      plan: CustomTrainingPlan(name: 'Pull B', selectedDays: const []),
      skippedExercises: 0,
    );
  }
}

class _FakeConnectivity implements Connectivity {
  _FakeConnectivity({required this.online});

  final bool online;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => [
    online ? ConnectivityResult.wifi : ConnectivityResult.none,
  ];

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      const Stream.empty();
}
