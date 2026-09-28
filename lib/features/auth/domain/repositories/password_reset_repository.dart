/// Wysyłka linku do ustawienia nowego hasła.
abstract interface class PasswordResetRepository {
  /// Czy wiadomości faktycznie wychodzą. `false` — backend nie ma jeszcze
  /// endpointu, a ekran uczciwie o tym informuje.
  bool get isLive;

  /// Prosi o link resetujący dla [email]. Ze względów bezpieczeństwa kończy
  /// się sukcesem także dla adresu bez konta — nie zdradzamy, kto ma konto.
  Future<void> requestReset({required String email});
}
