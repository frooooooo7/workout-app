import '../domain/repositories/password_reset_repository.dart';

/// Zaślepka do czasu, aż backend dostanie `POST /auth/forgot-password`.
/// Udaje krótkie zapytanie, żeby ekran pokazał pełny przepływ (ładowanie,
/// potwierdzenie, ponowną wysyłkę). Podmiana na prawdziwą implementację
/// to jedna linijka w `ServiceLocator`.
class PlaceholderPasswordResetRepository implements PasswordResetRepository {
  const PlaceholderPasswordResetRepository({
    this.latency = const Duration(milliseconds: 900),
  });

  final Duration latency;

  @override
  bool get isLive => false;

  @override
  Future<void> requestReset({required String email}) =>
      Future<void>.delayed(latency);
}
