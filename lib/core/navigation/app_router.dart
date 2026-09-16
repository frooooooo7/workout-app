import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/presentation/account_settings_routes.dart';
import '../../features/auth/domain/models/auth_models.dart';
import '../../features/auth/presentation/screens/login_form_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/training/presentation/screens/activity_type_selection_screen.dart';
import '../../features/training/presentation/screens/ongoing_workout_screen.dart';
import '../../features/training/presentation/screens/pick_training_plan_screen.dart';
import '../../features/training/presentation/screens/training_screen.dart';
import '../../features/training/presentation/screens/create_plan_screen.dart';
import '../../features/training/presentation/screens/edit_workout_screen.dart';
import '../../features/training/presentation/screens/history_screen.dart';
import '../../features/training/presentation/screens/plan_details_screen.dart';
import '../../features/training/presentation/screens/plans_screen.dart';
import '../../features/training/presentation/screens/training_session_details_screen.dart';
import '../../features/training/presentation/screens/training_stats_screen.dart';
import '../../features/training/presentation/screens/workout_summary_screen.dart';
import '../../features/training/presentation/bloc/training_session_cubit.dart';
import '../../features/feed/domain/models/feed_author.dart';
import '../../features/feed/presentation/bloc/feed_cubit.dart';
import '../../features/feed/presentation/bloc/post_comments_cubit.dart';
import '../../features/feed/presentation/bloc/post_details_cubit.dart';
import '../../features/feed/presentation/screens/activity_feed_screen.dart';
import '../../features/feed/presentation/screens/post_details_screen.dart';
import '../../features/library/presentation/screens/library_screen.dart';
import '../../features/library/presentation/screens/pick_exercise_screen.dart';
import '../../features/profile/domain/models/user_profile.dart';
import '../../features/profile/domain/repositories/profile_repository.dart';
import '../../features/profile/presentation/bloc/edit_profile_cubit.dart';
import '../../features/profile/presentation/bloc/follow_cubit.dart';
import '../../features/profile/presentation/bloc/profile_cubit.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/profile/presentation/screens/find_people_screen.dart';
import '../../features/profile/presentation/screens/following_list_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/profile_settings_screen.dart';
import '../../features/profile/presentation/screens/user_profile_screen.dart';
import '../services/service_locator.dart';
import '../theme/app_colors.dart';
import 'app_shell.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final appRootNavigatorKey = GlobalKey<NavigatorState>();

ProfileRepository _profileRepositoryForCurrentUser() {
  return ServiceLocator.profileRepository;
}

/// Ekrany z przyciskiem obserwowania. Udana zmiana prosi własny profil
/// o odświeżenie (licznik obserwowanych) i feed o nowe posty; po powrocie
/// na `/app/profile` ProfileScreen i tak odświeża się sam.
Widget _withFollowCubit(Widget child) {
  return BlocProvider(
    create: (_) => FollowCubit(
      _profileRepositoryForCurrentUser(),
      onFollowChanged: () {
        ServiceLocator.requestProfileRefresh();
        ServiceLocator.requestFeedRefresh();
      },
    ),
    child: child,
  );
}

/// Zalogowany użytkownik jako autor — do optymistycznych kudosów
/// i komentarzy (awatar dociąga się przy odświeżeniu z serwera).
FeedAuthor? _currentFeedAuthor() {
  final user = ServiceLocator.currentUser.value;
  if (user == null) return null;
  return FeedAuthor(
    id: user.id,
    firstName: user.firstName,
    lastName: user.lastName,
  );
}

GoRouter buildRouter({
  required Future<AuthUser?> Function() resolveUser,
  String initialLocation = '/splash',
}) {
  return GoRouter(
    navigatorKey: appRootNavigatorKey,
    initialLocation: initialLocation,
    redirect: (_, state) async {
      final isProtectedRoute = state.uri.path.startsWith('/app/');
      if (!isProtectedRoute || ServiceLocator.currentUser.value != null) {
        return null;
      }

      final user = await resolveUser();
      if (user == null) return '/login';

      ServiceLocator.currentUser.value = user;
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, s) => _SplashRoute(resolveUser: resolveUser),
      ),

      // Auth — unauthenticated zone
      GoRoute(
        path: '/login',
        builder: (_, s) => LoginScreen(notice: ServiceLocator.loginNotice),
        routes: [
          GoRoute(
            path: 'form',
            builder: (_, s) =>
                LoginFormScreen(notice: ServiceLocator.loginNotice),
          ),
          GoRoute(path: 'register', builder: (_, s) => const RegisterScreen()),
        ],
      ),

      // App shell — authenticated zone
      // User is read from ServiceLocator.currentUser (set before navigating here).
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          final user = ServiceLocator.currentUser.value;
          if (user == null) return const _LoadingScreen();
          return BlocProvider(
            create: (_) =>
                TrainingSessionCubit(ServiceLocator.trainingSessionRepository),
            child: AppShell(navigationShell: navigationShell, user: user),
          );
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/history',
                builder: (_, s) => const HistoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/plans',
                builder: (_, s) => const PlansScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/training',
                builder: (_, s) => const TrainingScreen(),
                routes: [
                  GoRoute(
                    parentNavigatorKey: appRootNavigatorKey,
                    name: 'pick-activity-type',
                    path: 'pick-activity-type',
                    builder: (_, s) => const ActivityTypeSelectionScreen(),
                  ),
                  GoRoute(
                    parentNavigatorKey: appRootNavigatorKey,
                    name: 'ongoing-workout',
                    path: 'ongoing-workout',
                    builder: (_, s) {
                      final args = s.extra as OngoingWorkoutArgs?;
                      return OngoingWorkoutScreen(args: args);
                    },
                  ),
                  GoRoute(
                    parentNavigatorKey: appRootNavigatorKey,
                    name: 'workout-summary',
                    path: 'workout-summary',
                    builder: (_, s) {
                      final args = s.extra as WorkoutSummaryArgs?;
                      return WorkoutSummaryScreen(args: args);
                    },
                  ),
                  GoRoute(
                    parentNavigatorKey: appRootNavigatorKey,
                    name: 'pick-training-plan',
                    path: 'pick-plan',
                    builder: (_, s) => const PickTrainingPlanScreen(),
                  ),
                  GoRoute(
                    name: 'training-plans',
                    path: 'plans',
                    redirect: (_, _) => '/app/plans',
                  ),
                  GoRoute(
                    parentNavigatorKey: appRootNavigatorKey,
                    name: 'training-library',
                    path: 'library',
                    builder: (_, s) => const LibraryScreen(),
                  ),
                  GoRoute(
                    parentNavigatorKey: appRootNavigatorKey,
                    name: 'create-plan',
                    path: 'create-plan',
                    builder: (context, state) {
                      final args = state.extra as CreatePlanArgs;
                      return BlocProvider.value(
                        value: args.cubit,
                        child: CreatePlanScreen(
                          existingPlan: args.existingPlan,
                          initialSelectedDays: args.initialSelectedDays,
                        ),
                      );
                    },
                    routes: [
                      GoRoute(
                        parentNavigatorKey: appRootNavigatorKey,
                        name: 'pick-exercise-for-plan',
                        path: 'pick-exercise',
                        builder: (_, s) => const PickExerciseScreen(),
                      ),
                    ],
                  ),
                  GoRoute(
                    parentNavigatorKey: appRootNavigatorKey,
                    name: 'plan-details',
                    path: 'plan-details',
                    builder: (context, state) {
                      final args = state.extra as PlanDetailsArgs;
                      return PlanDetailsScreen(args: args);
                    },
                  ),
                  GoRoute(
                    parentNavigatorKey: appRootNavigatorKey,
                    name: 'training-stats',
                    path: 'stats',
                    builder: (_, s) => const TrainingStatsScreen(),
                  ),
                  GoRoute(
                    parentNavigatorKey: appRootNavigatorKey,
                    name: 'training-session-details',
                    path: 'history/:sessionId',
                    builder: (context, state) {
                      final sessionId = state.pathParameters['sessionId']!;
                      return TrainingSessionDetailsScreen(
                        sessionId: sessionId,
                        repository: ServiceLocator.trainingHistoryRepository,
                        sessionRepository:
                            ServiceLocator.trainingSessionRepository,
                      );
                    },
                    routes: [
                      GoRoute(
                        parentNavigatorKey: appRootNavigatorKey,
                        name: 'training-session-edit',
                        path: 'edit',
                        builder: (context, state) => EditWorkoutScreen(
                          sessionId: state.pathParameters['sessionId']!,
                          repository: ServiceLocator.trainingSessionRepository,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/activity',
                builder: (_, s) {
                  final userId = ServiceLocator.currentUser.value?.id;
                  return _withFollowCubit(
                    BlocProvider(
                      create: (_) => FeedCubit(
                        repository: ServiceLocator.feedRepository,
                        cache: ServiceLocator.feedCache,
                        userId: userId,
                        refreshSignal: ServiceLocator.feedRefreshSignal,
                        events: ServiceLocator.feedPostEvents,
                        currentUser: _currentFeedAuthor(),
                        hiddenPostIds: ServiceLocator.pendingDeletedSessionIds,
                      ),
                      child: ActivityFeedScreen(
                        repository: ServiceLocator.feedRepository,
                        currentUserId: userId,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/profile',
                builder: (_, s) {
                  final user = ServiceLocator.currentUser.value;
                  if (user == null) return const _LoadingScreen();
                  return BlocProvider(
                    create: (_) => ProfileCubit(
                      _profileRepositoryForCurrentUser(),
                      hiddenActivityIds:
                          ServiceLocator.pendingDeletedSessionIds,
                    ),
                    child: const ProfileScreen(),
                  );
                },
                routes: [
                  GoRoute(
                    parentNavigatorKey: appRootNavigatorKey,
                    path: 'settings',
                    builder: (_, s) {
                      final user = ServiceLocator.currentUser.value;
                      if (user == null) return const _LoadingScreen();
                      return ProfileSettingsScreen(
                        user: user,
                        accountRepository: ServiceLocator.accountRepository,
                      );
                    },
                    routes: buildAccountSettingsRoutes(appRootNavigatorKey),
                  ),
                  GoRoute(
                    parentNavigatorKey: appRootNavigatorKey,
                    path: 'edit',
                    builder: (_, s) {
                      final extra = s.extra;
                      return BlocProvider(
                        create: (_) => EditProfileCubit(
                          _profileRepositoryForCurrentUser(),
                          initialProfile: extra is UserProfile ? extra : null,
                          onNamesChanged: (profile) =>
                              ServiceLocator.updateCurrentUserNames(
                                userId: profile.id,
                                firstName: profile.firstName,
                                lastName: profile.lastName,
                              ),
                        ),
                        child: const EditProfileScreen(),
                      );
                    },
                  ),
                  GoRoute(
                    parentNavigatorKey: appRootNavigatorKey,
                    path: 'following',
                    builder: (_, s) => _withFollowCubit(
                      FollowingListScreen(
                        repository: _profileRepositoryForCurrentUser(),
                        currentUserId: ServiceLocator.currentUser.value?.id,
                      ),
                    ),
                  ),
                  GoRoute(
                    parentNavigatorKey: appRootNavigatorKey,
                    path: 'followers',
                    builder: (_, s) => _withFollowCubit(
                      FollowersListScreen(
                        repository: _profileRepositoryForCurrentUser(),
                        currentUserId: ServiceLocator.currentUser.value?.id,
                      ),
                    ),
                  ),
                  GoRoute(
                    parentNavigatorKey: appRootNavigatorKey,
                    path: 'find-people',
                    builder: (_, s) => _withFollowCubit(
                      FindPeopleScreen(
                        repository: _profileRepositoryForCurrentUser(),
                        currentUserId: ServiceLocator.currentUser.value?.id,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // Szczegóły posta w feedzie — poza shellem, żeby działały z każdej
      // zakładki (feed, profil, profil innego użytkownika).
      GoRoute(
        parentNavigatorKey: appRootNavigatorKey,
        path: '/app/posts/:sessionId',
        builder: (_, state) {
          final postId = state.pathParameters['sessionId']!;
          final repository = ServiceLocator.feedRepository;
          return _withFollowCubit(
            MultiBlocProvider(
              providers: [
                BlocProvider(
                  create: (_) => PostDetailsCubit(
                    repository: repository,
                    postId: postId,
                    events: ServiceLocator.feedPostEvents,
                    currentUser: _currentFeedAuthor(),
                  ),
                ),
                BlocProvider(
                  create: (_) => PostCommentsCubit(
                    repository: repository,
                    postId: postId,
                    events: ServiceLocator.feedPostEvents,
                    currentUser: _currentFeedAuthor(),
                  ),
                ),
              ],
              child: PostDetailsScreen(
                postId: postId,
                repository: repository,
                currentUserId: ServiceLocator.currentUser.value?.id,
                focusComment: state.uri.queryParameters['comment'] == '1',
              ),
            ),
          );
        },
      ),

      GoRoute(
        parentNavigatorKey: appRootNavigatorKey,
        path: '/app/users/:userId',
        builder: (_, state) {
          final userId = state.pathParameters['userId']!;
          return _withFollowCubit(
            UserProfileScreen(
              userId: userId,
              repository: _profileRepositoryForCurrentUser(),
              currentUserId: ServiceLocator.currentUser.value?.id,
            ),
          );
        },
        routes: [
          GoRoute(
            parentNavigatorKey: appRootNavigatorKey,
            path: 'following',
            builder: (_, state) => _withFollowCubit(
              FollowingListScreen(
                repository: _profileRepositoryForCurrentUser(),
                userId: state.pathParameters['userId']!,
                currentUserId: ServiceLocator.currentUser.value?.id,
              ),
            ),
          ),
          GoRoute(
            parentNavigatorKey: appRootNavigatorKey,
            path: 'followers',
            builder: (_, state) => _withFollowCubit(
              FollowersListScreen(
                repository: _profileRepositoryForCurrentUser(),
                userId: state.pathParameters['userId']!,
                currentUserId: ServiceLocator.currentUser.value?.id,
              ),
            ),
          ),
        ],
      ),
    ],
  );
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );
  }
}

/// Resolves auth session, sets [ServiceLocator.currentUser], then redirects.
class _SplashRoute extends StatefulWidget {
  const _SplashRoute({required this.resolveUser});

  final Future<AuthUser?> Function() resolveUser;

  @override
  State<_SplashRoute> createState() => _SplashRouteState();
}

class _SplashRouteState extends State<_SplashRoute> {
  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final user = await widget.resolveUser();
    if (!mounted) return;
    if (user != null) {
      ServiceLocator.currentUser.value = user;
      context.go('/app/training');
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );
  }
}
