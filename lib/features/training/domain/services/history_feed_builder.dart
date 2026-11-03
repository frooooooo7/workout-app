import '../models/training_history_models.dart';
import '../models/training_session.dart';
import 'stats/personal_records_calculator.dart';
import 'stats/stats_sets.dart';
import 'training_session_detail_mapper.dart';

/// Jedno ćwiczenie na karcie treningu w Historii: nazwa i jego najlepszy
/// wynik z tej sesji.
class HistoryFeedLine {
  const HistoryFeedLine({
    required this.name,
    this.weightKg,
    this.reps,
    this.durationSeconds,
    this.distanceM,
    this.distanceUnit = DistanceUnit.km,
    this.isRecord = false,
  });

  final String name;

  /// Najcięższa seria robocza; `null` (albo 0) — ćwiczenie z masą własną.
  final double? weightKg;
  final int? reps;

  /// Kardio i ćwiczenia na czas: suma zrobionych odcinków.
  final int? durationSeconds;
  final int? distanceM;
  final DistanceUnit distanceUnit;

  /// Ćwiczenie pobiło w tej sesji rekord życiowy.
  final bool isRecord;
}

/// Trening na liście Historii: pozycja listy (do kalendarza, tygodni i szczegółów)
/// plus to, co karta pokazuje bez otwierania sesji.
class HistoryFeedEntry {
  const HistoryFeedEntry({
    required this.item,
    this.lines = const [],
    this.recordsCount = 0,
    this.note,
  });

  final TrainingSessionListItem item;

  /// Główne ćwiczenia w kolejności z treningu. Puste, gdy znamy tylko pozycję
  /// listy z serwera (jeszcze bez pobranych ćwiczeń).
  final List<HistoryFeedLine> lines;

  /// Rekordy pobite w tej sesji (z całej historii).
  final int recordsCount;

  final String? note;

  /// Dzień treningu, czas lokalny, bez godziny.
  DateTime get day {
    final local = item.startedAt.toLocal();
    return DateTime(local.year, local.month, local.day);
  }
}

/// Karta pokazuje tyle ćwiczeń; resztę widać w szczegółach sesji.
const historyFeedMaxLines = 3;

/// Buduje listę Historii z ukończonych sesji z lokalnej bazy, od najnowszej.
///
/// Na karcie ląduje [maxLines] ćwiczeń o największej objętości (a bez ciężaru
/// — o największej liczbie serii), w kolejności z treningu. Każde pokazuje
/// swoją najlepszą serię. Ćwiczenie jest „rekordowe”, gdy [records] mają dla
/// niego wpis z tej sesji.
List<HistoryFeedEntry> buildHistoryFeed(
  Iterable<TrainingSession> sessions,
  PersonalRecordsResult records, {
  int maxLines = historyFeedMaxLines,
}) {
  final recordKeysBySession = <String, Set<String>>{};
  for (final record in records.records) {
    (recordKeysBySession[record.sessionId] ??= {}).add(record.exerciseKey);
  }

  final entries = <HistoryFeedEntry>[];
  for (final session in sessions) {
    if (session.status != TrainingSessionStatus.completed) continue;
    final recordKeys = recordKeysBySession[session.id] ?? const <String>{};
    final note = session.note?.trim();
    entries.add(
      HistoryFeedEntry(
        item: trainingSessionListItemFromSession(session),
        lines: _linesOf(session, recordKeys, maxLines),
        recordsCount: recordKeys.length,
        note: note == null || note.isEmpty ? null : note,
      ),
    );
  }
  entries.sort((a, b) => b.item.startedAt.compareTo(a.item.startedAt));
  return entries;
}

/// Pozycja z samej listy serwera — bez ćwiczeń, z liczbą rekordów od serwera.
HistoryFeedEntry historyFeedEntryFromListItem(TrainingSessionListItem item) {
  final note = item.notePreview?.trim();
  return HistoryFeedEntry(
    item: item,
    recordsCount: item.prsCount ?? 0,
    note: note == null || note.isEmpty ? null : note,
  );
}

class _Candidate {
  _Candidate(this.index, this.line, this.volumeKg, this.sets);

  final int index;
  final HistoryFeedLine line;
  final double volumeKg;
  final int sets;
}

List<HistoryFeedLine> _linesOf(
  TrainingSession session,
  Set<String> recordKeys,
  int maxLines,
) {
  final candidates = <_Candidate>[];
  for (var i = 0; i < session.exercises.length; i++) {
    final exercise = session.exercises[i];
    final isRecord = recordKeys.contains(statsExerciseKey(exercise));
    final candidate = exercise.tracking.isCardio
        ? _cardioCandidate(i, exercise, isRecord)
        : _strengthCandidate(i, exercise, isRecord);
    if (candidate != null) candidates.add(candidate);
  }

  final ranked = [...candidates]
    ..sort((a, b) {
      final byVolume = b.volumeKg.compareTo(a.volumeKg);
      if (byVolume != 0) return byVolume;
      final bySets = b.sets.compareTo(a.sets);
      return bySets != 0 ? bySets : a.index.compareTo(b.index);
    });
  final chosen = ranked.take(maxLines).toList()
    ..sort((a, b) => a.index.compareTo(b.index));
  return [for (final c in chosen) c.line];
}

_Candidate? _strengthCandidate(
  int index,
  TrainingSessionExercise exercise,
  bool isRecord,
) {
  double? bestWeight;
  int? bestReps;
  var sets = 0;
  var volume = 0.0;
  for (final set in completedSetsOf(exercise)) {
    sets++;
    final weight = set.hasWeight ? set.weightKg : null;
    final reps = set.reps;
    volume += set.volumeKg;
    final better = switch ((weight, bestWeight)) {
      (null, null) => (reps ?? 0) > (bestReps ?? 0),
      (null, _) => false,
      (_, null) => true,
      (final w?, final b?) =>
        w > b || (w == b && (reps ?? 0) > (bestReps ?? 0)),
    };
    if (better) {
      bestWeight = weight;
      bestReps = reps;
    }
  }
  if (sets == 0) return null;
  return _Candidate(
    index,
    HistoryFeedLine(
      name: exercise.exerciseName.trim(),
      weightKg: bestWeight,
      reps: bestReps,
      isRecord: isRecord,
    ),
    volume,
    sets,
  );
}

_Candidate? _cardioCandidate(
  int index,
  TrainingSessionExercise exercise,
  bool isRecord,
) {
  var seconds = 0;
  var meters = 0;
  var sets = 0;
  for (final set in exercise.sets) {
    if (!set.completed) continue;
    final duration = set.actualDurationSeconds ?? 0;
    final distance = set.actualDistanceM ?? 0;
    if (duration == 0 && distance == 0) continue;
    sets++;
    seconds += duration;
    meters += distance;
  }
  if (sets == 0) return null;
  return _Candidate(
    index,
    HistoryFeedLine(
      name: exercise.exerciseName.trim(),
      durationSeconds: seconds > 0 ? seconds : null,
      distanceM: meters > 0 ? meters : null,
      distanceUnit: exercise.distanceUnit,
      isRecord: isRecord,
    ),
    0,
    sets,
  );
}
