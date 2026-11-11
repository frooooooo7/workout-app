import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gym/features/profile/domain/services/profile_week_calculator.dart';
import 'package:gym/features/profile/presentation/bloc/profile_body_cubit.dart';
import 'package:gym/features/profile/presentation/bloc/profile_week_cubit.dart';
import 'package:gym/features/profile/presentation/screens/profile_progress_screen.dart';
import 'package:gym/features/profile/presentation/widgets/profile_week_card.dart';
import 'package:gym/features/training/domain/models/training_session.dart';
import 'package:gym/features/training/domain/models/training_summary_stats.dart';
import 'package:gym/features/training/domain/repositories/training_stats_repository.dart';

Future<void> _pumpProgress(
  WidgetTester tester, {
  ProfileWeekSummary? week,
  ProfileBodySummary? body,
  int? goal,
}) async {
  await tester.binding.setSurfaceSize(const Size(430, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => MultiBlocProvider(
          providers: [
            BlocProvider<ProfileWeekCubit>(create: (_) => _FakeWeekCubit(week)),
            BlocProvider<ProfileBodyCubit>(create: (_) => _FakeBodyCubit(body)),
          ],
          child: ProfileProgressScreen(weeklyGoalLoader: () async => goal),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the private week summary with the weekly goal', (
    tester,
  ) async {
    await _pumpProgress(
      tester,
      goal: 4,
      week: const ProfileWeekSummary(
        trainedWeekdays: {1, 3},
        stats: TrainingPeriodStats(workouts: 2, durationSec: 6000),
        streakWeeks: 3,
      ),
    );

    expect(find.text('Postępy'), findsOneWidget);
    expect(find.byKey(const ValueKey('progress-privacy')), findsOneWidget);
    expect(find.text('Ten tydzień'), findsOneWidget);
    expect(find.text('Cel 2/4'), findsOneWidget);
    expect(
      tester.widget<ProfileWeekCard>(find.byType(ProfileWeekCard)).weeklyGoal,
      4,
    );
  });

  testWidgets('without a weekly goal the card invites to set one', (
    tester,
  ) async {
    await _pumpProgress(
      tester,
      week: const ProfileWeekSummary(
        trainedWeekdays: {1},
        stats: TrainingPeriodStats(workouts: 1),
      ),
    );

    expect(find.byKey(const ValueKey('profile-week-goal')), findsNothing);
    expect(find.text('Ustaw cel'), findsOneWidget);
  });

  testWidgets('body shortcuts show the latest weight and its change', (
    tester,
  ) async {
    await _pumpProgress(
      tester,
      body: ProfileBodySummary(
        weightKg: 84.5,
        weightDeltaKg: -2.5,
        lastMeasurementOn: DateTime(2026, 10, 12),
      ),
    );

    expect(
      find.byKey(const ValueKey('profile-shortcut-weight')),
      findsOneWidget,
    );
    expect(find.text('84,5 kg'), findsOneWidget);
    expect(find.text('↓ 2,5 kg w 30 dni'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('profile-shortcut-measurements')),
      findsOneWidget,
    );
  });

  testWidgets('body shortcuts without data invite to add the first entry', (
    tester,
  ) async {
    await _pumpProgress(tester, body: const ProfileBodySummary());

    expect(find.text('Dodaj'), findsNWidgets(2));
    expect(
      find.byKey(const ValueKey('profile-shortcut-lock')),
      findsNWidgets(2),
    );
    expect(find.text('Dane o ciele widzisz tylko Ty.'), findsOneWidget);
  });
}

class _FakeWeekCubit extends ProfileWeekCubit {
  _FakeWeekCubit(ProfileWeekSummary? initial) : super(_NoOpStats()) {
    if (initial != null) emit(initial);
  }

  @override
  Future<void> load() async {}
}

class _FakeBodyCubit extends ProfileBodyCubit {
  _FakeBodyCubit(ProfileBodySummary? initial) {
    if (initial != null) emit(initial);
  }

  @override
  Future<void> load() async {}
}

class _NoOpStats implements TrainingStatsRepository {
  @override
  Future<List<TrainingSession>> completedSessionsSince(DateTime from) async =>
      const [];

  @override
  Future<List<TrainingSession>> allCompletedSessions() async => const [];
}
