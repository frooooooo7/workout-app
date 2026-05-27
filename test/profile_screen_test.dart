import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/navigation/app_routes.dart';
import 'package:gym/core/services/service_locator.dart';
import 'package:gym/features/auth/domain/models/auth_models.dart';
import 'package:gym/features/home/domain/models/recent_activity.dart';
import 'package:gym/features/profile/domain/models/following_user.dart';
import 'package:gym/features/profile/domain/models/profile_activity.dart';
import 'package:gym/features/profile/domain/models/profile_activity_stat.dart';
import 'package:gym/features/profile/domain/models/profile_stats.dart';
import 'package:gym/features/profile/domain/models/profile_update_input.dart';
import 'package:gym/features/profile/domain/models/user_profile.dart';
import 'package:gym/features/profile/domain/repositories/profile_repository.dart';
import 'package:gym/features/profile/presentation/bloc/profile_cubit.dart';
import 'package:gym/features/profile/presentation/bloc/profile_state.dart';
import 'package:gym/features/profile/presentation/screens/following_list_screen.dart';
import 'package:gym/features/profile/presentation/screens/profile_screen.dart';
import 'package:gym/features/profile/presentation/screens/profile_settings_screen.dart';
import 'package:gym/features/profile/presentation/widgets/following_avatar_strip.dart';
import 'package:gym/features/profile/presentation/widgets/profile_hero_header.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('ProfileScreen renders hero, stats and activity sections', (
    tester,
  ) async {
    const profile = UserProfile(
      id: 'me',
      firstName: 'Jan',
      lastName: 'Kowalski',
      handle: 'jan.kowalski',
      stats: ProfileStats(
        followingCount: 24,
        followersCount: 18,
        workoutsCount: 142,
      ),
      isOwnProfile: true,
    );

    final cubit = _FakeProfileCubit(
      ProfileState(
        profile: profile,
        following: const [
          FollowingUser(
            id: 'u1',
            firstName: 'Anna',
            lastName: 'Nowak',
            handle: 'annanowak',
          ),
        ],
        highlightActivity: const ProfileActivity(
          kind: RecentActivityKind.strength,
          title: 'Trening siłowy',
          date: 'Dziś',
          duration: '58 min',
          detail: '6 ćwiczeń',
          timeLabel: '18:32',
          stats: [
            ProfileActivityStat(label: 'Czas', value: '58 min'),
            ProfileActivityStat(label: 'Ćwiczenia', value: '6 ćwiczeń'),
            ProfileActivityStat(label: 'Objętość', value: '6 450 kg'),
          ],
          kudosCount: 12,
          commentCount: 3,
        ),
        recentActivities: const [
          ProfileActivity(
            kind: RecentActivityKind.run,
            title: 'Bieg poranny',
            date: 'Wczoraj',
            duration: '34 min',
            detail: '5,2 km',
            timeLabel: '07:15',
            stats: [
              ProfileActivityStat(label: 'Czas', value: '34 min'),
              ProfileActivityStat(label: 'Dystans', value: '5,2 km'),
              ProfileActivityStat(label: 'Tempo', value: '6:32 /km'),
            ],
            kudosCount: 7,
          ),
        ],
        loading: false,
      ),
    );

    await tester.binding.setSurfaceSize(const Size(430, 1600));
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<ProfileCubit>.value(
          value: cubit,
          child: const ProfileScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Jan Kowalski'), findsAtLeast(2));
    expect(find.text('@jan.kowalski'), findsOneWidget);
    expect(find.text('Obserwowani'), findsOneWidget);
    expect(find.text('Dodaj opis profilu…'), findsOneWidget);
    expect(find.text('Trening siłowy'), findsAtLeast(1));
    expect(find.text('12'), findsOneWidget);
    expect(find.text('Objętość'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(find.text('Bieg poranny'), findsOneWidget);
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
            onFollowersTap: () {},
            onWorkoutsTap: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Obserwowani'));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('FollowingListScreen shows find people action in app bar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => FollowingListScreen(
                repository: const _FakeProfileRepository(),
              ),
            ),
            GoRoute(
              path: '/app/profile/find-people',
              builder: (context, state) => const Scaffold(
                body: Center(child: Text('Find people')),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Znajdź osoby'), findsOneWidget);
    await tester.tap(find.byTooltip('Znajdź osoby'));
    await tester.pumpAndSettle();

    expect(find.text('Find people'), findsOneWidget);
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

  testWidgets('ProfileSettingsScreen reuses profile returned from edit flow', (
    tester,
  ) async {
    const user = AuthUser(
      id: 'me',
      email: 'jan@example.com',
      firstName: 'Jan',
      lastName: 'Kowalski',
    );
    const initialProfile = UserProfile(
      id: 'me',
      firstName: 'Jan',
      lastName: 'Kowalski',
      handle: 'jan.kowalski',
      stats: ProfileStats(
        followingCount: 0,
        followersCount: 0,
        workoutsCount: 0,
      ),
      isOwnProfile: true,
    );
    const updatedProfile = UserProfile(
      id: 'me',
      firstName: 'Adam',
      lastName: 'Nowak',
      handle: 'adam.nowak',
      stats: ProfileStats(
        followingCount: 0,
        followersCount: 0,
        workoutsCount: 0,
      ),
      isOwnProfile: true,
    );

    ServiceLocator.currentUser.value = user;
    addTearDown(() => ServiceLocator.currentUser.value = null);

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const ProfileSettingsScreen(
            user: user,
            initialProfile: initialProfile,
          ),
        ),
        GoRoute(
          path: AppRoutes.editProfile,
          builder: (context, state) {
            final profile = state.extra as UserProfile?;
            return Scaffold(
              body: Column(
                children: [
                  Text('edit:${profile?.firstName ?? 'none'}'),
                  TextButton(
                    onPressed: () => context.pop(updatedProfile),
                    child: const Text('save fake'),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    await tester.tap(find.text('Edytuj profil'));
    await tester.pumpAndSettle();
    expect(find.text('edit:Jan'), findsOneWidget);

    await tester.tap(find.text('save fake'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edytuj profil'));
    await tester.pumpAndSettle();

    expect(find.text('edit:Adam'), findsOneWidget);
  });
}

class _FakeProfileCubit extends ProfileCubit {
  _FakeProfileCubit(ProfileState initial)
      : super(const _FakeProfileRepository()) {
    emit(initial);
  }

  @override
  Future<void> load() async {}
}

class _FakeProfileRepository implements ProfileRepository {
  const _FakeProfileRepository();

  @override
  Future<List<FollowingUser>> getFollowing({int limit = 20, int offset = 0}) {
    return Future.value(const []);
  }

  @override
  Future<List<FollowingUser>> getFollowers({int limit = 20, int offset = 0}) {
    return Future.value(const []);
  }

  @override
  Future<UserProfile> getOwnProfile() => throw UnimplementedError();

  @override
  Future<List<ProfileActivity>> getRecentActivities({
    int limit = 5,
    String? userId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<UserProfile> getUserProfile(String userId) => throw UnimplementedError();

  @override
  Future<List<FollowingUser>> searchUsers(String query) {
    throw UnimplementedError();
  }

  @override
  Future<UserProfile> updateBio(String bio) async {
    throw UnimplementedError();
  }

  @override
  Future<UserProfile> updateProfile(ProfileUpdateInput input) async {
    throw UnimplementedError();
  }

  @override
  Future<UserProfile> uploadAvatar(Uint8List bytes, String filename) async {
    throw UnimplementedError();
  }
}
