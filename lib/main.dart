import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:sqflite/sqflite.dart';

import 'core/navigation/app_router.dart';
import 'core/network/api_client.dart';
import 'core/services/service_locator.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/domain/models/auth_models.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }

  ServiceLocator.init();
  await ServiceLocator.seedLibrary();
  runApp(GymApp());
}

class GymApp extends StatelessWidget {
  GymApp({super.key});

  late final _router = buildRouter(resolveUser: _resolveUser);

  /// Offline-first session resolution:
  /// 1. Read cached user from secure storage → render shell immediately.
  /// 2. Verify token in the background via GET /auth/me.
  ///    – 401 → clear session, redirect to login.
  ///    – network error → keep offline session.
  Future<AuthUser?> _resolveUser() async {
    final token = await ServiceLocator.tokenStorage.readToken();
    if (token == null || token.isEmpty) return null;

    // Restore from cache first (offline-first — no network wait on startup)
    final cached = await ServiceLocator.tokenStorage.readUser();
    if (cached != null) {
      // Verify in background after shell is shown
      _verifyInBackground();
      return cached;
    }

    // No cache yet — try network before showing shell
    try {
      final data = await ServiceLocator.apiClient.get('/auth/me', auth: true);
      final user = AuthUser.fromJson(data as Map<String, dynamic>);
      await ServiceLocator.tokenStorage.saveUser(user);
      return user;
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await ServiceLocator.tokenStorage.clear();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _verifyInBackground() async {
    try {
      final data = await ServiceLocator.apiClient.get('/auth/me', auth: true);
      final fresh = AuthUser.fromJson(data as Map<String, dynamic>);
      await ServiceLocator.tokenStorage.saveUser(fresh);
      ServiceLocator.currentUser.value = fresh;
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await ServiceLocator.tokenStorage.clear();
        ServiceLocator.currentUser.value = null;
        _router.go('/login');
      }
    } catch (_) {
      // Network error — keep current session
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Stronger',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: _router,
    );
  }
}
