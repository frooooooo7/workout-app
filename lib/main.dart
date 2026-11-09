import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'core/launch/app_launch_controller.dart';
import 'core/launch/launch_overlay.dart';
import 'core/launch/launch_route_watcher.dart';
import 'core/launch/native_splash_gate.dart';
import 'core/licenses/app_licenses.dart';
import 'core/navigation/app_router.dart';
import 'core/services/service_locator.dart';
import 'core/session/app_user_bootstrap.dart';
import 'core/theme/app_localization.dart';
import 'core/theme/app_theme.dart';
import 'core/units/weight_unit.dart';
import 'core/units/weight_unit_scope.dart';
import 'features/training/data/plate_settings_store.dart';

void main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  // Splash systemowy zostaje, dopóki logo ekranu ładowania nie jest gotowe.
  NativeSplashGate.hold(binding);

  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }

  registerAppLicenses();
  ServiceLocator.init();
  await WeightUnits.load();
  await PlateSettingsStore.load();
  runApp(const GymApp());
  NativeSplashGate.releaseAfter();
}

class GymApp extends StatefulWidget {
  const GymApp({super.key});

  @override
  State<GymApp> createState() => _GymAppState();
}

class _GymAppState extends State<GymApp> {
  late final AppUserBootstrap _bootstrap;
  late final GoRouter _router;
  final AppLaunchController _launch = AppLaunchController();
  late final LaunchRouteWatcher _routeWatcher;

  @override
  void initState() {
    super.initState();
    _bootstrap = AppUserBootstrap(
      onSessionInvalidated: () => _router.go('/login'),
      onAwaitingServer: () => _launch.setAwaitingServer(true),
    );
    _router = buildRouter(resolveUser: _bootstrap.resolveInitialUser);
    // Wymuszone wylogowanie (unieważniony token) i usunięcie konta.
    ServiceLocator.sessionManager.onSessionEnded = () => _router.go('/login');
    _routeWatcher = LaunchRouteWatcher(router: _router, launch: _launch);
  }

  @override
  void dispose() {
    _routeWatcher.dispose();
    _launch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Stronger',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      locale: AppLocalization.locale,
      supportedLocales: AppLocalization.supportedLocales,
      localizationsDelegates: AppLocalization.delegates,
      routerConfig: _router,
      builder: (context, child) => LaunchHost(
        controller: _launch,
        child: WeightUnitScope(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}
