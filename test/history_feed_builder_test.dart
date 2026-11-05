import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/training/domain/models/training_history_models.dart';
import 'package:gym/features/training/domain/models/training_session.dart';
import 'package:gym/features/training/domain/services/history_feed_builder.dart';
import 'package:gym/features/training/domain/services/stats/personal_records_calculator.dart';

TrainingSessionSet _set(
  String weight,
  String reps, {
  SetType type = SetType.normal,
  bool completed = true,
}) => TrainingSessionSet(
  setType: type,
  actualWeight: weight,
  actualReps: reps,
  completed: completed,
);

TrainingSessionExercise _exercise(
  String name,
  List<TrainingSessionSet> sets, {
  ExerciseTracking tracking = ExerciseTracking.weightReps,
}) => TrainingSessionExercise(
  exerciseId: name,
  exerciseName: name,
  exerciseMuscles: const [],
  exerciseCategory: 'strength',
  sets: sets,
  tracking: tracking,
);

TrainingSession _session(
  String id,
  DateTime startedAt,
  List<TrainingSessionExercise> exercises, {
  String? note,
}) => TrainingSession(
  id: id,
  planName: 'Push',
  status: TrainingSessionStatus.completed,
  startedAt: startedAt.toUtc(),
  finishedAt: startedAt.add(const Duration(hours: 1)).toUtc(),
  note: note,
  exercises: exercises,
);

TrainingSessionExercise _cardio(int seconds, int meters) =>
    _exercise('Bieżnia', [
      TrainingSessionSet(
        completed: true,
        actualDurationSeconds: seconds,
        actualDistanceM: meters,
      ),
    ], tracking: ExerciseTracking.durationDistance);

void main() {
  final day = DateTime(2026, 10, 12, 17);

  test('shows the three biggest exercises in session order', () {
    final session = _session('s', day, [
      _exercise('Rozpiętki', [_set('20', '10')]), // 200
      _exercise('Wyciskanie', [_set('90', '5'), _set('80', '8')]), // 1090
      _exercise('Biceps', [_set('10', '10')]), // 100
      _exercise('Przysiad', [_set('120', '5')]), // 600
    ]);

    final entry = buildHistoryFeed([
      session,
    ], PersonalRecordsResult.empty).single;

    expect(entry.lines.map((l) => l.name), [
      'Rozpiętki',
      'Wyciskanie',
      'Przysiad',
    ]);
  });

  test('a line carries the heaviest working set, warm-ups excluded', () {
    final session = _session('s', day, [
      _exercise('Wyciskanie', [
        _set('140', '3', type: SetType.warmup),
        _set('90', '5'),
        _set('92,5', '4'),
        _set('100', '2', completed: false),
      ]),
    ]);

    final line = buildHistoryFeed([
      session,
    ], PersonalRecordsResult.empty).single.lines.single;

    expect(line.weightKg, 92.5);
    expect(line.reps, 4);
  });

  test('bodyweight exercise shows its best reps without a weight', () {
    final session = _session('s', day, [
      _exercise('Pompki', [_set('', '12'), _set('', '15')]),
    ]);

    final line = buildHistoryFeed([
      session,
    ], PersonalRecordsResult.empty).single.lines.single;

    expect(line.weightKg, isNull);
    expect(line.reps, 15);
  });

  test('cardio sums duration and distance of finished segments', () {
    final session = _session('s', day, [
      _exercise('Bieżnia', [
        TrainingSessionSet(
          completed: true,
          actualDurationSeconds: 600,
          actualDistanceM: 1500,
        ),
        TrainingSessionSet(
          completed: true,
          actualDurationSeconds: 300,
          actualDistanceM: 800,
        ),
        TrainingSessionSet(completed: false, actualDurationSeconds: 900),
      ], tracking: ExerciseTracking.durationDistance),
    ]);

    final line = buildHistoryFeed([
      session,
    ], PersonalRecordsResult.empty).single.lines.single;

    expect(line.durationSeconds, 900);
    expect(line.distanceM, 2300);
  });

  test('exercises without a finished set are left out', () {
    final session = _session('s', day, [
      _exercise('Pominięte', [_set('50', '8', completed: false)]),
      _exercise('Zrobione', [_set('50', '8')]),
    ]);

    final entry = buildHistoryFeed([
      session,
    ], PersonalRecordsResult.empty).single;

    expect(entry.lines.map((l) => l.name), ['Zrobione']);
  });

  test('marks record exercises and counts the records of the session', () {
    final older = _session('old', day.subtract(const Duration(days: 7)), [
      _exercise('Wyciskanie', [_set('80', '5')]),
      _exercise('Przysiad', [_set('100', '5')]),
    ]);
    final newer = _session('new', day, [
      _exercise('Wyciskanie', [_set('90', '5')]),
      _exercise('Przysiad', [_set('100', '5')]),
    ]);
    final records = PersonalRecordsCalculator.compute([older, newer]);

    final entries = buildHistoryFeed([older, newer], records);

    // Od najnowszej.
    expect(entries.map((e) => e.item.id), ['new', 'old']);
    expect(entries.first.recordsCount, 1);
    expect(entries.first.lines.map((l) => (l.name, l.isRecord)), [
      ('Wyciskanie', true),
      ('Przysiad', false),
    ]);
    expect(entries.last.recordsCount, 0);
  });

  test('a record exercise is shown even when it is not among the biggest', () {
    TrainingSession build(String id, DateTime at, String dipsReps) =>
        _session(id, at, [
          _exercise('Wyciskanie', [_set('100', '5')]), // 500
          _exercise('Przysiad', [_set('120', '5')]), // 600
          _exercise('Martwy ciąg', [_set('140', '3')]), // 420
          // Masa własna: tonaż 0, a to właśnie tu padł rekord.
          _exercise('Dipy', [_set('0', dipsReps)]),
        ]);
    final older = build('old', day.subtract(const Duration(days: 7)), '8');
    final newer = build('new', day, '12');
    final records = PersonalRecordsCalculator.compute([older, newer]);

    final entry = buildHistoryFeed([older, newer], records).first;

    expect(entry.lines.map((l) => l.name), contains('Dipy'));
    expect(entry.lines.length, 3);
    expect(entry.lines.firstWhere((l) => l.name == 'Dipy').isRecord, isTrue);
  });

  test('keeps the trimmed session note and drops a blank one', () {
    final withNote = _session('a', day, [
      _exercise('Wyciskanie', [_set('90', '5')]),
    ], note: '  Barki bolą  ');
    final blank = _session('b', day.add(const Duration(hours: 3)), [
      _exercise('Wyciskanie', [_set('90', '5')]),
    ], note: '   ');

    final entries = buildHistoryFeed([
      withNote,
      blank,
    ], PersonalRecordsResult.empty);

    expect(entries.firstWhere((e) => e.item.id == 'a').note, 'Barki bolą');
    expect(entries.firstWhere((e) => e.item.id == 'b').note, isNull);
  });

  test('an entry from a server list item has no lines but keeps records', () {
    final item = TrainingSessionListItem(
      id: 'srv',
      startedAt: day.toUtc(),
      endedAt: null,
      durationSec: 3600,
      status: TrainingSessionStatus.completed,
      plan: const TrainingPlanSummary(id: 'p', name: 'Push'),
      exercisesCount: 5,
      completedSetsCount: 15,
      hasNote: true,
      updatedAt: day.toUtc(),
      prsCount: 2,
      notePreview: 'Dobry dzień',
    );

    final entry = historyFeedEntryFromListItem(item);

    expect(entry.lines, isEmpty);
    expect(entry.recordsCount, 2);
    expect(entry.note, 'Dobry dzień');
  });

  test(
    'the same exercise twice in a workout is one line with the best set',
    () {
      final feed = buildHistoryFeed([
        _session('a', day, [
          _exercise('Wyciskanie', [_set('80', '8')]),
          _exercise('OHP', [_set('40', '8')]),
          _exercise('Wyciskanie', [_set('90', '5'), _set('85', '6')]),
        ]),
      ], PersonalRecordsResult.empty);

      final lines = feed.single.lines;
      expect(lines.map((l) => l.name), ['Wyciskanie', 'OHP']);
      expect(lines.first.weightKg, 90);
      expect(lines.first.reps, 5);
    },
  );

  test('a repeated cardio exercise sums its segments into one line', () {
    final feed = buildHistoryFeed([
      _session('a', day, [_cardio(600, 2000), _cardio(300, 1000)]),
    ], PersonalRecordsResult.empty);

    final line = feed.single.lines.single;
    expect(line.durationSeconds, 900);
    expect(line.distanceM, 3000);
  });
}
