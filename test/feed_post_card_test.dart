import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/feed/domain/models/feed_author.dart';
import 'package:gym/features/feed/domain/models/feed_post.dart';
import 'package:gym/features/feed/presentation/utils/feed_formatters.dart';
import 'package:gym/features/feed/presentation/widgets/feed_empty_state.dart';
import 'package:gym/features/feed/presentation/widgets/feed_people_strip.dart';
import 'package:gym/features/feed/presentation/widgets/feed_post_card.dart';
import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:gym/features/profile/domain/models/following_user.dart';
import 'package:gym/features/profile/domain/repositories/profile_repository.dart';
import 'package:gym/features/profile/presentation/bloc/follow_cubit.dart';
import 'package:gym/features/training/domain/models/training_history_models.dart';
import 'package:gym/features/training/domain/models/training_stats.dart';

class _NoOpProfileRepository extends Fake implements ProfileRepository {}

FeedPost _post({
  bool isOwn = false,
  bool hasKudoed = false,
  int kudos = 3,
  int comments = 1,
  List<PersonalRecord> personalRecords = const [],
}) {
  return FeedPost(
    id: 'p1',
    author: const FeedAuthor(id: 'u1', firstName: 'Anna', lastName: 'Nowak'),
    title: 'Push A',
    note: 'Nowy rekord na ławce',
    startedAt: DateTime(2026, 9, 15, 18, 5),
    durationSec: 3420,
    exercisesCount: 6,
    completedSetsCount: 18,
    totalVolumeKg: 5230.5,
    muscles: const [MuscleGroup.chest, MuscleGroup.triceps],
    topExercises: const [
      TopExercise(
        name: 'Wyciskanie sztangi na ławce',
        completedSets: 4,
        bestSet: TrainingSetMetrics(weightKg: 82.5, reps: 8),
      ),
    ],
    personalRecords: personalRecords,
    kudosCount: kudos,
    commentCount: comments,
    hasKudoed: hasKudoed,
    isOwn: isOwn,
    recentKudos: const [
      FeedAuthor(id: 'u2', firstName: 'Ola', lastName: 'Lis'),
    ],
  );
}

Future<void> _pumpCard(
  WidgetTester tester,
  FeedPost post, {
  VoidCallback? onKudosTap,
  VoidCallback? onKudosListTap,
  VoidCallback? onCommentTap,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: FeedPostCard(
            post: post,
            now: DateTime(2026, 9, 15, 20),
            onKudosTap: onKudosTap,
            onKudosListTap: onKudosListTap,
            onCommentTap: onCommentTap,
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('formatters', () {
    final now = DateTime(2026, 9, 15, 20);

    test('relative Polish timestamps', () {
      expect(
        formatFeedTimestamp(DateTime(2026, 9, 15, 18, 5), now: now),
        'Dziś, 18:05',
      );
      expect(
        formatFeedTimestamp(DateTime(2026, 9, 14, 7, 30), now: now),
        'Wczoraj, 07:30',
      );
      expect(
        formatFeedTimestamp(DateTime(2026, 9, 12, 18, 5), now: now),
        '12 wrz, 18:05',
      );
      expect(
        formatFeedTimestamp(DateTime(2025, 12, 31, 9, 0), now: now),
        '31 gru 2025, 09:00',
      );
    });

    test('best set picks strongest weighted set and Polish plurals', () {
      const bench = TopExercise(
        name: 'Wyciskanie',
        completedSets: 4,
        bestSet: TrainingSetMetrics(weightKg: 82.5, reps: 8),
      );
      const squat = TopExercise(
        name: 'Przysiad',
        completedSets: 4,
        bestSet: TrainingSetMetrics(weightKg: 100, reps: 3),
      );
      const pushUps = TopExercise(
        name: 'Pompki',
        completedSets: 5,
        bestSet: TrainingSetMetrics(reps: 40),
      );
      // 82,5×(1+8/30)=104,5 < 100×(1+3/30)=110.
      expect(pickBestSetExercise(const [bench, squat, pushUps]), squat);
      expect(pickBestSetExercise(const [pushUps]), isNull);
      expect(pickBestSetExercise(const []), isNull);
      expect(formatKudosCount(1), '1 kudos');
      expect(formatKudosCount(3), '3 kudosy');
      expect(formatKudosCount(12), '12 kudosów');
    });
  });

  group('FeedPostCard', () {
    testWidgets('renders post content for another user and toggles kudos',
        (tester) async {
      var kudosTaps = 0;
      var listTaps = 0;
      var commentTaps = 0;
      await _pumpCard(
        tester,
        _post(),
        onKudosTap: () => kudosTaps++,
        onKudosListTap: () => listTaps++,
        onCommentTap: () => commentTaps++,
      );

      expect(find.text('Anna Nowak'), findsOneWidget);
      expect(find.text('Dziś, 18:05'), findsOneWidget);
      expect(find.text('Push A'), findsOneWidget);
      expect(find.text('Nowy rekord na ławce'), findsOneWidget);
      expect(find.text('57 min'), findsOneWidget);
      expect(find.text('5,23 t'), findsOneWidget);
      expect(find.text('18'), findsOneWidget);
      expect(find.text('NAJLEPSZA SERIA'), findsOneWidget);
      expect(find.text('Wyciskanie sztangi na ławce'), findsOneWidget);
      expect(find.text('82,5 kg × 8'), findsOneWidget);
      expect(find.text('Klatka'), findsOneWidget);
      expect(find.text('3 kudosy'), findsOneWidget);
      expect(find.text('1 komentarz'), findsOneWidget);

      final kudosButton = find.byKey(const ValueKey('feed-kudos-button-p1'));
      expect(kudosButton, findsOneWidget);
      expect(find.text('Kudos'), findsOneWidget);
      expect(find.byIcon(Icons.thumb_up_alt_outlined), findsOneWidget);

      await tester.tap(kudosButton);
      await tester.tap(find.byKey(const ValueKey('feed-kudos-summary-p1')));
      await tester.tap(find.byKey(const ValueKey('feed-comment-button-p1')));

      expect(kudosTaps, 1);
      expect(listTaps, 1);
      expect(commentTaps, 1);
    });

    testWidgets('shows filled kudos state when already kudoed', (tester) async {
      await _pumpCard(tester, _post(hasKudoed: true));

      expect(find.text('Dano kudosa'), findsOneWidget);
      expect(find.byIcon(Icons.thumb_up_alt_rounded), findsOneWidget);
    });

    testWidgets('own post has no kudos button but keeps comments',
        (tester) async {
      await _pumpCard(tester, _post(isOwn: true, kudos: 0, comments: 0));

      expect(find.byKey(const ValueKey('feed-kudos-button-p1')), findsNothing);
      expect(
        find.byKey(const ValueKey('feed-comment-button-p1')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('feed-kudos-summary-p1')), findsNothing);
    });

    testWidgets('new records replace the best set and collapse past two', (
      tester,
    ) async {
      PersonalRecord record(String name, double kg, double improvement) =>
          PersonalRecord(
            exerciseKey: 'name:${name.toLowerCase()}',
            exerciseName: name,
            exerciseId: '',
            sessionId: 'p1',
            date: DateTime(2026, 9, 15, 18, 5),
            kinds: const {PersonalRecordKind.weight},
            weightKg: kg,
            reps: 5,
            improvement: improvement,
          );
      await _pumpCard(
        tester,
        _post(
          personalRecords: [
            record('Wyciskanie sztangi na ławce', 85, 2.5),
            record('Przysiad', 120, 5),
            record('Martwy ciąg', 150, 10),
          ],
        ),
      );

      expect(find.text('3 nowe rekordy!'), findsOneWidget);
      expect(find.text('Wyciskanie sztangi na ławce'), findsOneWidget);
      expect(find.text('85 kg × 5'), findsOneWidget);
      expect(find.text('+2,5 kg'), findsOneWidget);
      expect(find.text('Przysiad'), findsOneWidget);
      expect(find.text('Martwy ciąg'), findsNothing);
      expect(find.text('i jeszcze 1'), findsOneWidget);
      expect(find.text('NAJLEPSZA SERIA'), findsNothing);
    });

    testWidgets('a single record reads "Nowy rekord!"', (tester) async {
      await _pumpCard(
        tester,
        _post(
          personalRecords: [
            PersonalRecord(
              exerciseKey: 'name:pompki',
              exerciseName: 'Pompki',
              exerciseId: '',
              sessionId: 'p1',
              date: DateTime(2026, 9, 15, 18, 5),
              kinds: const {PersonalRecordKind.reps},
              reps: 40,
              improvement: 4,
            ),
          ],
        ),
      );

      expect(find.text('Nowy rekord!'), findsOneWidget);
      expect(find.text('40 powt.'), findsOneWidget);
      expect(find.text('+4 powt.'), findsOneWidget);
    });
  });

  testWidgets('empty state shows explanation and suggested users',
      (tester) async {
    var findFriendsTaps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider(
            create: (_) => FollowCubit(_NoOpProfileRepository()),
            child: SingleChildScrollView(
              child: FeedEmptyState(
                currentUserId: 'me',
                suggestionsLoading: false,
                onFindFriends: () => findFriendsTaps++,
                suggestions: const [
                  FollowingUser(
                    id: 'u1',
                    firstName: 'Ola',
                    lastName: 'Lis',
                    handle: 'ola',
                  ),
                  FollowingUser(
                    id: 'me',
                    firstName: 'Jan',
                    lastName: 'Kowalski',
                    handle: 'jan',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Twój feed jest pusty'), findsOneWidget);
    expect(find.text('PROPONOWANE OSOBY'), findsOneWidget);
    expect(find.text('Ola Lis'), findsOneWidget);
    expect(find.text('Jan Kowalski'), findsNothing);
    expect(find.text('Obserwuj'), findsOneWidget);

    await tester.tap(find.text('Znajdź znajomych'));
    expect(findFriendsTaps, 1);
  });

  testWidgets('people strip lists distinct other authors after find tile',
      (tester) async {
    var findTaps = 0;
    final tapped = <String>[];
    FeedPost post(String id, String authorId, String name, {bool own = false}) =>
        FeedPost(
          id: id,
          author: FeedAuthor(id: authorId, firstName: name, lastName: 'X'),
          title: 'T',
          startedAt: DateTime(2026, 9, 15, 10),
          isOwn: own,
        );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FeedPeopleStrip(
            now: DateTime(2026, 9, 15, 20),
            posts: [
              post('p1', 'me', 'Ja', own: true),
              post('p2', 'u1', 'Ola'),
              post('p3', 'u1', 'Ola'),
              post('p4', 'u2', 'Piotr'),
            ],
            onFindPeople: () => findTaps++,
            onAuthorTap: (author) => tapped.add(author.id),
          ),
        ),
      ),
    );

    expect(find.text('Znajdź'), findsOneWidget);
    expect(find.text('Ja'), findsNothing);
    expect(find.text('Ola'), findsOneWidget);
    expect(find.text('Piotr'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('feed-strip-find-people')));
    await tester.tap(find.text('Piotr'));
    expect(findTaps, 1);
    expect(tapped, ['u2']);
  });
}
