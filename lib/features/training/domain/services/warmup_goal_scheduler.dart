/// Ciche powiadomienie systemowe, gdy rozgrzewka dojdzie do celu czasu
/// (np. przy zablokowanym ekranie). Stoper w aplikacji działa niezależnie.
abstract class WarmupGoalScheduler {
  Future<void> scheduleGoalReached({required Duration after});

  Future<void> cancelGoalReached();
}

/// Bez powiadomień (web, testy).
class NoopWarmupGoalScheduler implements WarmupGoalScheduler {
  const NoopWarmupGoalScheduler();

  @override
  Future<void> scheduleGoalReached({required Duration after}) async {}

  @override
  Future<void> cancelGoalReached() async {}
}
