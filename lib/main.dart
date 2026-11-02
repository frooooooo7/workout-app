import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'core/launch/app_launch_controller.dart';
import 'core/launch/launch_overlay.dart';
import 'core/launch/native_splash_gate.dart';
import 'core/navigation/app_router.dart';
import 'core/services/service_locator.dart';
import 'core/session/app_user_bootstrap.dart';
import 'core/theme/app_localization.dart';
import 'core/theme/app_theme.dart';
import 'core/units/weight_unit.dart';
import 'core/units/weight_unit_scope.dart';

void main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  // Splash systemowy zostaje, dopóki logo ekranu ładowania nie jest gotowe.
  NativeSplashGate.hold(binding);

  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }

  ServiceLocator.init();
  await WeightUnits.load();
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
    _router.routerDelegate.addListener(_onRouteChanged);
  }

  /// Ekrany bez własnego sygnału gotowości (onboarding świeżego konta)
  /// zgłaszają się nakładce ładowania po zbudowaniu.
  void _onRouteChanged() {
    final path = _router.routerDelegate.currentConfiguration.uri.path;
    if (!path.startsWith('/onboarding')) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _launch.attach(LaunchTarget.other);
      _launch.markReady(LaunchTarget.other);
    });
  }

  @override
  void dispose() {
    _router.routerDelegate.removeListener(_onRouteChanged);
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
