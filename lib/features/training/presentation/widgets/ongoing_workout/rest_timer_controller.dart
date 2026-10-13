import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/services/rest_timer_scheduler.dart';

/// Odliczanie przerwy między seriami. Sekunda zmienia tylko [remaining] —
/// słucha go sam panel odpoczynku, nie cały ekran; start, koniec i zmiana
/// długości wołają [notifyListeners].
///
/// Systemowe powiadomienie o końcu przerwy planuje [scheduler] (gdy jest).
class RestTimerController extends ChangeNotifier {
  RestTimerController({this.scheduler});

  final RestTimerScheduler? scheduler;

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
  bool _disposed = false;

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
    selectedDuration = duration;
    _total = duration;
    remaining.value = duration;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    notifyListeners();
    return _schedule(duration);
  }

  /// „+15 s”: wydłuża bieżącą przerwę i przesuwa powiadomienie.
  Future<bool> extend(Duration extra) async {
    if (!isActive) return true;
    _total += extra;
    remaining.value += extra;
    notifyListeners();
    return _schedule(remaining.value);
  }

  /// „Pomiń” / „Zatrzymaj”: kończy przerwę i odwołuje powiadomienie.
  void stop() {
    _ticker?.cancel();
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

  void _tick() {
    if (remaining.value <= const Duration(seconds: 1)) {
      _ticker?.cancel();
      // Koniec przerwy czuć w dłoni; dźwięk daje powiadomienie systemowe.
      unawaited(HapticFeedback.heavyImpact());
      _reset();
      return;
    }
    remaining.value -= const Duration(seconds: 1);
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
    final pending = scheduler?.cancelRestFinished();
    if (pending != null) unawaited(pending.catchError((_) {}));
    remaining.dispose();
    super.dispose();
  }
}
