import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/utils/number_formatter.dart';
import 'package:gym/features/profile/domain/services/profile_week_calculator.dart';
import 'package:gym/features/training/domain/models/training_session.dart';

TrainingSession _session(DateTime startedAt, {int minutes = 60}) =>
    TrainingSession(
      planName: 'Push',
      status: TrainingSessionStatus.completed,
      startedAt: startedAt,
      finishedAt: startedAt.add(Duration(minutes: minutes)),
      exercises: const [],
    );

void main() {
  // Środa, 23 września 2026.
  final now = DateTime(2026, 9, 23, 20);

  test('marks trained weekdays and sums the current week', () {
    final summary = ProfileWeekCalculator.summarize([
      _session(DateTime(2026, 9, 21, 18)), // pon
      _session(DateTime(2026, 9, 23, 7), minutes: 30), // śr
      _session(DateTime(2026, 9, 18, 18)), // poprzedni tydzień
    ], now: now);

    expect(summary.trainedWeekdays, {1, 3});
    expect(summary.stats.workouts, 2);
    expect(summary.stats.durationSec, 90 * 60);
  });

  test('streak counts consecutive weeks including the current one', () {
    final summary = ProfileWeekCalculator.summarize([
      _session(DateTime(2026, 9, 22)),
      _session(DateTime(2026, 9, 15)),
      _session(DateTime(2026, 9, 8)),
      // przerwa w tygodniu od 31 sierpnia
      _session(DateTime(2026, 8, 25)),
    ], now: now);

    expect(summary.streakWeeks, 3);
  });

  test('streak survives a current week without a workout yet', () {
    final summary = ProfileWeekCalculator.summarize([
      _session(DateTime(2026, 9, 15)),
      _session(DateTime(2026, 9, 8)),
    ], now: now);

    expect(summary.trainedWeekdays, isEmpty);
    expect(summary.streakWeeks, 2);
  });

  test('no recent workouts means no streak', () {
    final summary = ProfileWeekCalculator.summarize([
      _session(DateTime(2026, 9, 1)),
    ], now: now);

    expect(summary.streakWeeks, 0);
  });

  test('formatCompactCount groups and abbreviates', () {
    expect(formatCompactCount(987), '987');
    expect(formatCompactCount(1234), '1 234');
    expect(formatCompactCount(12345), '12,3 tys.');
    expect(formatCompactCount(120000), '120 tys.');
    expect(formatCompactCount(1250000), '1,2 mln');
  });
}
