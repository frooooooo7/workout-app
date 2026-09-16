/// Czy planować systemowe powiadomienie o końcu przerwy. Timer w aplikacji
/// działa niezależnie od tego ustawienia.
abstract class RestTimerNotificationSettings {
  Future<bool> isEnabled();

  Future<void> setEnabled(bool enabled);
}
