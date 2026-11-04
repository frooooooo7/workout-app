import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/services/service_locator.dart';
import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:gym/features/library/domain/repositories/exercise_repository.dart';
import 'package:gym/features/library/presentation/screens/library_screen.dart';
import 'package:gym/features/library/presentation/screens/pick_exercise_screen.dart';
import 'package:gym/features/training/domain/models/training_session.dart';
import 'package:gym/features/training/domain/repositories/training_stats_repository.dart';

const _bench = Exercise(
  id: '1',
  name: 'Wyciskanie sztangi na ławce',
  muscles: [MuscleGroup.chest],
  category: ExerciseCategory.compound,
);

class _Repo implements ExerciseRepository {
  @override
  Future<List<Exercise>> getAll({
    MuscleGroup? muscleGroup,
    LibraryFilter? filter,
    String? query,
  }) async => [_bench];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Stats implements TrainingStatsRepository {
  @override
  Future<List<TrainingSession>> completedSessionsSince(DateTime from) async =>
      const [];

  @override
  Future<List<TrainingSession>> allCompletedSessions() async => const [];
}

void main() {
  setUp(() {
    ServiceLocator.debugSetUserScopedRepositories(
      exerciseRepository: _Repo(),
      trainingStatsRepository: _Stats(),
    );
  });
  tearDown(() => ServiceLocator.debugSetUserScopedRepositories());

  testWidgets('wpisz tekst, potem „wstecz”: wraca na ekran startowy, '
      'dopiero drugie „wstecz” zamyka bibliotekę', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 1600 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('trening')),
      ),
    );
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const LibraryScreen()),
    );
    await tester.pumpAndSettle();
    expect(find.text('WYBIERZ PARTIĘ'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'ławce');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('WYBIERZ PARTIĘ'), findsNothing);
    expect(find.text('Wyciskanie sztangi na ławce'), findsOneWidget);

    // Systemowe „wstecz” z wyników szukania.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(LibraryScreen), findsOneWidget);
    expect(find.text('WYBIERZ PARTIĘ'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '');

    // Drugie „wstecz” z ekranu startowego zamyka bibliotekę.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(LibraryScreen), findsNothing);
  });

  testWidgets('po wyborze partii „wstecz” wraca na ekran startowy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 1600 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: LibraryScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Wszystkie ('));
    await tester.pumpAndSettle();
    expect(find.text('WYBIERZ PARTIĘ'), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('WYBIERZ PARTIĘ'), findsOneWidget);
  });

  testWidgets('filtry z ekranu startowego prowadzą od razu do wyników', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 1600 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: LibraryScreen()));
    await tester.pumpAndSettle();
    expect(find.text('WYBIERZ PARTIĘ'), findsOneWidget);

    await tester.tap(find.byTooltip('Filtry'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Klatka piersiowa'));
    await tester.pump();
    expect(find.text('Pokaż 1 ćwiczenie'), findsOneWidget);
    await tester.tap(find.text('Pokaż 1 ćwiczenie'));
    await tester.pumpAndSettle();

    expect(find.text('WYBIERZ PARTIĘ'), findsNothing);
    expect(find.text('Wyciskanie sztangi na ławce'), findsOneWidget);
    expect(find.text('Aktywne filtry: 1'), findsOneWidget);
  });

  testWidgets('tryb wyboru: stuknięcie zaznacza, „Dodaj” zwraca listę', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 1600 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('trening')),
      ),
    );
    final result = navigatorKey.currentState!.push<List<Exercise>>(
      MaterialPageRoute(builder: (_) => const PickExerciseScreen()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Wybierz ćwiczenia'), findsOneWidget);

    await tester.tap(find.textContaining('Wszystkie ('));
    await tester.pumpAndSettle();
    expect(find.textContaining('Dodaj '), findsNothing);

    await tester.tap(find.text('Wyciskanie sztangi na ławce'));
    await tester.pumpAndSettle();
    expect(find.text('Dodaj 1 ćwiczenie'), findsOneWidget);

    // Drugie stuknięcie odznacza.
    await tester.tap(find.text('Wyciskanie sztangi na ławce'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Dodaj '), findsNothing);

    await tester.tap(find.text('Wyciskanie sztangi na ławce'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dodaj 1 ćwiczenie'));
    await tester.pumpAndSettle();

    expect((await result)!.map((e) => e.id), ['1']);
    expect(find.text('trening'), findsOneWidget);
  });

  testWidgets('tryb wyboru: „wstecz” z zaznaczeniem pyta o potwierdzenie', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 1600 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('trening')),
      ),
    );
    final result = navigatorKey.currentState!.push<List<Exercise>>(
      MaterialPageRoute(builder: (_) => const PickExerciseScreen()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Wszystkie ('));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wyciskanie sztangi na ławce'));
    await tester.pumpAndSettle();

    // Pierwsze „wstecz” wraca na ekran startowy, drugie pyta o wybór.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Porzucić wybór?'), findsOneWidget);

    await tester.tap(find.text('Zostań'));
    await tester.pumpAndSettle();
    expect(find.byType(LibraryScreen), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Porzuć'));
    await tester.pumpAndSettle();
    expect(find.text('trening'), findsOneWidget);
    expect(await result, isNull);
  });

  testWidgets('tryb wyboru: tytuł z planem, numer zaznaczenia, „W planie”', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 1600 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('trening')),
      ),
    );
    navigatorKey.currentState!.push<List<Exercise>>(
      MaterialPageRoute(
        builder: (_) => const PickExerciseScreen(
          title: 'Dodaj do planu',
          subtitle: 'Push A · 1 w planie',
          existingIds: {'1'},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Dodaj do planu'), findsOneWidget);
    expect(find.text('Push A · 1 w planie'), findsOneWidget);

    await tester.tap(find.textContaining('Wszystkie ('));
    await tester.pumpAndSettle();
    expect(find.text('W planie'), findsOneWidget);

    await tester.tap(find.text('Wyciskanie sztangi na ławce'));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
  });
}
