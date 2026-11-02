import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

/// Wstrzymuje pierwszą klatkę Fluttera, dopóki logo nakładki nie jest
/// zdekodowane — dzięki temu pierwsza klatka jest identyczna ze splashem
/// systemowym i nic nie miga. Zawsze jest puszczana, najpóźniej po [limit].
class NativeSplashGate {
  NativeSplashGate._();

  /// Tyle po starcie aplikacji pierwsza klatka jest puszczana najpóźniej.
  static const limit = Duration(seconds: 1);

  static bool _held = false;
  static Timer? _timer;

  /// Wołane w `main()` przed `runApp`.
  static void hold(WidgetsBinding binding) {
    if (_held) return;
    _held = true;
    FlutterNativeSplash.preserve(widgetsBinding: binding);
    // Bezpiecznik także dla inicjalizacji przed `runApp`.
    _timer = Timer(const Duration(seconds: 5), release);
  }

  /// Po `runApp`: puść pierwszą klatkę za [after], jeśli nikt nie zrobi tego
  /// wcześniej (logo, którego nie da się zdekodować, nie może jej zatrzymać).
  static void releaseAfter([Duration after = limit]) {
    if (!_held) return;
    _timer?.cancel();
    _timer = Timer(after, release);
  }

  /// Puszcza pierwszą klatkę (bezpieczne do wielokrotnego wołania).
  static void release() {
    _timer?.cancel();
    _timer = null;
    if (!_held) return;
    _held = false;
    FlutterNativeSplash.remove();
  }
}
