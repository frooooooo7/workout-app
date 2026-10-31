import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/training/domain/models/training_session.dart';
import 'package:gym/features/training/domain/repositories/training_session_repository.dart';
import 'package:gym/features/training/presentation/bloc/training_session_cubit.dart';
import 'package:gym/features/training/presentation/utils/start_workout.dart';

class _Repo extends Fake implements TrainingSessionRepository {
  _Repo(this.active);

  TrainingSession? active;
  final cancelled = <String>[];

  @override
  Future<TrainingSession?> getActive() async => active;

  @override
  Future<TrainingSession> cancel(String sessionId) async {
    cancelled.add(sessionId);
    final session = active!;
    active = null;
    return session.copyWith(status: TrainingSessionStatus.cancelled);
  }
}

TrainingSessionExercise _exercise() => TrainingSessionExercise(
  exerciseId: 'bench',
  exerciseName: 'Bench press',
  exerciseMuscles: const ['chest'],
  exerciseCategory: 'compound',
  sets: [TrainingSessionSet()],
);

void main() {
  Future<(_Repo, bool)> run(TrainingSession? session) async {
    final repo = _Repo(session);
    final cubit = TrainingSessionCubit(repo, autoRefresh: false);
    final discarded = await discardEmptyCustomSession(cubit);
    expect(cubit.state.activeSession?.id, repo.active?.id);
    await cubit.close();
    return (repo, discarded);
  }

  test('an empty free workout is cancelled', () async {
    final session = TrainingSession.custom();
    final (repo, discarded) = await run(session);

    expect(discarded, isTrue);
    expect(repo.cancelled, [session.id]);
  });

  test('a free workout with an exercise is kept', () async {
    final session = TrainingSession.custom().copyWith(exercises: [_exercise()]);
    final (repo, discarded) = await run(session);

    expect(discarded, isFalse);
    expect(repo.cancelled, isEmpty);
  });

  test('an empty session started from a plan is kept', () async {
    final session = TrainingSession.custom().copyWith(planLocalId: 'plan-1');
    final (repo, discarded) = await run(session);

    expect(discarded, isFalse);
    expect(repo.cancelled, isEmpty);
  });

  test('nothing to do without an active session', () async {
    final (repo, discarded) = await run(null);

    expect(discarded, isFalse);
    expect(repo.cancelled, isEmpty);
  });
}
