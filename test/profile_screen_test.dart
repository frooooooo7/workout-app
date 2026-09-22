import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/feed/domain/models/cursor_page.dart';
import 'package:gym/features/feed/domain/models/feed_author.dart';
import 'package:gym/features/feed/domain/models/feed_post.dart';
import 'package:gym/features/feed/domain/repositories/feed_repository.dart';
import 'package:gym/features/profile/domain/models/following_user.dart';
import 'package:gym/features/profile/domain/models/profile_stats.dart';
import 'package:gym/features/profile/domain/models/user_profile.dart';
import 'package:gym/features/profile/domain/repositories/profile_repository.dart';
import 'package:gym/features/profile/domain/services/profile_week_calculator.dart';
import 'package:gym/features/profile/presentation/bloc/profile_cubit.dart';
import 'package:gym/features/profile/presentation/bloc/profile_posts_cubit.dart';
import 'package:gym/features/profile/presentation/bloc/profile_state.dart';
import 'package:gym/features/profile/presentation/bloc/profile_week_cubit.dart';
import 'package:gym/features/profile/presentation/screens/profile_screen.dart';
import 'package:gym/features/profile/presentation/widgets/following_avatar_strip.dart';
import 'package:gym/features/profile/presentation/widgets/profile_hero_header.dart';
import 'package:gym/features/training/domain/models/training_session.dart';
import 'package:gym/features/training/domain/models/training_summary_stats.dart';
import 'package:gym/features/training/domain/repositories/training_stats_repository.dart';

const _me = FeedAuthor(id: 'me', firstName: 'Jan', lastName: 'Kowalski');

FeedPost _post(String id, String title, {int kudos = 0}) => FeedPost(
  id: id,
  author: _me,
  title: title,
  startedAt: DateTime(2026, 9, 20, 18),
  durationSec: 3480,
  completedSetsCount: 18,
  totalVolumeKg: 6450,
  kudosCount: kudos,
  isOwn: true,
);

const _profile = UserProfile(
  id: 'me',
  firstName: 'Jan',
  lastName: 'Kowalski',
  handle: 'jan.kowalski',
  stats: ProfileStats(
    followingCount: 24,
    followersCount: 18,
    workoutsCount: 12345,
  ),
  isOwnProfile: true,
);

Future<void> _pumpProfile(
  WidgetTester tester, {
  required ProfileState state,
  List<FeedPost> posts = const [],
  ProfileWeekSummary? week,
}) async {
  final feed = _FeedRepo(posts);
  await tester.binding.setSurfaceSize(const Size(430, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<ProfileCubit>.value(value: _FakeProfileCubit(state)),
          BlocProvider(
            create: (_) => ProfilePostsCubit(repository: feed, userId: 'me'),
          ),
          BlocProvider<ProfileWeekCubit>(create: (_) => _FakeWeekCubit(week)),
        ],
        child: ProfileScreen(feedRepository: feed),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('ProfileScreen renders header, week, following and posts', (
    tester,
  ) async {
    await _pumpProfile(
      tester,
      state: const ProfileState(
        profile: _profile,
        following: [
          FollowingUser(
            id: 'u1',
            firstName: 'Anna',
            lastName: 'Nowak',
            handle: 'annanowak',
          ),
        ],
        loading: false,
      ),
      posts: [
        _post('p1', 'Push — klatka i triceps', kudos: 12),
        _post('p2', 'Pull — plecy i biceps'),
      ],
      week: const ProfileWeekSummary(
        trainedWeekdays: {1, 3},
        stats: TrainingPeriodStats(workouts: 2, durationSec: 6000),
        streakWeeks: 3,
      ),
    );

    expect(find.text('Profil'), findsOneWidget);
    expect(find.text('Jan Kowalski'), findsOneWidget);
    expect(find.text('@jan.kowalski'), findsOneWidget);
    expect(find.text('12,3 tys.'), findsOneWidget);
    expect(find.text('Dodaj opis profilu'), findsOneWidget);
    expect(find.text('Edytuj profil'), findsOneWidget);
    expect(find.text('Ten tydzień'), findsOneWidget);
    expect(find.text('3 tygodnie'), findsOneWidget);
    expect(find.text('Anna'), findsOneWidget);
    expect(find.text('Zobacz wszystkich'), findsOneWidget);
    expect(find.text('Push — klatka i triceps'), findsOneWidget);
    expect(find.text('Pull — plecy i biceps'), findsOneWidget);
    // Oś czasu profilu nie powtarza autora na każdej karcie.
    expect(find.text('Twój trening'), findsNothing);
  });

  testWidgets('empty timeline invites to start a workout', (tester) async {
    await _pumpProfile(
      tester,
      state: const ProfileState(profile: _profile, loading: false),
    );

    expect(find.text('Brak udostępnionych treningów'), findsOneWidget);
    expect(find.text('Rozpocznij trening'), findsOneWidget);
    expect(find.text('Znajdź osoby'), findsOneWidget);
    expect(find.text('Zobacz wszystkich'), findsNothing);
  });

  testWidgets('offline without cached profile shows calm offline view', (
    tester,
  ) async {
    await _pumpProfile(
      tester,
      state: const ProfileState(
        loading: false,
        offline: true,
        error: 'Profil wczyta się, gdy wrócisz online.',
      ),
    );

    expect(find.text('Jesteś offline'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    expect(find.text('Spróbuj ponownie'), findsOneWidget);
  });

  testWidgets('ProfileStatsRow triggers onFollowingTap', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileStatsRow(
            followingCount: 10,
            followersCount: 5,
            workoutsCount: 20,
            onFollowingTap: () => tapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Obserwowani'));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('FollowingAvatarStrip shows empty state CTA', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FollowingAvatarStrip(
            following: const [],
            onFindPeopleTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Znajdź osoby'), findsOneWidget);
    await tester.tap(find.text('Znajdź osoby'));
    await tester.pump();
    expect(tapped, isTrue);
  });
}

class _FakeProfileCubit extends ProfileCubit {
  _FakeProfileCubit(ProfileState initial) : super(_NoOpRepository()) {
    emit(initial);
  }

  @override
  Future<void> load() async {}

  @override
  Future<void> refresh() async {}
}

class _FakeWeekCubit extends ProfileWeekCubit {
  _FakeWeekCubit(ProfileWeekSummary? initial) : super(_NoOpStats()) {
    if (initial != null) emit(initial);
  }

  @override
  Future<void> load() async {}
}

class _NoOpStats implements TrainingStatsRepository {
  @override
  Future<List<TrainingSession>> completedSessionsSince(DateTime from) async =>
      const [];
}

class _NoOpRepository extends Fake implements ProfileRepository {}

class _FeedRepo extends Fake implements FeedRepository {
  _FeedRepo(this.posts);

  final List<FeedPost> posts;

  @override
  Future<FeedPage> getUserPosts(
    String userId, {
    String? cursor,
    int limit = 10,
  }) async => FeedPage(items: posts);
}
