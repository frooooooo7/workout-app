abstract class RestTimerScheduler {
  Future<void> scheduleRestFinished({required Duration duration});

  Future<void> cancelRestFinished();

  /// Rozgrzewa timezone / plugin powiadomień poza ścieżką pierwszego timeru.
  Future<void> warmUp();
}
