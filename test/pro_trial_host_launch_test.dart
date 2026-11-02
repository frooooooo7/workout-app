import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gym/core/launch/app_launch_controller.dart';
import 'package:gym/core/launch/launch_overlay.dart';
import 'package:gym/core/services/service_locator.dart';
import 'package:gym/features/auth/domain/models/auth_models.dart';
import 'package:gym/features/pro/data/pro_trial_seen_store.dart';
import 'package:gym/features/pro/presentation/widgets/pro_trial_host.dart';

class _MemoryStore implements ProTrialSeenStore {
  final seen = <String>{};

  @override
  Future<bool> welcomeSeen(String userId) async => seen.contains('w$userId');

  @override
  Future<void> markWelcomeSeen(String userId) async => seen.add('w$userId');

  @override
  Future<bool> endSeen(String userId) async => seen.contains('e$userId');

  @override
  Future<void> markEndSeen(String userId) async => seen.add('e$userId');
}

void main() {
  tearDown(() => ServiceLocator.currentUser.value = null);

  testWidgets('powitanie PRO czeka, aż ekran ładowania zniknie', (
    tester,
  ) async {
    final now = DateTime(2026, 11, 2, 12);
    ServiceLocator.currentUser.value = AuthUser(
      id: 'u1',
      email: 'a@b.pl',
      firstName: 'Damian',
      lastName: 'T',
      createdAt: now,
    );
    final launch = AppLaunchController();
    addTearDown(launch.dispose);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: ProTrialHost(store: _MemoryStore(), clock: () => now),
          ),
        ),
        GoRoute(
          path: '/pro/welcome',
          builder: (_, _) => const Text('Powitanie PRO'),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        builder: (context, child) =>
            LaunchHost(controller: launch, child: child!),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await tester.pump();

    // Pod nakładką ekranu PRO jeszcze nie ma.
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Powitanie PRO'), findsNothing);

    // Dopiero po znikaniu nakładki trafia na ekran.
    launch.markReady(LaunchTarget.other);
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('Powitanie PRO'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Powitanie PRO'), findsOneWidget);
  });
}
