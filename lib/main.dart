import 'package:flutter/material.dart';
import 'core/network/api_client.dart';
import 'core/services/service_locator.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/domain/models/auth_models.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/home/presentation/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ServiceLocator.init();
  runApp(const GymApp());
}

class GymApp extends StatelessWidget {
  const GymApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stronger',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const _StartupRouter(),
    );
  }
}

/// Offline-first startup flow:
/// 1. Read token + cached user from secure storage simultaneously.
/// 2. If both present → render HomeScreen immediately (no network wait).
/// 3. Verify token in background via GET /auth/me.
///    – 401 → token revoked/expired → force logout.
///    – network error → keep offline session (user stays on HomeScreen).
/// 4. If no token → LoginScreen.
class _StartupRouter extends StatefulWidget {
  const _StartupRouter();

  @override
  State<_StartupRouter> createState() => _StartupRouterState();
}

class _StartupRouterState extends State<_StartupRouter> {
  AuthUser? _user;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _initSession();
  }

  Future<void> _initSession() async {
    final token = await ServiceLocator.tokenStorage.readToken();

    if (token == null || token.isEmpty) {
      if (mounted) setState(() => _ready = true);
      return;
    }

    // Try to restore session from cache (offline-first — no network round-trip)
    final cachedUser = await ServiceLocator.tokenStorage.readUser();
    if (cachedUser != null && mounted) {
      setState(() {
        _user = cachedUser;
        _ready = true;
      });
    }

    // Verify token in background; update cache if data changed
    _verifyTokenInBackground(token);
  }

  Future<void> _verifyTokenInBackground(String token) async {
    try {
      final data =
          await ServiceLocator.apiClient.get('/auth/me', auth: true);
      final freshUser =
          AuthUser.fromJson(data as Map<String, dynamic>);
      await ServiceLocator.tokenStorage.saveUser(freshUser);

      // Reveal HomeScreen if we had no cached user yet
      if (mounted && !_ready) {
        setState(() {
          _user = freshUser;
          _ready = true;
        });
      }
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        // Token rejected by server — force logout
        await ServiceLocator.tokenStorage.clear();
        if (mounted) {
          setState(() {
            _user = null;
            _ready = true;
          });
          // If already on HomeScreen, navigate back to login
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (_) => false,
          );
        }
      }
      // Network / server error: keep existing session (offline-first)
      if (mounted && !_ready) setState(() => _ready = true);
    } catch (_) {
      if (mounted && !_ready) setState(() => _ready = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        backgroundColor: Color(0xFF0B0B14),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF6C47FF)),
        ),
      );
    }

    final user = _user;
    if (user != null) return HomeScreen(user: user);
    return const LoginScreen();
  }
}
