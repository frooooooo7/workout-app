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

  @override
  Future<List<TrainingSession>> allCompletedSessions() async => sessions;
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
  Exercise initialExercise = _exercise,
  String exerciseId = 'bench',
  bool initialIsSnapshot = false,
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
          exerciseId: exerciseId,
          initialExercise: initialExercise,
          initialIsSnapshot: initialIsSnapshot,
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

  testWidgets('historia pokazuje poprzednie treningi od najnowszego', (
    tester,
  ) async {
    await _pump(
      tester,
      sessions: [
        for (var day = 1; day <= 7; day++)
          _session(DateTime(2026, 9, day), '${70 + day * 2}', '5'),
      ],
    );

    await tester.scrollUntilVisible(find.text('Historia'), 200);
    expect(find.text('7 treningów'), findsOneWidget);

    // Najnowszy trening (84 kg) jest na górze i pobił poprzedni rekord.
    await tester.scrollUntilVisible(find.text('84 × 5'), 200);
    expect(find.text('Rekord'), findsWidgets);
    // Domyślnie widać 5 ostatnich treningów, reszta po rozwinięciu.
    expect(find.text('72 × 5'), findsNothing);
    final toggle = find.byKey(const ValueKey('exercise-history-toggle'));
    await tester.scrollUntilVisible(toggle, 200);
    expect(find.text('Pokaż wszystkie (7)'), findsOneWidget);
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('72 × 5'), 200);
    expect(find.text('Pokaż mniej'), findsOneWidget);
  });

  testWidgets('wykres przełącza metrykę', (tester) async {
    await _pump(
      tester,
      sessions: [
        _session(DateTime(2026, 9, 1), '80', '8'),
        _session(DateTime(2026, 9, 8), '90', '5'),
      ],
    );

    await tester.scrollUntilVisible(find.text('Progres szacowanego 1RM'), 200);
    final topWeight = find.byKey(
      const ValueKey('exercise-chart-metric-topWeight'),
    );
    await tester.ensureVisible(topWeight);
    await tester.pumpAndSettle();
    await tester.tap(topWeight);
    await tester.pumpAndSettle();
    expect(find.text('Najcięższa seria'), findsOneWidget);
    expect(find.text('+10 kg'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('exercise-chart-metric-volume')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Objętość na trening'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('z treningu dociąga ćwiczenie z biblioteki po nazwie', (
    tester,
  ) async {
    await _pump(
      tester,
      exerciseId: 'server-uuid',
      initialIsSnapshot: true,
      initialExercise: Exercise(
        id: 'server-uuid',
        name: _exercise.name.toUpperCase(),
        muscles: const [MuscleGroup.chest],
        category: ExerciseCategory.compound,
      ),
      sessions: [_session(DateTime(2026, 9, 1), '80', '8')],
    );

    // Opis jest tylko w bibliotece — snapshot z treningu go nie ma.
    await tester.scrollUntilVisible(find.text(_exercise.description), 200);
    expect(find.text(_exercise.name), findsWidgets);
  });
}
