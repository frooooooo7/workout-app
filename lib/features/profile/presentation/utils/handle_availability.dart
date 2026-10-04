import 'dart:async';

/// Wynik sprawdzania nicku na żywo, podczas pisania.
enum HandleAvailability {
  /// Nic nie sprawdzamy: nick bez zmian, z błędem formatu albo serwer nie
  /// odpowiedział. Zapis i tak zweryfikuje nick na serwerze.
  unknown,
  checking,
  available,
  taken,
}

const kHandleTakenMessage = 'Ten nick jest już zajęty. Wybierz inny.';

/// Odkłada zapytanie o dostępność nicku do chwili, gdy użytkownik przestanie
/// pisać, i odrzuca odpowiedzi dla nicków, które zdążyły się zmienić.
class HandleAvailabilityChecker {
  HandleAvailabilityChecker(
    this._isAvailable, {
    this.delay = const Duration(milliseconds: 400),
  });

  final Future<bool> Function(String handle) _isAvailable;
  final Duration delay;

  Timer? _timer;
  var _generation = 0;

  /// Sprawdza [handle] po [delay]; [onResult] dostaje wynik tylko dla
  /// ostatnio zleconego nicku. Błąd sieci → [HandleAvailability.unknown].
  void check(String handle, void Function(HandleAvailability) onResult) {
    cancel();
    final generation = _generation;
    _timer = Timer(delay, () async {
      HandleAvailability result;
      try {
        result = await _isAvailable(handle)
            ? HandleAvailability.available
            : HandleAvailability.taken;
      } catch (_) {
        result = HandleAvailability.unknown;
      }
      if (generation == _generation) onResult(result);
    });
  }

  /// Porzuca zaplanowane i trwające sprawdzenie.
  void cancel() {
    _timer?.cancel();
    _timer = null;
    _generation++;
  }
}
