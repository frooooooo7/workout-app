import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/auth/domain/models/auth_models.dart';
import 'package:gym/features/training/domain/models/custom_training_plan.dart';
import 'package:gym/features/training/domain/models/post_draft.dart';
import 'package:gym/features/training/domain/models/training_session.dart';
import 'package:gym/features/training/domain/repositories/training_session_repository.dart';
import 'package:gym/features/training/domain/repositories/training_stats_repository.dart';
import 'package:gym/features/training/presentation/screens/workout_summary_screen.dart';
import 'package:gym/features/training/presentation/widgets/workout_summary/share_workout_sheet.dart';
import 'package:gym/features/training/presentation/widgets/workout_summary/workout_share_card.dart';

void main() {
  const user = AuthUser(
    id: 'u1',
    email: 'jan@gym.com',
    firstName: 'Jan',
    lastName: 'Kowalski',
  );

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  Widget buildScreen(
    _FakeTrainingSessionRepository repository, {
    List<TrainingSession> history = const [],
    PostPhotoPicker? pickPhoto,
  }) {
    return MaterialApp(
      home: WorkoutSummaryScreen(
        args: WorkoutSummaryArgs(
          session: repository.session,
          repository: repository,
          statsRepository: _FakeStatsRepository(history),
          user: user,
          pickPhoto: pickPhoto,
        ),
      ),
    );
  }

  /// Otwiera arkusz „Udostępnij trening” z karty w podsumowaniu.
  Future<void> openShareSheet(WidgetTester tester) async {
    final shareButton = find.byKey(const ValueKey('workout-share-button'));
    await scrollTo(tester, shareButton);
    await tester.tap(shareButton);
    await tester.pumpAndSettle();
    expect(find.text('Udostępnij trening'), findsOneWidget);
  }

  Future<void> publish(WidgetTester tester) async {
    final button = find.byKey(const ValueKey('share-sheet-publish'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('shows completion hero and session metrics', (tester) async {
    final repository = _FakeTrainingSessionRepository(_completedSession());

    await tester.pumpWidget(buildScreen(repository));
    await tester.pumpAndSettle();

    expect(find.text('Trening ukończony!'), findsOneWidget);
    expect(find.textContaining('Push'), findsOneWidget);
    // 45 minut treningu.
    expect(find.text('45:00'), findsOneWidget);
    // 60×8 + 62,5×8 = 980 kg (nieukończona seria nie liczy się) — w karcie
    // statystyk i w wyróżnieniu największej objętości.
    expect(find.text('980 kg'), findsNWidgets(2));
    expect(find.text('Ukończone serie'), findsOneWidget);
    expect(find.text('2'), findsWidgets);
    expect(find.text('Ukończono 2 z 3 serii'), findsOneWidget);
    expect(find.text('67%'), findsOneWidget);
  });

  testWidgets('highlights the heaviest set and top-volume exercise', (
    tester,
  ) async {
    final repository = _FakeTrainingSessionRepository(_completedSession());

    await tester.pumpWidget(buildScreen(repository));
    await tester.pumpAndSettle();

    final heaviest = find.byKey(const ValueKey('summary-highlight-heaviest'));
    expect(
      find.descendant(of: heaviest, matching: find.text('62,5 kg × 8')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: heaviest, matching: find.text('Bench press')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('summary-highlight-volume')),
      findsOneWidget,
    );
  });

  testWidgets('shows "Nowy rekord!" when the workout beats earlier bests', (
    tester,
  ) async {
    final current = _completedSession();
    // Tydzień wcześniej: 60 kg × 8 — dziś 62,5 kg × 8 bije rekord ciężaru.
    final earlier = _benchSession(
      DateTime.utc(2026, 9, 6, 15),
      weight: '60',
      reps: '8',
    );
    final repository = _FakeTrainingSessionRepository(current);

    await tester.pumpWidget(
      buildScreen(repository, history: [earlier, current]),
    );
    await tester.pumpAndSettle();

    final banner = find.byKey(const ValueKey('new-records-banner'));
    expect(banner, findsOneWidget);
    expect(
      find.descendant(of: banner, matching: find.text('Nowy rekord!')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: banner, matching: find.text('Bench press')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: banner, matching: find.text('62,5 kg × 8')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: banner, matching: find.text('+2,5 kg')),
      findsOneWidget,
    );
  });

  testWidgets('no record banner without a better result or earlier history', (
    tester,
  ) async {
    final repository = _FakeTrainingSessionRepository(_completedSession());

    // Pierwsze wykonanie ćwiczenia ustala punkt odniesienia — to nie rekord.
    await tester.pumpWidget(buildScreen(repository));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('new-records-banner')), findsNothing);

    // Wcześniej było ciężej — dziś bez rekordu.
    await tester.pumpWidget(
      buildScreen(
        repository,
        history: [
          _benchSession(DateTime.utc(2026, 9, 6, 15), weight: '70', reps: '8'),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('new-records-banner')), findsNothing);
  });

  testWidgets(
    'share sheet publishes title and body and the card previews the post',
    (tester) async {
      final repository = _FakeTrainingSessionRepository(_completedSession());

      await tester.pumpWidget(buildScreen(repository));
      await tester.pumpAndSettle();
      await openShareSheet(tester);
      await tester.enterText(
        find.byKey(const ValueKey('share-sheet-title')),
        '  Nowy rekord  ',
      );
      await tester.enterText(
        find.byKey(const ValueKey('share-sheet-body')),
        'W końcu 120 kg na 5!',
      );
      await publish(tester);

      final draft = repository.postDrafts.single;
      expect(draft.cleanTitle, 'Nowy rekord');
      expect(draft.cleanBody, 'W końcu 120 kg na 5!');
      expect(draft.photo, isA<KeepPostPhoto>());
      expect(repository.session.sharedToProfile, isTrue);

      await scrollTo(
        tester,
        find.byKey(const ValueKey('workout-share-post-preview')),
      );
      expect(find.text('Udostępniono na profilu'), findsOneWidget);
      expect(find.text('Nowy rekord'), findsOneWidget);
      expect(find.text('W końcu 120 kg na 5!'), findsOneWidget);
      expect(find.byKey(const ValueKey('workout-share-button')), findsNothing);

      await tester.tap(find.text('Cofnij'));
      await tester.pumpAndSettle();

      expect(repository.sharedCalls.last, (repository.session.id, false));
      expect(repository.session.sharedToProfile, isFalse);
      expect(
        find.byKey(const ValueKey('workout-share-button')),
        findsOneWidget,
      );
    },
  );

  testWidgets('empty sheet publishes with the workout name as the title', (
    tester,
  ) async {
    final repository = _FakeTrainingSessionRepository(_completedSession());

    await tester.pumpWidget(buildScreen(repository));
    await tester.pumpAndSettle();
    await openShareSheet(tester);
    await publish(tester);

    final draft = repository.postDrafts.single;
    expect(draft.cleanTitle, isNull);
    expect(draft.cleanBody, isNull);
    expect(repository.session.sharedToProfile, isTrue);
    await scrollTo(
      tester,
      find.byKey(const ValueKey('workout-share-post-preview')),
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('workout-share-post-preview')),
        matching: find.text(repository.session.planName),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a picked photo goes into the draft and can be edited later', (
    tester,
  ) async {
    final repository = _FakeTrainingSessionRepository(_completedSession());
    final photo = PickedPostPhoto(
      bytes: Uint8List.fromList(_onePixelPng),
      filename: 'gym.png',
    );

    await tester.pumpWidget(
      buildScreen(repository, pickPhoto: (context, source) async => photo),
    );
    await tester.pumpAndSettle();
    await openShareSheet(tester);

    await tester.tap(find.byKey(const ValueKey('share-sheet-gallery')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('share-sheet-photo')), findsOneWidget);

    await publish(tester);
    final draft = repository.postDrafts.single;
    expect(draft.photo, isA<SetPostPhoto>());
    expect((draft.photo as SetPostPhoto).photo.filename, 'gym.png');

    // Edycja: zdjęcie i tytuł są już w arkuszu, usunięcie zdjęcia trafia do
    // kolejnego szkicu.
    final edit = find.byKey(const ValueKey('workout-share-edit'));
    await scrollTo(tester, edit);
    await tester.tap(edit);
    await tester.pumpAndSettle();
    expect(find.text('Edytuj post'), findsWidgets);
    expect(find.byKey(const ValueKey('share-sheet-photo')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('share-sheet-remove-photo')));
    await tester.pumpAndSettle();
    await publish(tester);

    expect(repository.postDrafts, hasLength(2));
    expect(repository.postDrafts.last.photo, isA<RemovePostPhoto>());
  });

  testWidgets('starts in shared state when session is already shared', (
    tester,
  ) async {
    final repository = _FakeTrainingSessionRepository(
      _completedSession().copyWith(sharedToProfile: true),
    );

    await tester.pumpWidget(buildScreen(repository));
    await tester.pumpAndSettle();

    await scrollTo(tester, find.byType(WorkoutShareCard));

    expect(find.text('Udostępniono na profilu'), findsOneWidget);
    expect(find.byKey(const ValueKey('workout-share-button')), findsNothing);
  });

  testWidgets('reverts card state and shows snackbar when saving fails', (
    tester,
  ) async {
    final repository = _FakeTrainingSessionRepository(
      _completedSession(),
      failShare: true,
    );

    await tester.pumpWidget(buildScreen(repository));
    await tester.pumpAndSettle();

    await openShareSheet(tester);
    await publish(tester);

    expect(
      find.text('Nie udało się udostępnić. Spróbuj ponownie.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('workout-share-button')), findsOneWidget);
    expect(repository.session.sharedToProfile, isFalse);
  });

  testWidgets('done button leaves the summary', (tester) async {
    final repository = _FakeTrainingSessionRepository(_completedSession());

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => WorkoutSummaryScreen(
                      args: WorkoutSummaryArgs(
                        session: repository.session,
                        repository: repository,
                        user: user,
                      ),
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(WorkoutSummaryScreen), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('workout-summary-done-button')));
    await tester.pumpAndSettle();

    expect(find.byType(WorkoutSummaryScreen), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });
}

TrainingSession _completedSession() {
  final startedAt = DateTime.utc(2026, 9, 13, 15, 0);
  return TrainingSession(
    planName: 'Push',
    status: TrainingSessionStatus.completed,
    startedAt: startedAt,
    finishedAt: startedAt.add(const Duration(minutes: 45)),
    exercises: [
      TrainingSessionExercise(
        exerciseId: 'bench',
        exerciseName: 'Bench press',
        exerciseMuscles: const ['chest', 'triceps'],
        exerciseCategory: 'compound',
        sets: [
          TrainingSessionSet(
            plannedWeight: '60',
            plannedReps: '8',
            actualWeight: '60',
            actualReps: '8',
            completed: true,
            completedAt: startedAt.add(const Duration(minutes: 5)),
          ),
          TrainingSessionSet(
            plannedWeight: '60',
            plannedReps: '8',
            actualWeight: '62,5',
            actualReps: '8',
            completed: true,
            completedAt: startedAt.add(const Duration(minutes: 9)),
          ),
          TrainingSessionSet(
            plannedWeight: '60',
            plannedReps: '8',
            actualWeight: '65',
            actualReps: '6',
          ),
        ],
      ),
    ],
  );
}

TrainingSession _benchSession(
  DateTime startedAt, {
  required String weight,
  required String reps,
}) {
  return TrainingSession(
    planName: 'Push',
    status: TrainingSessionStatus.completed,
    startedAt: startedAt,
    finishedAt: startedAt.add(const Duration(minutes: 40)),
    exercises: [
      TrainingSessionExercise(
        exerciseId: 'bench',
        exerciseName: 'Bench press',
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
}

class _FakeStatsRepository implements TrainingStatsRepository {
  _FakeStatsRepository(this.sessions);

  final List<TrainingSession> sessions;

  @override
  Future<List<TrainingSession>> allCompletedSessions() async => sessions;

  @override
  Future<List<TrainingSession>> completedSessionsSince(DateTime from) async => [
    for (final s in sessions)
      if (!s.startedAt.isBefore(from)) s,
  ];
}

class _FakeTrainingSessionRepository implements TrainingSessionRepository {
  _FakeTrainingSessionRepository(this.session, {this.failShare = false});

  TrainingSession session;
  final bool failShare;
  final List<(String, bool)> sharedCalls = [];

  @override
  Future<TrainingSession?> getActive() async => null;

  @override
  Future<TrainingSession?> getById(String sessionId) async =>
      session.id == sessionId || session.serverId == sessionId ? session : null;

  @override
  Future<TrainingSession> startFromPlan(CustomTrainingPlan plan) {
    throw UnimplementedError();
  }

  @override
  Future<TrainingSession> startCustom({
    String planName = TrainingSession.defaultCustomName,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<TrainingSession> save(TrainingSession session) async => session;

  @override
  Future<TrainingSession> finish(String sessionId) async => session;

  @override
  Future<TrainingSession> cancel(String sessionId) async => session;

  @override
  Future<TrainingSession> setSharedToProfile(
    String sessionId,
    bool shared,
  ) async {
    sharedCalls.add((sessionId, shared));
    if (failShare) throw StateError('offline');
    session = session.copyWith(sharedToProfile: shared);
    return session;
  }

  @override
  Future<TrainingSession> startFromSession(TrainingSession source) {
    throw UnimplementedError();
  }

  @override
  Future<TrainingSession?> loadForEdit(String sessionId) async => null;

  @override
  Future<void> delete(String sessionId) async {}

  final List<PostDraft> postDrafts = [];

  @override
  Future<TrainingSession> sharePost(String sessionId, PostDraft draft) async {
    postDrafts.add(draft);
    if (failShare) throw StateError('offline');
    session = session.copyWith(
      sharedToProfile: true,
      postTitle: draft.cleanTitle,
      clearPostTitle: draft.cleanTitle == null,
      note: draft.cleanBody,
      clearNote: draft.cleanBody == null,
    );
    return session;
  }

  @override
  Future<Uint8List?> pendingPostPhoto(String sessionId) async => null;
}

/// Najmniejszy poprawny PNG (1×1) — podgląd zdjęcia w arkuszu.
const _onePixelPng = <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0xF8,
  0xCF,
  0xC0,
  0xF0,
  0x1F,
  0x00,
  0x05,
  0x00,
  0x01,
  0xFF,
  0x89,
  0x99,
  0x3D,
  0x1D,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];
