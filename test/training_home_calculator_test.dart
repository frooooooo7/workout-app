import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/training/domain/models/training_home_insights.dart';
import 'package:gym/features/training/domain/models/training_session.dart';
import 'package:gym/features/training/domain/repositories/training_stats_repository.dart';
import 'package:gym/features/training/domain/services/training_home_calculator.dart';
import 'package:gym/features/training/presentation/bloc/training_home_cubit.dart';

// Środa 2026-07-29; tydzień zaczyna się 27.07.
final _today = DateTime(2026, 7, 29, 12);

TrainingSession _session(
  String plan,
  DateTime startLocal, {
  int minutes = 60,
  String? serverId,
  List<(String, String)> sets = const [('80', '8')],
  String exercise = 'Wyciskanie',
}) => TrainingSession(
  serverId: serverId,
  planName: plan,
  status: TrainingSessionStatus.completed,
  startedAt: startLocal.toUtc(),
  finishedAt: startLocal.add(Duration(minutes: minutes)).toUtc(),
  exercises: [
    TrainingSessionExercise(
      exerciseId: '',
      exerciseName: exercise,
      exerciseMuscles: const ['chest'],
      exerciseCategory: 'compound',
      sets: [
        for (final (weight, reps) in sets)
          TrainingSessionSet(
            actualWeight: weight,
            actualReps: reps,
            completed: true,
          ),
      ],
    ),
  ],
);

class _Repo implements TrainingStatsRepository {
  _Repo(this.sessions);

  final List<TrainingSession> sessions;

  @override
  Future<List<TrainingSession>> allCompletedSessions() async => sessions;

  @override
  Future<List<TrainingSession>> completedSessionsSince(DateTime from) async =>
      sessions;
}

void main() {
  group('TrainingHomeCalculator', () {
    test('marks this week\'s completed days with their plan', () {
      final insights = TrainingHomeCalculator.compute([
        _session('Legs', DateTime(2026, 7, 24, 18)), // poprzedni tydzień
        _session('Push', DateTime(2026, 7, 27, 18)),
        _session('Pull', DateTime(2026, 7, 28, 18)),
      ], today: _today);

      expect(insights.weekDonePlans, {1: 'Push', 2: 'Pull'});
    });

    test('takes the top set of the most recent session as last result', () {
      final insights = TrainingHomeCalculator.compute([
        _session('Push', DateTime(2026, 7, 20, 18), sets: [('100', '3')]),
        _session(
          'Push',
          DateTime(2026, 7, 27, 18),
          sets: [('80', '10'), ('92,5', '6'), ('92,5', '5')],
        ),
        _session(
          'Pull',
          DateTime(2026, 7, 28, 18),
          exercise: 'Pompki',
          sets: [('', '15'), ('', '12')],
        ),
      ], today: _today);

      final bench = insights.lastResults[homeExerciseKey('Wyciskanie', '')]!;
      expect(bench.weightKg, 92.5);
      expect(bench.reps, 6);
      final dips = insights.lastResults[homeExerciseKey('Pompki', '')]!;
      expect(dips.weightKg, isNull);
      expect(dips.reps, 15);
      expect(
        insights.bests[homeExerciseKey('Wyciskanie', '')]!.bestWeightKg,
        100,
      );
    });

    test('averages the last three durations of a plan', () {
      final insights = TrainingHomeCalculator.compute([
        _session('Push', DateTime(2026, 7, 6, 18), minutes: 200),
        _session('Push', DateTime(2026, 7, 13, 18), minutes: 50),
        _session('Push', DateTime(2026, 7, 20, 18), minutes: 60),
        _session('Push', DateTime(2026, 7, 27, 18), minutes: 70),
      ], today: _today);

      expect(insights.durationFor(' push '), 60 * 60);
      expect(insights.durationFor('Legs'), isNull);
    });

    test('counts records per session under local and server ids', () {
      final record = _session(
        'Push',
        DateTime(2026, 7, 27, 18),
        serverId: 'srv-2',
        sets: [('90', '5')],
      );
      final insights = TrainingHomeCalculator.compute([
        _session('Push', DateTime(2026, 7, 20, 18), sets: [('80', '5')]),
        record,
      ], today: _today);

      expect(insights.recordsBySession[record.id], greaterThan(0));
      expect(
        insights.recordsBySession['srv-2'],
        insights.recordsBySession[record.id],
      );
    });

    test('computes weekly goal progress when a goal is set', () {
      final insights = TrainingHomeCalculator.compute(
        [_session('Push', DateTime(2026, 7, 27, 18))],
        today: _today,
        weeklyGoal: 3,
      );

      expect(insights.weeklyGoal!.goal, 3);
      expect(insights.weeklyGoal!.workoutsThisWeek, 1);
    });
  });

  group('TrainingHomeCubit', () {
    test('loads insights and adds the weekly goal when it arrives', () async {
      final changes = ValueNotifier(0);
      final cubit = TrainingHomeCubit(
        _Repo([_session('Push', DateTime(2026, 7, 27, 18))]),
        dataChanges: changes,
        weeklyGoalLoader: () async => 4,
        clock: () => _today,
      );
      await cubit.refresh();

      expect(cubit.state.weekDonePlans, {1: 'Push'});
      expect(cubit.state.weeklyGoal?.goal, 4);

      await cubit.close();
      changes.dispose();
    });

    test('keeps working without a goal source', () async {
      final cubit = TrainingHomeCubit(_Repo(const []), clock: () => _today);
      await cubit.refresh();

      expect(cubit.state.weekDonePlans, isEmpty);
      expect(cubit.state.weeklyGoal, isNull);
      await cubit.close();
    });

    group('large history is computed off the main isolate', () {
      List<TrainingSession> history() => [
        for (var i = 0; i < TrainingHomeCubit.isolateThreshold + 20; i++)
          _session(
            'Push',
            DateTime(2026, 7, 27, 18).subtract(Duration(days: i)),
            sets: [('${60 + i % 30}', '5')],
          ),
      ];

      test('matches the direct calculation', () async {
        final sessions = history();
        final cubit = TrainingHomeCubit(_Repo(sessions), clock: () => _today);
        await cubit.refresh();

        final direct = TrainingHomeCalculator.compute(sessions, today: _today);
        expect(cubit.state.weekDonePlans, direct.weekDonePlans);
        expect(cubit.state.recordsBySession, direct.recordsBySession);
        expect(cubit.state.bests.keys.toSet(), direct.bests.keys.toSet());
        expect(
          cubit.state.bests.values.single.bestWeightKg,
          direct.bests.values.single.bestWeightKg,
        );
        await cubit.close();
      });

      test(
        'a goal that lands while the isolate is computing is kept',
        () async {
          for (final delayMs in [0, 5, 15, 30]) {
            final cubit = TrainingHomeCubit(
              _Repo(history()),
              clock: () => _today,
              weeklyGoalLoader: () async {
                await Future<void>.delayed(Duration(milliseconds: delayMs));
                return 4;
              },
            );
            await cubit.refresh();
            // Liczenie z refresh() z konstruktora mogło skończyć się później.
            for (var i = 0; i < 100 && cubit.state.weeklyGoal == null; i++) {
              await Future<void>.delayed(const Duration(milliseconds: 20));
            }

            expect(
              cubit.state.weeklyGoal?.goal,
              4,
              reason: 'delay $delayMs ms',
            );
            expect(cubit.state.weekDonePlans, isNotEmpty);
            await cubit.close();
          }
        },
      );
    });
  });
}
