import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/training/domain/models/training_history_models.dart';
import 'package:gym/features/training/domain/services/history_week_grouper.dart';
import 'package:gym/features/training/presentation/widgets/workout_history/history_formatters.dart';

TrainingSessionListItem _item(String id, DateTime local, double volume) =>
    TrainingSessionListItem(
      id: id,
      startedAt: local.toUtc(),
      endedAt: null,
      durationSec: 0,
      status: TrainingSessionStatus.completed,
      plan: const TrainingPlanSummary(id: '', name: 'Push'),
      exercisesCount: 0,
      completedSetsCount: 0,
      hasNote: false,
      updatedAt: local.toUtc(),
      totalVolumeKg: volume,
    );

void main() {
  test('groups sessions into weeks, newest first, with weekly volume', () {
    final groups = groupSessionsByWeek([
      _item('mon', DateTime(2026, 10, 12, 17), 4150),
      _item('sun-prev', DateTime(2026, 10, 11, 9), 1000),
      _item('wed', DateTime(2026, 10, 14, 18), 8290),
      _item('old', DateTime(2026, 10, 1, 18), 500),
    ]);

    expect(groups.map((g) => g.weekStart), [
      DateTime(2026, 10, 12),
      DateTime(2026, 10, 5),
      DateTime(2026, 9, 28),
    ]);
    expect(groups.first.sessions.map((s) => s.id), ['wed', 'mon']);
    expect(groups.first.totalVolumeKg, 12440);
    expect(groups.last.weekEnd, DateTime(2026, 10, 4));
  });

  test('formats week ranges, durations and counts', () {
    expect(
      formatWeekRange(DateTime(2026, 10, 12), DateTime(2026, 10, 18)),
      '12–18 paź',
    );
    expect(
      formatWeekRange(DateTime(2026, 9, 28), DateTime(2026, 10, 4)),
      '28 wrz – 4 paź',
    );
    expect(formatHoursMinutes(52 * 60), '52 min');
    expect(formatHoursMinutes(62 * 60 + 30), '1 h 02 min');
    expect(formatWorkoutCount(1), '1 trening');
    expect(formatWorkoutCount(3), '3 treningi');
    expect(formatWorkoutCount(9), '9 treningów');
  });
}
