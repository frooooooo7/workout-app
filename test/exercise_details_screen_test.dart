import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:gym/features/library/domain/repositories/exercise_repository.dart';
import 'package:gym/features/library/presentation/bloc/exercise_details_cubit.dart';
import 'package:gym/features/library/presentation/screens/exercise_details_screen.dart';
import 'package:gym/features/training/domain/models/training_session.dart';
import 'package:gym/features/training/domain/repositories/training_stats_repository.dart';

const _exercise = Exercise(
  id: 'bench',
  name: 'Wyciskanie sztangi na ławce',
  muscles: [MuscleGroup.chest, MuscleGroup.triceps, MuscleGroup.shoulders],
  category: ExerciseCategory.compound,
  description: 'Łopatki ściągnięte, stopy mocno w podłodze.',
);

class _FakeRepository implements ExerciseRepository {
  final favourites = <String, bool>{};

  @override
  Future<void> setFavourite(String id, {required bool isFavourite}) async {
    favourites[id] = isFavourite;
  }

  @override
  Future<List<Exercise>> getAll({
    MuscleGroup? muscleGroup,
    LibraryFilter? filter,
    String? query,
  }) async =>
      [_exercise];

  @override
  Future<Exercise> create({
    required String name,
    required List<MuscleGroup> muscles,
    required ExerciseCategory category,
    required String description,
    Uint8List? imageBytes,
    String? imageFilename,
  }) =>
      throw UnimplementedError();

  @override
  Future<Exercise> update({
    required String id,
    required String name,
    required List<MuscleGroup> muscles,
    required ExerciseCategory category,
    required String description,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> delete(String id) => throw UnimplementedError();
}

class _FakeStats implements TrainingStatsRepository {
  _FakeStats(this.sessions);

  final List<TrainingSession> sessions;

  @override
  Future<List<TrainingSession>> completedSessionsSince(DateTime from) async =>
      sessions;
}

TrainingSession _session(DateTime date, String weight, String reps) =>
    TrainingSession(
      planName: 'Push',
      status: TrainingSessionStatus.completed,
      startedAt: date,
      finishedAt: date,
      exercises: [
        TrainingSessionExercise(
          exerciseId: 'bench',
          exerciseName: _exercise.name,
          exerciseMuscles: const ['chest'],
          exerciseCategory: 'compound',
          sets: [
            TrainingSessionSet(
              actualWeight: weight,
              actualReps: reps,
              completed: true,
            ),
          ],
        ),
      ],
    );

Future<_FakeRepository> _pump(
  WidgetTester tester, {
  List<TrainingSession> sessions = const [],
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final repository = _FakeRepository();
  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider(
        create: (_) => ExerciseDetailsCubit(
          repository: repository,
          statsRepository: _FakeStats(sessions),
          exerciseId: _exercise.id,
          initialExercise: _exercise,
        )..load(),
        child: const ExerciseDetailsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  testWidgets('pokazuje nazwę, mięśnie, rekordy i opis', (tester) async {
    await _pump(
      tester,
      sessions: [
        _session(DateTime(2026, 9, 1), '80', '8'),
        _session(DateTime(2026, 9, 8), '90', '5'),
      ],
    );

    expect(find.text(_exercise.name), findsWidgets);
    expect(find.text('Zaangażowane mięśnie'), findsOneWidget);
    expect(find.text('Klatka piersiowa'), findsWidgets);

    await tester.scrollUntilVisible(find.text('Progres szacowanego 1RM'), 200);
    expect(find.text('Twoje wyniki'), findsOneWidget);
    expect(find.text('90'), findsOneWidget);
    expect(find.text('× 5 powtórzeń'), findsOneWidget);

    await tester.scrollUntilVisible(find.text(_exercise.description), 200);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bez historii pokazuje stan „Brak wyników”', (tester) async {
    await _pump(tester);

    await tester.scrollUntilVisible(find.text('Brak wyników'), 200);
    expect(find.text('Brak wyników'), findsOneWidget);
  });

  testWidgets('gwiazdka przełącza ulubione', (tester) async {
    final repository = await _pump(tester);

    await tester.tap(find.byTooltip('Dodaj do ulubionych'));
    await tester.pumpAndSettle();

    expect(repository.favourites['bench'], isTrue);
    expect(find.byTooltip('Usuń z ulubionych'), findsOneWidget);
  });
}
