import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/services/rest_timer_scheduler.dart';

/// Odliczanie przerwy między seriami. Sekunda zmienia tylko [remaining] —
/// słucha go sam panel odpoczynku, nie cały ekran; start, koniec i zmiana
/// długości wołają [notifyListeners].
///
/// Systemowe powiadomienie o końcu przerwy planuje [scheduler] (gdy jest).
///
/// Odliczanie idzie od godziny końca przerwy, nie od liczby tyknięć — przy
/// zablokowanym ekranie system wstrzymuje timery, a po powrocie licznik od
/// razu pokazuje prawdziwy czas (albo kończy przerwę, jeśli już minęła).
class RestTimerController extends ChangeNotifier {
  RestTimerController({this.scheduler, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final RestTimerScheduler? scheduler;
  final DateTime Function() _clock;

  /// Częstsze niż co sekundę, żeby opóźnione tyknięcie nie gubiło sekund.
  static const _tickInterval = Duration(milliseconds: 250);

  /// Ile zostało; [Duration.zero], gdy przerwa nie trwa.
  final ValueNotifier<Duration> remaining = ValueNotifier(Duration.zero);

  /// Pełna długość bieżącej przerwy (z dodanymi „+15 s”) — mianownik
  /// pierścienia.
  Duration get total => _total;
  Duration _total = Duration.zero;

  /// Ostatnio wybrana długość przerwy — z nią przerwa startuje sama po
  /// odhaczeniu serii.
  Duration selectedDuration = const Duration(seconds: 90);

  /// Ostatnia własna długość przerwy — skrót w arkuszu wyboru.
  Duration? get lastCustomDuration => _lastCustomDuration;
  Duration? _lastCustomDuration;

  static const _lastCustomKey = 'last_custom_rest_duration';

  Timer? _ticker;
  DateTime? _endsAt;
  bool _disposed = false;

  /// Po powrocie na pierwszy plan licznik od razu łapie prawdziwy czas,
  /// zamiast czekać na najbliższe tyknięcie.
  AppLifecycleListener? _lifecycle;

  /// Wczytuje zapamiętaną własną długość przerwy.
  Future<void> loadLastCustomDuration() async {
    final prefs = await SharedPreferences.getInstance();
    final seconds = prefs.getInt(_lastCustomKey);
    if (seconds == null || _disposed) return;
    _lastCustomDuration = Duration(seconds: seconds);
    notifyListeners();
  }

  void rememberCustomDuration(Duration duration) {
    _lastCustomDuration = duration;
    unawaited(
      SharedPreferences.getInstance().then(
        (prefs) => prefs.setInt(_lastCustomKey, duration.inSeconds),
      ),
    );
  }

  bool get isActive => _ticker?.isActive == true;

  /// Startuje (albo restartuje) przerwę. Zwraca `false`, gdy lokalny licznik
  /// ruszył, ale powiadomienia systemowego nie udało się zaplanować.
  Future<bool> start(Duration duration) async {
    _ticker?.cancel();
    _lifecycle ??= AppLifecycleListener(onResume: sync);
    selectedDuration = duration;
    _total = duration;
    _endsAt = _clock().add(duration);
    remaining.value = duration;
    _ticker = Timer.periodic(_tickInterval, (_) => sync());
    notifyListeners();
    return _schedule(duration);
  }

  /// „+15 s”: wydłuża bieżącą przerwę i przesuwa powiadomienie.
  Future<bool> extend(Duration extra) async {
    final endsAt = _endsAt;
    if (!isActive || endsAt == null) return true;
    _total += extra;
    final newEnd = endsAt.add(extra);
    _endsAt = newEnd;
    sync();
    // Przerwa mogła już minąć (ekran wrócił, ticker jeszcze nie tyknął).
    if (!isActive) return true;
    notifyListeners();
    return _schedule(newEnd.difference(_clock()));
  }

  /// „Pomiń” / „Zatrzymaj”: kończy przerwę i odwołuje powiadomienie.
  void stop() {
    _ticker?.cancel();
    _endsAt = null;
    final pending = scheduler?.cancelRestFinished();
    if (pending != null) unawaited(pending.catchError((_) {}));
    _reset();
  }

  Future<bool> _schedule(Duration duration) async {
    final scheduler = this.scheduler;
    if (scheduler == null) return true;
    try {
      await scheduler.scheduleRestFinished(duration: duration);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Przelicza [remaining] z godziny końca przerwy. Woła ją ticker i powrót
  /// aplikacji na pierwszy plan.
  void sync() {
    final endsAt = _endsAt;
    if (endsAt == null || !isActive) return;
    final left = endsAt.difference(_clock());
    if (left <= Duration.zero) {
      _ticker?.cancel();
      _endsAt = null;
      // Koniec przerwy czuć w dłoni; dźwięk daje powiadomienie systemowe.
      unawaited(HapticFeedback.heavyImpact());
      _reset();
      return;
    }
    // W górę do pełnej sekundy: przez pierwszą sekundę widać „1:30”, nie
    // „1:29”, a „0:00” pojawia się dopiero razem z końcem przerwy.
    remaining.value = Duration(seconds: (left.inMilliseconds / 1000).ceil());
  }

  void _reset() {
    if (_disposed) return;
    remaining.value = Duration.zero;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    _lifecycle?.dispose();
    final pending = scheduler?.cancelRestFinished();
    if (pending != null) unawaited(pending.catchError((_) {}));
    remaining.dispose();
    super.dispose();
  }
}
