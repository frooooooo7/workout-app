abstract class RestTimerScheduler {
  Future<void> scheduleRestFinished({required Duration duration});

  Future<void> cancelRestFinished();
}
