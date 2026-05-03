import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/models/auth_models.dart';
import '../../features/auth/presentation/screens/login_form_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/training/presentation/screens/activity_type_selection_screen.dart';
import '../../features/training/presentation/screens/training_screen.dart';
import '../../features/activity/presentation/screens/activity_screen.dart';
import '../../features/library/presentation/screens/library_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../services/service_locator.dart';
import 'app_shell.dart';

final appRootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter buildRouter({
  required Future<AuthUser?> Function() resolveUser,
}) {
  return GoRouter(
    navigatorKey: appRootNavigatorKey,
    initialLocation: '/splash',
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
                    path: 'pick-activity-type',
                    builder: (_, s) => const ActivityTypeSelectionScreen(),
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
                  return ProfileScreen(user: user);
                },
              ),
            ],
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
