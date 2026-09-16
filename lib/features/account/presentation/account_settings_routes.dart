import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/service_locator.dart';
import 'bloc/change_password_cubit.dart';
import 'bloc/delete_account_cubit.dart';
import 'bloc/notification_settings_cubit.dart';
import 'screens/change_password_screen.dart';
import 'screens/delete_account_screen.dart';
import 'screens/help_screen.dart';
import 'screens/notification_settings_screen.dart';

const kChangePasswordRoute = '/app/profile/settings/change-password';
const kNotificationSettingsRoute = '/app/profile/settings/notifications';
const kHelpRoute = '/app/profile/settings/help';
const kDeleteAccountRoute = '/app/profile/settings/delete-account';

/// Podtrasy `/app/profile/settings/*` (konto i bezpieczeństwo).
List<RouteBase> buildAccountSettingsRoutes(
  GlobalKey<NavigatorState> rootNavigatorKey,
) {
  return [
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: 'change-password',
      builder: (_, _) => BlocProvider(
        create: (_) => ChangePasswordCubit(ServiceLocator.accountRepository),
        child: const ChangePasswordScreen(),
      ),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: 'notifications',
      builder: (_, _) => BlocProvider(
        create: (_) => NotificationSettingsCubit(
          ServiceLocator.restTimerNotificationSettings,
          onRestTimerNotificationsDisabled:
              ServiceLocator.restTimerScheduler.cancelRestFinished,
        ),
        child: const NotificationSettingsScreen(),
      ),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: 'help',
      builder: (_, _) => const HelpScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: 'delete-account',
      builder: (_, _) => BlocProvider(
        create: (_) => DeleteAccountCubit(
          ServiceLocator.accountRepository,
          countUnsyncedChanges: ServiceLocator.countUnsyncedChanges,
        ),
        child: const DeleteAccountScreen(),
      ),
    ),
  ];
}
