import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'app_launch_controller.dart';

/// Zgłasza ekranowi ładowania ekrany, które nie mają własnego sygnału
/// gotowości (onboarding, a na webie także każdy adres wpisany w pasku, np.
/// `#/app/profile`, bo router startuje wtedy od niego, z pominięciem
/// `/splash`). Bez tego nakładka wisiałaby do limitu całego startu.
class LaunchRouteWatcher {
  LaunchRouteWatcher({required this.router, required this.launch}) {
    router.routerDelegate.addListener(_onRouteChanged);
  }

  final GoRouter router;
  final AppLaunchController launch;

  /// Czy ekran pod tą ścieżką sam zgłasza gotowość nakładce: `/splash`
  /// (dalej przechodzi do Treningu albo logowania), logowanie i Trening
  /// (także jego podstrony, bo zakładka jest pod nimi zbudowana).
  /// Podstrony logowania (`/login/form`) zasłaniają kartę powitalną, więc
  /// ich nie ma na liście: logo nie ma lecieć do ukrytej karty.
  static bool hasOwnSignal(String path) =>
      path == '/splash' || path == '/login' || path.startsWith('/app/training');

  void _onRouteChanged() {
    final path = router.routerDelegate.currentConfiguration.uri.path;
    // Pusta ścieżka: router jeszcze nie ustawił pierwszej trasy.
    if (path.isEmpty || hasOwnSignal(path)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      launch.attach(LaunchTarget.other);
      launch.markReady(LaunchTarget.other, force: true);
    });
  }

  void dispose() => router.routerDelegate.removeListener(_onRouteChanged);
}
