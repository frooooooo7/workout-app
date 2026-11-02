import 'dart:async';
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';

/// Dokąd prowadzi start aplikacji — od tego zależy wyjście z ekranu ładowania.
enum LaunchTarget {
  /// Zalogowany: karty Treningu wjeżdżają z prawdziwymi danymi.
  training,

  /// Bez konta: logo „leci” do karty logowania.
  login,

  /// Inny ekran (np. onboarding świeżego konta): zwykłe wyjście.
  other,
}

enum LaunchPhase {
  /// Wejście i czekanie na docelowy ekran.
  intro,

  /// Nakładka znika, docelowy ekran jest już widoczny pod spodem.
  exiting,

  /// Nakładki już nie ma.
  done,
}

/// Przebieg ekranu ładowania: kiedy znika i co widać w międzyczasie.
///
/// Znika, gdy minęło [minIntro] (tyle trwa wejście) **i** docelowy ekran
/// zgłosił gotowość ([markReady]) — Trening gdy ma dane, logowanie gdy ma
/// obrazki. Czekanie na dane ma limit [maxWait] od zbudowania ekranu
/// ([attach]), a cały start limit [hardCap], żeby nikt nie utknął.
class AppLaunchController extends ChangeNotifier {
  AppLaunchController({
    this.minIntro = const Duration(milliseconds: 850),
    this.maxWait = const Duration(milliseconds: 2500),
    this.hardCap = const Duration(seconds: 20),
    this.slowAfter = const Duration(milliseconds: 1200),
    this.statusAfter = const Duration(seconds: 3),
    this.exitDuration = const Duration(milliseconds: 700),
  });

  /// Najkrótszy czas ekranu (wejście logo). Przy wyłączonych animacjach 0.
  final Duration minIntro;

  /// Najdłuższe czekanie na dane od zbudowania docelowego ekranu.
  final Duration maxWait;

  /// Absolutny limit całego startu.
  final Duration hardCap;

  /// Po tym czasie pokazuje się cienki pasek ładowania.
  final Duration slowAfter;

  /// Po tym czasie (jeśli wciąż czekamy) pojawia się opis.
  final Duration statusAfter;

  /// Czas wyjścia (animacja znikania); po nim nakładka jest usuwana.
  final Duration exitDuration;

  LaunchPhase _phase = LaunchPhase.intro;
  LaunchPhase get phase => _phase;

  LaunchTarget? _target;
  LaunchTarget? get target => _target;

  bool _started = false;
  bool _reduceMotion = false;
  bool get reduceMotion => _reduceMotion;

  bool _minElapsed = false;
  bool _ready = false;
  bool _assetsReady = false;
  bool _attached = false;

  bool _showProgress = false;
  bool get showProgress => _showProgress;

  bool _showStatus = false;
  bool get showStatus => _showStatus;

  bool _awaitingServer = false;

  /// Czy start czeka na odpowiedź serwera (brak zapisanego użytkownika).
  bool get awaitingServer => _awaitingServer;

  /// Gdzie na ekranie jest logo w karcie logowania (cel lotu logo).
  Rect? Function()? loginLogoRect;

  /// Wyznaczone na początku wyjścia (docelowy ekran jest wtedy już na miejscu).
  Rect? _loginLogoTarget;
  Rect? get loginLogoTarget => _loginLogoTarget;

  final Completer<void> _revealed = Completer<void>();
  final Completer<void> _done = Completer<void>();

  /// Kończy się, gdy nakładka zaczyna znikać (docelowy ekran gra wejście).
  Future<void> get whenRevealed => _revealed.future;

  /// Kończy się, gdy nakładki już nie ma (np. ekran PRO może się pokazać).
  Future<void> get whenDone => _done.future;

  bool get revealed => _phase != LaunchPhase.intro;
  bool get isDone => _phase == LaunchPhase.done;

  Timer? _minTimer;
  Timer? _slowTimer;
  Timer? _statusTimer;
  Timer? _maxTimer;
  Timer? _capTimer;
  Timer? _exitTimer;

  /// Uruchamia zegary — wołane, gdy logo jest już gotowe do narysowania,
  /// czyli w chwili, gdy użytkownik widzi pierwszą klatkę.
  void start({bool reduceMotion = false}) {
    if (_started || _phase != LaunchPhase.intro) return;
    _started = true;
    _reduceMotion = reduceMotion;
    if (reduceMotion || minIntro == Duration.zero) {
      _minElapsed = true;
    } else {
      _minTimer = Timer(minIntro, () {
        _minElapsed = true;
        _maybeExit();
      });
    }
    _slowTimer = Timer(slowAfter, () {
      _showProgress = true;
      notifyListeners();
    });
    _statusTimer = Timer(statusAfter, () {
      _showStatus = true;
      notifyListeners();
    });
    _capTimer = Timer(hardCap, _beginExit);
    notifyListeners();
  }

  /// Start czeka na serwer (bez zapisanego użytkownika) — opis „Łączę…”.
  void setAwaitingServer(bool value) {
    if (_awaitingServer == value) return;
    _awaitingServer = value;
    notifyListeners();
  }

  /// Docelowy ekran jest zbudowany: od teraz czekanie na dane ma limit.
  void attach(LaunchTarget target) {
    if (_phase != LaunchPhase.intro) return;
    _target ??= target;
    if (_attached) return;
    _attached = true;
    _maxTimer = Timer(maxWait, () {
      _ready = true;
      _assetsReady = true;
      _maybeExit();
    });
  }

  /// Docelowy ekran ma wszystko, co trzeba, żeby go pokazać.
  void markReady(LaunchTarget target) {
    if (_phase != LaunchPhase.intro) return;
    _target = target;
    _ready = true;
    _maybeExit();
  }

  /// Zdjęcie i logo logowania są zdekodowane (nakładka wczytuje je sama).
  void markAssetsReady() {
    if (_assetsReady) return;
    _assetsReady = true;
    _maybeExit();
  }

  void _maybeExit() {
    if (_phase != LaunchPhase.intro || !_started) return;
    if (!_ready || !_minElapsed) return;
    // Logowanie pokazuje się dopiero z gotowymi obrazkami.
    if (_target == LaunchTarget.login && !_assetsReady) return;
    _beginExit();
  }

  void _beginExit() {
    if (_phase != LaunchPhase.intro) return;
    _cancelIntroTimers();
    _phase = LaunchPhase.exiting;
    if (_target == LaunchTarget.login) {
      _loginLogoTarget = loginLogoRect?.call();
    }
    if (!_revealed.isCompleted) _revealed.complete();
    notifyListeners();
    _exitTimer = Timer(exitDuration, () {
      _phase = LaunchPhase.done;
      if (!_done.isCompleted) _done.complete();
      notifyListeners();
    });
  }

  void _cancelIntroTimers() {
    _minTimer?.cancel();
    _slowTimer?.cancel();
    _statusTimer?.cancel();
    _maxTimer?.cancel();
    _capTimer?.cancel();
  }

  @override
  void dispose() {
    _cancelIntroTimers();
    _exitTimer?.cancel();
    super.dispose();
  }
}
