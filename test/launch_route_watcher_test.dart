import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gym/core/launch/app_launch_controller.dart';
import 'package:gym/core/launch/launch_overlay.dart';
import 'package:gym/core/launch/launch_route_watcher.dart';

Future<void> _decodeAssets(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 400)),
  );
  await tester.pump();
}

GoRouter _router(String initialLocation) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    for (final path in [
      '/splash',
      '/app/profile',
      '/app/training',
      '/login',
      '/login/form',
    ])
      GoRoute(
        path: path,
        builder: (_, _) => Scaffold(body: Text(path)),
      ),
  ],
);

Future<AppLaunchController> _launch(
  WidgetTester tester,
  String initialLocation,
) async {
  final launch = AppLaunchController();
  addTearDown(launch.dispose);
  final router = _router(initialLocation);
  addTearDown(router.dispose);
  final watcher = LaunchRouteWatcher(router: router, launch: launch);
  addTearDown(watcher.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      builder: (context, child) =>
          LaunchHost(controller: launch, child: child!),
    ),
  );
  await _decodeAssets(tester);
  return launch;
}

void main() {
  test('sygnał własny mają /splash, logowanie i Trening z podstronami', () {
    expect(LaunchRouteWatcher.hasOwnSignal('/splash'), isTrue);
    expect(LaunchRouteWatcher.hasOwnSignal('/login'), isTrue);
    expect(LaunchRouteWatcher.hasOwnSignal('/app/training'), isTrue);
    expect(LaunchRouteWatcher.hasOwnSignal('/app/training/library'), isTrue);
    expect(LaunchRouteWatcher.hasOwnSignal('/app/profile'), isFalse);
    expect(LaunchRouteWatcher.hasOwnSignal('/app/history'), isFalse);
    expect(LaunchRouteWatcher.hasOwnSignal('/pro/welcome'), isFalse);
    expect(LaunchRouteWatcher.hasOwnSignal('/login/form'), isFalse);
  });

  testWidgets('web: F5 na /app/profile nie trzyma nakładki do limitu', (
    tester,
  ) async {
    final launch = await _launch(tester, '/app/profile');

    await tester.pump(const Duration(milliseconds: 860));
    expect(launch.phase, LaunchPhase.exiting);
    await tester.pump(const Duration(seconds: 1));
    expect(launch.phase, LaunchPhase.done);
  });

  testWidgets('F5 na /login/form: zwykłe wyjście, logo nie leci do karty', (
    tester,
  ) async {
    final launch = await _launch(tester, '/login/form');
    // Ekran logowania zgłasza się po swojemu, ale router ma pierwszeństwo.
    launch.markReady(LaunchTarget.login);

    await tester.pump(const Duration(milliseconds: 860));
    expect(launch.phase, LaunchPhase.exiting);
    expect(launch.target, LaunchTarget.other);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('start przez /splash nie zgłasza się sam (czeka na ekran)', (
    tester,
  ) async {
    final launch = await _launch(tester, '/splash');

    await tester.pump(const Duration(milliseconds: 1500));
    expect(launch.phase, LaunchPhase.intro);
    // Dopiero limit całego startu go kończy.
    await tester.pump(const Duration(seconds: 19));
    expect(launch.phase, LaunchPhase.exiting);
    await tester.pump(const Duration(seconds: 1));
  });
}
