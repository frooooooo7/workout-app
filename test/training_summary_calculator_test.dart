import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/training/domain/models/training_session.dart';
import 'package:gym/features/training/domain/services/training_summary_calculator.dart';

TrainingSessionSet _set({
  String? weight,
  String? reps,
  bool completed = true,
}) {
  return TrainingSessionSet(
    actualWeight: weight,
    actualReps: reps,
    completed: completed,
  );
}

TrainingSessionExercise _exercise(
  String id,
  List<TrainingSessionSet> sets, {
  String name = 'Ćwiczenie',
}) {
  return TrainingSessionExercise(
    exerciseId: id,
    exerciseName: name,
    exerciseMuscles: const ['chest'],
    exerciseCategory: 'compound',
    sets: sets,
  );
}

TrainingSession _session(
  DateTime startLocal, {
  Duration duration = const Duration(hours: 1),
  TrainingSessionStatus status = TrainingSessionStatus.completed,
  List<TrainingSessionExercise>? exercises,
}) {
  return TrainingSession(
    planName: 'Push',
    status: status,
    startedAt: startLocal.toUtc(),
    finishedAt: startLocal.add(duration).toUtc(),
    exercises:
        exercises ??
        [
          _exercise('bench', [_set(weight: '80', reps: '10')]),
        ],
  );
}

void main() {
  group('period boundaries', () {
    test('week starts on Monday 00:00 local time', () {
      expect(
        TrainingSummaryCalculator.startOfWeek(DateTime(2026, 9, 16, 10, 30)),
        DateTime(2026, 9, 14),
      );
      // Niedziela należy do tygodnia zaczętego w poprzedni poniedziałek.
      expect(
        TrainingSummaryCalculator.startOfWeek(DateTime(2026, 9, 20, 23, 59)),
        DateTime(2026, 9, 14),
      );
      expect(
        TrainingSummaryCalculator.startOfWeek(DateTime(2026, 9, 14)),
        DateTime(2026, 9, 14),
      );
    });

    test('month starts on the 1st; earliest start covers a week from the '
        'previous month', () {
      final now = DateTime(2026, 10, 2, 12);
      expect(TrainingSummaryCalculator.startOfMonth(now), DateTime(2026, 10));
      expect(
        TrainingSummaryCalculator.startOfWeek(now),
        DateTime(2026, 9, 28),
      );
      expect(
        TrainingSummaryCalculator.earliestStart(now),
        DateTime(2026, 9, 28),
      );
    });

    test('summarize splits sessions into week and month', () {
      final now = DateTime(2026, 9, 16, 20);
      final summary = TrainingSummaryCalculator.summarize([
        _session(DateTime(2026, 9, 14, 0, 0)), // początek tygodnia
        _session(DateTime(2026, 9, 16, 18)), // dziś
        _session(DateTime(2026, 9, 13, 23, 59)), // ostatnia chwila przed tyg.
        _session(DateTime(2026, 9, 1, 7)), // początek miesiąca
        _session(DateTime(2026, 8, 31, 23, 59)), // poprzedni miesiąc
        _session(
          DateTime(2026, 9, 15, 18),
          status: TrainingSessionStatus.cancelled,
        ),
        _session(
          DateTime(2026, 9, 15, 19),
          status: TrainingSessionStatus.active,
        ),
        _session(DateTime(2026, 9, 17, 8)), // przyszłość (błędny zegar)
      ], now: now);

      expect(summary.week.workouts, 2);
      expect(summary.month.workouts, 4);
      expect(summary.week.durationSec, 2 * 3600);
      expect(summary.month.volumeKg, 4 * 800);
    });
  });

  group('aggregate', () {
    test('parses comma and dot weights, ignores incomplete sets', () {
      final stats = TrainingSummaryCalculator.aggregate([
        _session(
          DateTime(2026, 9, 15, 18),
          duration: const Duration(minutes: 57),
          exercises: [
            _exercise('bench', [
              _set(weight: '82,5', reps: '8'),
              _set(weight: '82.5', reps: ' 8 '),
              _set(weight: '100', reps: '10', completed: false),
            ]),
            _exercise('pullups', [
              _set(reps: '12'), // masa własna: powtórzenia bez objętości
              _set(weight: 'abc', reps: '8-10'), // zakres: seria bez liczb
            ]),
            _exercise('squat', [
              _set(weight: '120', reps: '5', completed: false),
            ]),
          ],
        ),
      ]);

      expect(stats.workouts, 1);
      expect(stats.durationSec, 57 * 60);
      expect(stats.completedSets, 4);
      expect(stats.reps, 8 + 8 + 12);
      expect(stats.volumeKg, closeTo(82.5 * 8 * 2, 0.001));
      // squat ma tylko nieukończone serie
      expect(stats.distinctExercises, 2);
    });

    test('counts distinct exercises across sessions, by id or name', () {
      final stats = TrainingSummaryCalculator.aggregate([
        _session(
          DateTime(2026, 9, 14, 18),
          exercises: [
            _exercise('bench', [_set(weight: '80', reps: '5')]),
            _exercise('', [_set(reps: '10')], name: 'Pompki'),
          ],
        ),
        _session(
          DateTime(2026, 9, 16, 18),
          exercises: [
            _exercise('bench', [_set(weight: '85', reps: '5')]),
            _exercise('', [_set(reps: '12')], name: ' pompki '),
            _exercise('row', [_set(weight: '60', reps: '10')]),
          ],
        ),
      ]);

      expect(stats.workouts, 2);
      expect(stats.distinctExercises, 3);
      expect(stats.volumeKg, 400 + 425 + 600);
    });

    test('empty input yields zeros', () {
      final stats = TrainingSummaryCalculator.aggregate(const []);
      expect(stats.workouts, 0);
      expect(stats.volumeKg, 0);
      expect(stats.distinctExercises, 0);
    });
  });
}
