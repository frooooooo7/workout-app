import '../models/training_history_models.dart';
import 'training_summary_calculator.dart';

/// Sesje z jednego tygodnia (poniedziałek–niedziela) na liście historii.
class HistoryWeekGroup {
  const HistoryWeekGroup({required this.weekStart, required this.sessions});

  /// Poniedziałek 00:00 czasu lokalnego.
  final DateTime weekStart;

  /// Od najnowszej.
  final List<TrainingSessionListItem> sessions;

  /// Niedziela tego tygodnia (data bez godziny).
  DateTime get weekEnd =>
      DateTime(weekStart.year, weekStart.month, weekStart.day + 6);

  /// Suma objętości tygodnia w kilogramach.
  double get totalVolumeKg =>
      sessions.fold(0, (sum, s) => sum + (s.totalVolumeKg ?? 0));
}

/// Grupuje sesje w tygodnie, od najnowszego. Kolejność wejścia jest dowolna.
List<HistoryWeekGroup> groupSessionsByWeek(
  Iterable<TrainingSessionListItem> sessions,
) {
  final ordered = [...sessions]
    ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  final groups = <HistoryWeekGroup>[];
  for (final session in ordered) {
    final week = TrainingSummaryCalculator.startOfWeek(session.startedAt);
    if (groups.isEmpty || groups.last.weekStart != week) {
      groups.add(HistoryWeekGroup(weekStart: week, sessions: [session]));
    } else {
      groups.last.sessions.add(session);
    }
  }
  return groups;
}
