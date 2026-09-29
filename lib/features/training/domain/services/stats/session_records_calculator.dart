import '../../models/training_session.dart';
import '../../models/training_stats.dart';
import '../training_summary_calculator.dart';
import 'stats_sets.dart';

/// Rekordy całych sesji z całej historii: najcięższa, najdłuższa, z największą
/// liczbą serii, oraz tydzień z największą objętością. Przy remisie wygrywa
/// wcześniejsza sesja — rekord należy do tej, która go ustanowiła.
abstract final class SessionRecordsCalculator {
  static SessionRecords compute(Iterable<TrainingSession> sessions) {
    final ordered = [
      for (final s in sessions)
        if (s.status == TrainingSessionStatus.completed) s,
    ]..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    if (ordered.isEmpty) return SessionRecords.empty;

    TrainingSession? volumeSession;
    var volumeBest = 0.0;
    TrainingSession? durationSession;
    var durationBest = 0;
    TrainingSession? setsSession;
    var setsBest = 0;

    final weekVolume = <DateTime, double>{};
    final weekWorkouts = <DateTime, int>{};

    for (final session in ordered) {
      var volume = 0.0;
      var sets = 0;
      for (final exercise in session.exercises) {
        for (final set in completedSetsOf(exercise)) {
          sets++;
          volume += set.volumeKg;
        }
      }
      final duration = TrainingSummaryCalculator.sessionDurationSec(session);

      if (volume > volumeBest) {
        volumeBest = volume;
        volumeSession = session;
      }
      if (duration > durationBest) {
        durationBest = duration;
        durationSession = session;
      }
      if (sets > setsBest) {
        setsBest = sets;
        setsSession = session;
      }

      final week = TrainingSummaryCalculator.startOfWeek(
        session.startedAt.toLocal(),
      );
      weekVolume.update(week, (v) => v + volume, ifAbsent: () => volume);
      weekWorkouts.update(week, (v) => v + 1, ifAbsent: () => 1);
    }

    SessionRecord record(
      SessionRecordKind kind,
      double value,
      TrainingSession session,
    ) => SessionRecord(
      kind: kind,
      value: value,
      sessionId: session.id,
      name: session.planName,
      date: session.startedAt,
    );

    DateTime? bestWeekStart;
    var bestWeekVolume = 0.0;
    final weeks = weekVolume.keys.toList()..sort();
    for (final week in weeks) {
      final volume = weekVolume[week]!;
      if (volume > bestWeekVolume) {
        bestWeekVolume = volume;
        bestWeekStart = week;
      }
    }

    return SessionRecords(
      records: [
        if (volumeSession != null)
          record(SessionRecordKind.volume, volumeBest, volumeSession),
        if (durationSession != null)
          record(
            SessionRecordKind.duration,
            durationBest.toDouble(),
            durationSession,
          ),
        if (setsSession != null)
          record(SessionRecordKind.sets, setsBest.toDouble(), setsSession),
      ],
      bestWeek: bestWeekStart == null
          ? null
          : BestWeek(
              start: bestWeekStart,
              volumeKg: bestWeekVolume,
              workouts: weekWorkouts[bestWeekStart] ?? 0,
            ),
    );
  }
}
