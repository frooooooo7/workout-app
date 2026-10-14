import 'dart:async';

import 'package:flutter/widgets.dart';

import '../domain/repositories/notifications_repository.dart';

/// Liczba nieprzeczytanych powiadomień — dzwonek w „Aktywności” i plakietka
/// w dolnym pasku. Odświeżana przy wejściu na zakładkę, po powrocie do
/// aplikacji i co [pollInterval], gdy aplikacja jest na pierwszym planie.
/// Zapytania częstsze niż [minInterval] są pomijane.
class UnreadNotificationsCounter extends ValueNotifier<int>
    with WidgetsBindingObserver {
  UnreadNotificationsCounter({
    this.minInterval = const Duration(seconds: 20),
    this.pollInterval = const Duration(minutes: 2),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       super(0);

  final Duration minInterval;
  final Duration pollInterval;
  final DateTime Function() _clock;

  NotificationsRepository? _repository;
  Timer? _timer;
  DateTime? _lastFetch;
  Future<void>? _inFlight;
  bool _observing = false;
  bool _foreground = true;

  /// Rośnie przy każdej zmianie konta i każdej lokalnej zmianie licznika:
  /// odpowiedź zapytania wysłanego wcześniej jest wtedy nieaktualna.
  int _generation = 0;

  /// Podpina repozytorium zalogowanego konta (albo `null` po wylogowaniu)
  /// i zeruje licznik.
  void attach(NotificationsRepository? repository) {
    _repository = repository;
    _generation++;
    _lastFetch = null;
    _inFlight = null;
    value = 0;
    if (repository != null && !_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
    _restartTimer();
    if (repository != null) unawaited(refresh(force: true));
  }

  /// Ustawia licznik z danych, które ekran już ma (lista, oznaczenie).
  void set(int count) {
    _generation++;
    _lastFetch = _clock();
    value = count < 0 ? 0 : count;
  }

  Future<void> refresh({bool force = false}) {
    final repository = _repository;
    if (repository == null) return Future.value();
    if (_inFlight case final pending?) return pending;
    final last = _lastFetch;
    if (!force && last != null && _clock().difference(last) < minInterval) {
      return Future.value();
    }
    final generation = _generation;
    _lastFetch = _clock();
    final request = repository
        .unreadCount()
        .then((count) {
          if (generation == _generation) value = count;
        })
        .catchError((Object _) {
          /* offline — zostaje ostatnia znana wartość */
        })
        .whenComplete(() {
          if (generation == _generation) _inFlight = null;
        });
    _inFlight = request;
    return request;
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = null;
    if (_repository == null || !_foreground) return;
    _timer = Timer.periodic(pollInterval, (_) => unawaited(refresh()));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (foreground == _foreground) return;
    _foreground = foreground;
    _restartTimer();
    if (foreground) unawaited(refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
