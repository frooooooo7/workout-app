import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/navigation/app_router.dart';
import 'package:gym/core/services/service_locator.dart';
import 'package:gym/features/auth/domain/models/auth_models.dart';

void main() {
  Future<void> setDesktopViewport(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    tester.view.devicePixelRatio = 1;
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      tester.view.resetDevicePixelRatio();
    });
  }

  tearDown(() {
    ServiceLocator.currentUser.value = null;
  });

  testWidgets('redirects protected deep links when no session is restored',
      (tester) async {
    await setDesktopViewport(tester);

    var resolveCalls = 0;
    final router = buildRouter(
      initialLocation: '/app/training',
      resolveUser: () async {
        resolveCalls += 1;
        return null;
      },
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(resolveCalls, 1);
    expect(router.routeInformationProvider.value.uri.path, '/login');
  });

  testWidgets('keeps protected deep links after restoring a session',
      (tester) async {
    await setDesktopViewport(tester);

    final user = AuthUser(
      id: 'user-1',
      email: 'test@example.com',
      firstName: 'Test',
      lastName: 'User',
    );

    var resolveCalls = 0;
    final router = buildRouter(
      initialLocation: '/app/activity',
      resolveUser: () async {
        resolveCalls += 1;
        return user;
      },
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(resolveCalls, 1);
    expect(ServiceLocator.currentUser.value, user);
    expect(router.routeInformationProvider.value.uri.path, '/app/activity');
  });
}
