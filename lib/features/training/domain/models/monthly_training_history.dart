import 'training_history_models.dart';

class MonthlyTrainingStats {
  const MonthlyTrainingStats({
    required this.totalDurationSec,
    required this.totalSessions,
    required this.totalExercises,
    required this.totalSets,
    required this.totalVolumeKg,
    this.mostFrequentWeekday,
    required this.avgSessionDurationSec,
  });

  final int totalDurationSec;
  final int totalSessions;
  final int totalExercises;
  final int totalSets;
  final double totalVolumeKg;
  final int? mostFrequentWeekday; // 1 = Poniedziałek, 7 = Niedziela
  final int avgSessionDurationSec;

  factory MonthlyTrainingStats.fromSessions(List<TrainingSessionListItem> sessions) {
    if (sessions.isEmpty) {
      return const MonthlyTrainingStats(
        totalDurationSec: 0,
        totalSessions: 0,
        totalExercises: 0,
        totalSets: 0,
        totalVolumeKg: 0,
        mostFrequentWeekday: null,
        avgSessionDurationSec: 0,
      );
    }

    int totalDuration = 0;
    int totalExercises = 0;
    int totalSets = 0;
    double totalVolume = 0;
    final weekdayCounts = <int, int>{};

    for (final s in sessions) {
      totalDuration += s.durationSec;
      totalExercises += s.exercisesCount;
      totalSets += s.completedSetsCount;
      totalVolume += s.totalVolumeKg ?? 0;
      final weekday = s.startedAt.toLocal().weekday;
      weekdayCounts[weekday] = (weekdayCounts[weekday] ?? 0) + 1;
    }

    int? topWeekday;
    int maxCount = 0;
    weekdayCounts.forEach((weekday, count) {
      if (count > maxCount) {
        maxCount = count;
        topWeekday = weekday;
      }
    });

    return MonthlyTrainingStats(
      totalDurationSec: totalDuration,
      totalSessions: sessions.length,
      totalExercises: totalExercises,
      totalSets: totalSets,
      totalVolumeKg: totalVolume,
      mostFrequentWeekday: topWeekday,
      avgSessionDurationSec: (totalDuration / sessions.length).round(),
    );
  }
}

class MonthlyTrainingHistory {
  const MonthlyTrainingHistory({
    required this.month,
    required this.stats,
    required this.trainingDays,
    required this.sessions,
  });

  final DateTime month;
  final MonthlyTrainingStats stats;
  final Set<DateTime> trainingDays;
  final List<TrainingSessionListItem> sessions;
}
