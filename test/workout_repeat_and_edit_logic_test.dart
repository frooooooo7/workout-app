import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/training/domain/models/training_session.dart';
import 'package:gym/features/training/domain/services/repeat_training_session.dart';
import 'package:gym/features/training/domain/services/workout_edit.dart';

void main() {
  TrainingSession source() => TrainingSession(
    id: 'old-session',
    serverId: 'srv-old',
    planLocalId: 'plan-local',
    planServerId: 'plan-server',
    planName: 'Push A',
    status: TrainingSessionStatus.completed,
    note: 'Ciężko',
    startedAt: DateTime.utc(2026, 9, 10, 10),
    finishedAt: DateTime.utc(2026, 9, 10, 11),
    sharedToProfile: true,
    exercises: [
      TrainingSessionExercise(
        id: 'ex-1',
        exerciseId: 'bench',
        exerciseName: 'Bench',
        exerciseMuscles: const ['chest'],
        exerciseCategory: 'compound',
        exerciseImageUrl: '/img/bench.png',
        sets: [
          TrainingSessionSet(
            id: 'set-1',
            plannedWeight: '80',
            plannedReps: '5',
            actualWeight: '82.5',
            actualReps: '4',
            actualRir: '1',
            completed: true,
            completedAt: DateTime.utc(2026, 9, 10, 10, 5),
          ),
          // Nieukończona seria bez wykonania — zostaje plan.
          TrainingSessionSet(
            id: 'set-2',
            plannedWeight: '80',
            plannedReps: '5',
            plannedRir: '2',
          ),
        ],
      ),
      TrainingSessionExercise(
        id: 'ex-2',
        exerciseId: 'row',
        exerciseName: 'Row',
        exerciseMuscles: const ['lats'],
        exerciseCategory: 'compound',
        sets: [TrainingSessionSet(id: 'set-3', actualReps: ' ')],
      ),
    ],
  );

  group('buildRepeatedSession', () {
    test('copies exercises and sets, prefilled from previous results', () {
      final repeated = buildRepeatedSession(
        source(),
        planLocalId: 'plan-local',
        planServerId: 'plan-server',
        startedAt: DateTime.utc(2026, 9, 15, 8),
      );

      expect(repeated.id, isNot('old-session'));
      expect(repeated.serverId, isNull);
      expect(repeated.status, TrainingSessionStatus.active);
      expect(repeated.startedAt, DateTime.utc(2026, 9, 15, 8));
      expect(repeated.finishedAt, isNull);
      expect(repeated.note, isNull);
      expect(repeated.sharedToProfile, isFalse);
      expect(repeated.planName, 'Push A');
      expect(repeated.planLocalId, 'plan-local');
      expect(repeated.planServerId, 'plan-server');
      expect(repeated.exercises.map((e) => e.exerciseName), ['Bench', 'Row']);
      expect(repeated.exercises.first.id, isNot('ex-1'));
      expect(repeated.exercises.first.exerciseImageUrl, '/img/bench.png');

      final sets = repeated.exercises.first.sets;
      expect(sets, hasLength(2));
      expect(sets[0].id, isNot('set-1'));
      expect(sets[0].plannedWeight, '82.5');
      expect(sets[0].plannedReps, '4');
      expect(sets[0].plannedRir, '1');
      expect(sets[0].actualWeight, '82.5');
      expect(sets[0].completed, isFalse);
      expect(sets[0].completedAt, isNull);
      expect(sets[1].plannedWeight, '80');
      expect(sets[1].plannedReps, '5');
      expect(sets[1].plannedRir, '2');

      final emptySet = repeated.exercises.last.sets.single;
      expect(emptySet.plannedReps, '');
      expect(emptySet.actualReps, isNull);
    });

    test('drops plan linkage when the plan no longer exists', () {
      final repeated = buildRepeatedSession(source());

      expect(repeated.planLocalId, isNull);
      expect(repeated.planServerId, isNull);
      expect(repeated.planName, 'Push A');
    });
  });

  group('workout edit', () {
    final now = DateTime.utc(2026, 9, 15, 12);

    test('draft derives duration from start and finish', () {
      final draft = WorkoutEditDraft.fromSession(source());

      expect(draft.name, 'Push A');
      expect(draft.note, 'Ciężko');
      expect(draft.durationMinutes, '60');
      expect(validateWorkoutEdit(draft, now: now), isNull);
    });

    test('validation messages are in Polish', () {
      final draft = WorkoutEditDraft.fromSession(source());

      expect(
        validateWorkoutEdit(draft.copyWith(name: '  '), now: now),
        'Podaj nazwę treningu.',
      );
      expect(
        validateWorkoutEdit(draft.copyWith(durationMinutes: '-5'), now: now),
        'Czas trwania musi być liczbą minut (0 lub więcej).',
      );
      expect(
        validateWorkoutEdit(draft.copyWith(durationMinutes: '1441'), now: now),
        'Czas trwania nie może przekraczać 24 godzin.',
      );
      expect(
        validateWorkoutEdit(
          draft.copyWith(startedAt: now.add(const Duration(days: 1))),
          now: now,
        ),
        'Data rozpoczęcia nie może być w przyszłości.',
      );
      expect(
        validateWorkoutEdit(draft.copyWith(exercises: const []), now: now),
        'Trening musi mieć co najmniej jedno ćwiczenie.',
      );

      TrainingSessionExercise withSet(TrainingSessionSet set) =>
          draft.exercises.first.copyWith(sets: [set]);
      expect(
        validateWorkoutEdit(
          draft.copyWith(
            exercises: [withSet(TrainingSessionSet(actualWeight: '8o'))],
          ),
          now: now,
        ),
        'Nieprawidłowy ciężar: „Bench”, seria 1.',
      );
      expect(
        validateWorkoutEdit(
          draft.copyWith(
            exercises: [withSet(TrainingSessionSet(actualReps: '5.5'))],
          ),
          now: now,
        ),
        'Liczba powtórzeń musi być liczbą całkowitą: „Bench”, seria 1.',
      );
      expect(
        validateWorkoutEdit(
          draft.copyWith(
            exercises: [withSet(TrainingSessionSet(actualRir: '11'))],
          ),
          now: now,
        ),
        'RIR musi być liczbą od 0 do 10: „Bench”, seria 1.',
      );
      expect(
        validateWorkoutEdit(
          draft.copyWith(
            exercises: [draft.exercises.first.copyWith(sets: const [])],
          ),
          now: now,
        ),
        'Ćwiczenie „Bench” musi mieć co najmniej jedną serię.',
      );
      expect(
        validateWorkoutEdit(
          draft.copyWith(
            exercises: [withSet(TrainingSessionSet(actualWeight: '82,5'))],
          ),
          now: now,
        ),
        isNull,
      );
    });

    test('apply keeps identity, derives finishedAt and shifts set stamps', () {
      final original = source();
      final draft = WorkoutEditDraft.fromSession(original).copyWith(
        name: ' Push B ',
        note: '',
        startedAt: DateTime.utc(2026, 9, 10, 12),
        durationMinutes: '90',
        exercises: [
          original.exercises.first.copyWith(
            sets: [
              original.exercises.first.sets.first.copyWith(
                actualWeight: '85,5',
              ),
              original.exercises.first.sets.last,
            ],
          ),
        ],
      );

      final edited = applyWorkoutEdit(original, draft);

      expect(edited.id, 'old-session');
      expect(edited.serverId, 'srv-old');
      expect(edited.status, TrainingSessionStatus.completed);
      expect(edited.sharedToProfile, isTrue);
      expect(edited.planName, 'Push B');
      expect(edited.note, isNull);
      expect(edited.startedAt, DateTime.utc(2026, 9, 10, 12));
      expect(edited.finishedAt, DateTime.utc(2026, 9, 10, 13, 30));
      expect(edited.exercises, hasLength(1));
      final sets = edited.exercises.single.sets;
      expect(sets.first.actualWeight, '85.5');
      expect(sets.first.completedAt, DateTime.utc(2026, 9, 10, 12, 5));
      expect(sets.last.completedAt, isNull);
    });
  });
}
