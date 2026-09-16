import '../domain/services/rest_timer_notification_settings.dart';
import '../domain/services/rest_timer_scheduler.dart';

/// Nie planuje powiadomienia, gdy użytkownik je wyłączył w ustawieniach
/// (bez pytania o uprawnienia). Anulowanie działa zawsze — powiadomienie
/// zaplanowane przed wyłączeniem też ma dać się odwołać.
class SettingsAwareRestTimerScheduler implements RestTimerScheduler {
  const SettingsAwareRestTimerScheduler({
    required RestTimerScheduler inner,
    required RestTimerNotificationSettings settings,
  }) : _inner = inner,
       _settings = settings;

  final RestTimerScheduler _inner;
  final RestTimerNotificationSettings _settings;

  @override
  Future<void> scheduleRestFinished({required Duration duration}) async {
    if (!await _settings.isEnabled()) {
      await _inner.cancelRestFinished();
      return;
    }
    await _inner.scheduleRestFinished(duration: duration);
  }

  @override
  Future<void> cancelRestFinished() => _inner.cancelRestFinished();

  @override
  Future<void> warmUp() => _inner.warmUp();
}
