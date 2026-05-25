import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/models/auth_models.dart';
import '../../features/auth/presentation/screens/login_form_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/training/presentation/screens/activity_type_selection_screen.dart';
import '../../features/training/presentation/screens/ongoing_workout_screen.dart';
import '../../features/training/presentation/screens/pick_training_plan_screen.dart';
import '../../features/training/presentation/screens/training_screen.dart';
import '../../features/training/presentation/screens/create_plan_screen.dart';
import '../../features/training/presentation/screens/plan_details_screen.dart';
import '../../features/training/presentation/screens/training_session_details_screen.dart';
import '../../features/training/presentation/screens/training_stats_screen.dart';
import '../../features/activity/presentation/screens/activity_screen.dart';
import '../../features/library/presentation/screens/library_screen.dart';
import '../../features/library/presentation/screens/pick_exercise_screen.dart';
import '../../features/profile/data/mock_profile_repository.dart';
import '../../features/profile/domain/repositories/profile_repository.dart';
import '../../features/profile/presentation/bloc/profile_cubit.dart';
import '../../features/profile/presentation/screens/find_people_screen.dart';
import '../../features/profile/presentation/screens/following_list_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/profile_settings_screen.dart';
import '../../features/profile/presentation/screens/user_profile_screen.dart';
import '../services/service_locator.dart';
import 'app_shell.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final appRootNavigatorKey = GlobalKey<NavigatorState>();

ProfileRepository _profileRepositoryForCurrentUser() {
  final user = ServiceLocator.currentUser.value;
  assert(user != null, 'ProfileRepository requires authenticated user');
  return MockProfileRepository(user: user!);
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
        builder: (_, s) => const LoginScreen(),
        routes: [
          GoRoute(
            path: 'form',
            builder: (_, s) => const LoginFormScreen(),
          ),
          GoRoute(
            path: 'register',
            builder: (_, s) => const RegisterScreen(),
          ),
        ],
      ),

      // App shell — authenticated zone
      // User is read from ServiceLocator.currentUser (set before navigating here).
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          final user = ServiceLocator.currentUser.value;
          if (user == null) return const _LoadingScreen();
          return AppShell(navigationShell: navigationShell, user: user);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/home',
                builder: (_, s) {
                  final user = ServiceLocator.currentUser.value;
                  if (user == null) return const _LoadingScreen();
                  return HomeScreen(user: user);
                },
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
                    name: 'pick-training-plan',
                    path: 'pick-plan',
                    builder: (_, s) => const PickTrainingPlanScreen(),
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
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/activity',
                builder: (_, s) => const ActivityScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/library',
                builder: (_, s) => const LibraryScreen(),
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
                    create: (_) => ProfileCubit(_profileRepositoryForCurrentUser()),
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
                      return ProfileSettingsScreen(user: user);
                    },
                  ),
                  GoRoute(
                    parentNavigatorKey: appRootNavigatorKey,
                    path: 'following',
                    builder: (_, s) => FollowingListScreen(
                      repository: _profileRepositoryForCurrentUser(),
                    ),
                  ),
                  GoRoute(
                    parentNavigatorKey: appRootNavigatorKey,
                    path: 'followers',
                    builder: (_, s) => FollowersListScreen(
                      repository: _profileRepositoryForCurrentUser(),
                    ),
                  ),
                  GoRoute(
                    parentNavigatorKey: appRootNavigatorKey,
                    path: 'find-people',
                    builder: (_, s) => FindPeopleScreen(
                      repository: _profileRepositoryForCurrentUser(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      GoRoute(
        parentNavigatorKey: appRootNavigatorKey,
        path: '/app/users/:userId',
        builder: (_, state) {
          final userId = state.pathParameters['userId']!;
          return UserProfileScreen(
            userId: userId,
            repository: _profileRepositoryForCurrentUser(),
          );
        },
      ),
    ],
  );
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0B0B14),
      body: Center(
        child: CircularProgressIndicator(color: Color(0xFF6C47FF)),
      ),
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
      context.go('/app/home');
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0B0B14),
      body: Center(
        child: CircularProgressIndicator(color: Color(0xFF6C47FF)),
      ),
    );
  }
}
