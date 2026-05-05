import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'core/navigation/app_router.dart';
import 'core/services/service_locator.dart';
import 'core/session/app_user_bootstrap.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }

  ServiceLocator.init();
  runApp(const GymApp());
}

class GymApp extends StatefulWidget {
  const GymApp({super.key});

  @override
  State<GymApp> createState() => _GymAppState();
}

class _GymAppState extends State<GymApp> {
  late final AppUserBootstrap _bootstrap;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _bootstrap = AppUserBootstrap(
      onSessionInvalidated: () => _router.go('/login'),
    );
    _router = buildRouter(
      resolveUser: _bootstrap.resolveInitialUser,
    );
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
