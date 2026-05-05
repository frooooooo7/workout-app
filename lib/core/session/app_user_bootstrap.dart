import '../../features/auth/domain/models/auth_models.dart';
import '../network/api_client.dart';
import '../services/service_locator.dart';

/// Offline-first rozwiązanie użytkownika na starcie + weryfikacja tokenu w tle.
class AppUserBootstrap {
  AppUserBootstrap({required this.onSessionInvalidated});

  final void Function() onSessionInvalidated;

  /// 1. Odczyt tokenu i cache użytkownika → natychmiastowe `currentUser`.
  /// 2. `GET /auth/me` w tle (gdy cache jest) albo na wejściu (bez cache).
  Future<AuthUser?> resolveInitialUser() async {
    final token = await ServiceLocator.tokenStorage.readToken();
    if (token == null || token.isEmpty) return null;

    final cached = await ServiceLocator.tokenStorage.readUser();
    if (cached != null) {
      ServiceLocator.currentUser.value = cached;
      _verifyInBackground();
      return cached;
    }

    try {
      final data = await ServiceLocator.apiClient.get('/auth/me', auth: true);
      final user = AuthUser.fromJson(data as Map<String, dynamic>);
      await ServiceLocator.tokenStorage.saveUser(user);
      ServiceLocator.currentUser.value = user;
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
        onSessionInvalidated();
      }
    } catch (_) {}
  }
}
