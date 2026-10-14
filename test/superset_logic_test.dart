import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:gym/features/training/domain/models/custom_training_plan.dart';
import 'package:gym/features/training/domain/models/training_session.dart';
import 'package:gym/features/training/domain/services/rest_history.dart';
import 'package:gym/features/training/domain/services/superset_groups.dart';
import 'package:gym/features/training/domain/services/superset_rounds.dart';

PlanExercise _pe(String name, [String? group]) => PlanExercise(
  id: name,
  exercise: Exercise(
    id: 'ex-$name',
    name: name,
    muscles: const [],
    category: ExerciseCategory.values.first,
  ),
  supersetGroup: group,
);

List<String?> _groups(List<PlanExercise> list) => [
  for (final e in list) e.supersetGroup,
];

TrainingSessionExercise _se(
  String name, {
  String? group,
  int sets = 3,
  int done = 0,
  int? rest,
}) => TrainingSessionExercise(
  id: name,
  exerciseId: 'ex-$name',
  exerciseName: name,
  exerciseMuscles: const [],
  exerciseCategory: 'other',
  supersetGroup: group,
  restSeconds: rest,
  sets: [
    for (var i = 0; i < sets; i++) TrainingSessionSet(completed: i < done),
  ],
);

void main() {
  group('SupersetGroups in the plan editor', () {
    test('linking two exercises makes group A, the next pair group B', () {
      var list = [_pe('a'), _pe('b'), _pe('c'), _pe('d')];
      list = SupersetGroups.linkWithNext(list, 2);
      expect(_groups(list), [null, null, 'A', 'A']);
      list = SupersetGroups.linkWithNext(list, 0);
      expect(_groups(list), ['A', 'A', 'B', 'B']);
    });

    test('linking next to a group adds the exercise to it', () {
      var list = [_pe('a', 'A'), _pe('b', 'A'), _pe('c')];
      list = SupersetGroups.linkWithNext(list, 1);
      expect(_groups(list), ['A', 'A', 'A']);
      expect(SupersetGroups.canLinkWithNext(list, 0), isFalse);
    });

    test('dragging an exercise out leaves no one-exercise group', () {
      final list = SupersetGroups.normalize([
        _pe('a', 'A'),
        _pe('x'),
        _pe('b', 'A'),
        _pe('c', 'B'),
        _pe('d', 'B'),
      ]);
      expect(_groups(list), [null, null, null, 'A', 'A']);
    });

    test('unlink splits the group and renumbers the rest', () {
      final list = SupersetGroups.unlink([
        _pe('a', 'A'),
        _pe('b', 'A'),
        _pe('c', 'B'),
        _pe('d', 'B'),
      ], 'A');
      expect(_groups(list), [null, null, 'A', 'A']);
    });

    test('rest belongs after the last exercise of a group', () {
      final list = [_pe('a', 'A'), _pe('b', 'A'), _pe('c')];
      bool ends(int i) =>
          SupersetGroups.endsRound(list, i, (e) => e.supersetGroup);
      expect([ends(0), ends(1), ends(2)], [false, true, true]);
    });
  });

  group('SupersetRounds during a workout', () {
    test('a superset is one block', () {
      final blocks = SupersetRounds.blocks([
        _se('a'),
        _se('b', group: 'A'),
        _se('c', group: 'A'),
        _se('d'),
      ]);
      expect(blocks, [
        [0],
        [1, 2],
        [3],
      ]);
      expect(SupersetRounds.blockOf(blocks, 2), 1);
    });

    test('after A1 goes A2 without rest, after A2 the round rest', () {
      final afterA1 = [
        _se('a', group: 'A', done: 1, rest: 999),
        _se('b', group: 'A', rest: 90),
      ];
      final first = SupersetRounds.afterSet(afterA1, 0);
      expect(first.rest, isFalse);
      expect(first.next, 1);
      expect(first.restSeconds, 90);
      expect(SupersetRounds.roundOf(afterA1, [0, 1]), (1, 3));

      final afterA2 = [
        _se('a', group: 'A', done: 1),
        _se('b', group: 'A', done: 1, rest: 90),
      ];
      final second = SupersetRounds.afterSet(afterA2, 1);
      expect(second.rest, isTrue);
      expect(second.restSeconds, 90);
      expect(second.next, 0);
      expect(SupersetRounds.roundOf(afterA2, [0, 1]), (2, 3));
    });

    test('a member with fewer sets drops out of later rounds', () {
      final exercises = [
        _se('a', group: 'A', sets: 3, done: 2),
        _se('b', group: 'A', sets: 2, done: 2, rest: 60),
      ];
      expect(SupersetRounds.focusOf(exercises, [0, 1]), 0);
      final after = SupersetRounds.afterSet([
        _se('a', group: 'A', sets: 3, done: 3),
        _se('b', group: 'A', sets: 2, done: 2, rest: 60),
      ], 0);
      expect(after.rest, isTrue);
    });

    test('a plain exercise rests with its own rest', () {
      final after = SupersetRounds.afterSet([_se('a', done: 1, rest: 75)], 0);
      expect(after.rest, isTrue);
      expect(after.restSeconds, 75);
    });
  });

  group('RestHistory', () {
    TrainingSession session(DateTime start, List<int> gapsSec) {
      var t = start;
      final sets = <TrainingSessionSet>[
        TrainingSessionSet(completed: true, completedAt: t),
      ];
      for (final gap in gapsSec) {
        t = t.add(Duration(seconds: gap));
        sets.add(TrainingSessionSet(completed: true, completedAt: t));
      }
      return TrainingSession(
        planName: 'Góra',
        startedAt: start,
        exercises: [
          TrainingSessionExercise(
            exerciseId: 'ex-a',
            exerciseName: 'A',
            exerciseMuscles: const [],
            exerciseCategory: 'other',
            sets: sets,
          ),
        ],
      );
    }

    test('averages gaps of the last sessions and ignores outliers', () {
      final average = RestHistory.average(
        [
          session(DateTime.utc(2026, 10, 1), [150, 170]),
          session(DateTime.utc(2026, 10, 3), [160, 3600, 5]),
        ],
        exerciseId: 'ex-a',
        exerciseName: 'A',
      );
      expect(average, (seconds: 160, sessions: 2));
      expect(RestHistory.suggestion(160), 165);
    });

    test('no completed pairs means no hint', () {
      expect(
        RestHistory.average(
          [session(DateTime.utc(2026, 10, 1), [])],
          exerciseId: 'ex-a',
          exerciseName: 'A',
        ),
        isNull,
      );
    });
  });
}
