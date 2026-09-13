import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../network/api_client.dart';
import 'sync_failure.dart';

/// Wspólny szkielet silników synchronizacji:
///
/// * kolejka — `flush` i `pull` nigdy nie przeplatają się ze sobą,
/// * zlewanie żądań — seria zapisów w trakcie treningu nie buduje kolejki
///   dziesiątek identycznych prób (każda mogłaby czekać na timeout),
/// * licznik aktywności dla wskaźnika synchronizacji,
/// * sygnał „dane lokalne się zmieniły” dla ekranów.
abstract class SyncEngineBase {
  SyncEngineBase({VoidCallback? onDataChanged})
    : _onDataChanged = onDataChanged;

  /// Jak często odczyt ekranu może wywołać pobranie danych z serwera.
  static const defaultPullMaxAge = Duration(seconds: 30);

  final VoidCallback? _onDataChanged;
  final ValueNotifier<int> _activeRuns = ValueNotifier<int>(0);
  final Map<String, Future<void>> _queuedByKey = {};

  bool _stopped = false;
  Future<void> _queue = Future<void>.value();
  DateTime? _lastPullAttemptAt;
  ApiException? _lastTransientFailure;
  int _networkFailureCount = 0;

  bool get isStopped => _stopped;

  /// Liczba zadań w kolejce (oczekujących i trwającego).
  ValueListenable<int> get activeRuns => _activeRuns;

  void stop() => _stopped = true;

  /// Zwraca i zeruje ostatni błąd przejściowy (np. brak sieci).
  ApiException? takeTransientFailure() {
    final failure = _lastTransientFailure;
    _lastTransientFailure = null;
    return failure;
  }

  @protected
  Future<void> runExclusive(Future<void> Function() body) {
    final done = Completer<void>();
    _activeRuns.value++;
    _queue = _queue.then((_) async {
      try {
        await body();
        done.complete();
      } catch (error, stackTrace) {
        done.completeError(error, stackTrace);
      } finally {
        _activeRuns.value--;
      }
    });
    return done.future;
  }

  /// Jak [runExclusive], ale gdy zadanie o tym samym [key] czeka jeszcze
  /// w kolejce (nie wystartowało), zwraca jego wynik zamiast dokładać kolejne.
  @protected
  Future<void> runCoalesced(String key, Future<void> Function() body) {
    final queued = _queuedByKey[key];
    if (queued != null) return queued;
    late final Future<void> future;
    future = runExclusive(() {
      if (identical(_queuedByKey[key], future)) _queuedByKey.remove(key);
      return body();
    });
    _queuedByKey[key] = future;
    return future;
  }

  /// Czy od ostatniej próby pobrania minęło co najmniej [maxAge]. Liczymy
  /// próby, nie sukcesy — inaczej offline każdy odczyt ekranu ciągnąłby sieć.
  @protected
  bool isPullDue(Duration maxAge) {
    final last = _lastPullAttemptAt;
    return last == null || DateTime.now().difference(last) >= maxAge;
  }

  @protected
  void markPullAttempt() => _lastPullAttemptAt = DateTime.now();

  @protected
  void notifyDataChanged() => _onDataChanged?.call();

  /// Zapamiętuje błąd i zwraca jego rodzaj — przy [SyncFailureKind.permanent]
  /// silnik oznacza wiersz jako odrzucony, żeby nie ponawiać go w pętli.
  @protected
  SyncFailureKind registerFailure(ApiException error) {
    final kind = classifySyncFailure(error);
    if (kind == SyncFailureKind.transient) _lastTransientFailure = error;
    if (isNetworkFailure(error)) _networkFailureCount++;
    return kind;
  }

  /// Znacznik dla [networkFailedSince] — pobierany na starcie wysyłki.
  @protected
  int get networkFailureMark => _networkFailureCount;

  /// Czy od [mark] wystąpił brak sieci — flush przerywa wtedy pętlę zamiast
  /// czekać na timeout każdego kolejnego wiersza. Błąd sprzed znacznika
  /// (np. nieudany pull offline) nie blokuje wysyłki po powrocie sieci.
  @protected
  bool networkFailedSince(int mark) => _networkFailureCount != mark;

  @protected
  void logUnexpected(String message, Object error, StackTrace stackTrace) {
    developer.log(
      message,
      name: runtimeType.toString(),
      error: error,
      stackTrace: stackTrace,
    );
  }
}
