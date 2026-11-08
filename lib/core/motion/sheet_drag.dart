import 'package:flutter/animation.dart';

/// Krzywa arkusza dosuniętego do krawędzi (Vaul / iOS): stroma na starcie,
/// miękkie lądowanie. 500 ms nadal czyta się krótko, bo większość ruchu
/// dzieje się w pierwszych klatkach.
const Cubic sheetEdgeCurve = Cubic(0.32, 0.72, 0, 1);

const Duration sheetEnterDuration = Duration(milliseconds: 500);

/// Zamknięcie przyciskiem — bez odbicia, krócej niż wejście.
/// Gest niesie siłę i kończy się sprężyną; przycisk nie.
const Duration sheetButtonCloseDuration = Duration(milliseconds: 240);

/// Szybkie pstryknięcie w dół (logiczne px/s). Ten sam próg co wbudowany
/// arkusz Materiala — krótkie pociągnięcie z tą prędkością zamyka.
const double sheetFlingVelocity = 700;

/// Ułamek wysokości, po którym puszczenie zamyka arkusz bez flicku.
const double sheetDismissFraction = 0.5;

/// Opór po minięciu krawędzi spoczynku (`dragElastic`).
const double sheetRubberBand = 0.2;

/// Następne przesunięcie arkusza w pikselach (dodatnie = w dół).
///
/// W zakresie otwarcia palec i arkusz jadą 1:1. Powyżej spoczynku (ujemne)
/// ruch jest tłumiony, a powrót do zera oddaje palec z powrotem 1:1.
double nextSheetOffset(
  double current,
  double delta, {
  double elastic = sheetRubberBand,
}) {
  if (delta == 0) return current;
  final next = current + delta;
  if (current >= 0 && next >= 0) return next;
  if (current <= 0 && delta < 0) return current + delta * elastic;
  if (current <= 0 && delta > 0) {
    final room = -current / elastic;
    if (delta <= room) return current + delta * elastic;
    return delta - room;
  }
  return next * elastic;
}

/// Puszczenie zamyka, gdy arkusz przejechał połowę drogi albo poleciał
/// w dół szybciej niż [sheetFlingVelocity]. Samo pstryknięcie w górę nie
/// zamyka.
bool shouldDismissSheet({
  required double offset,
  required double travel,
  required double velocity,
}) {
  if (offset <= 0 || travel <= 0) return false;
  if (velocity >= sheetFlingVelocity) return true;
  return offset >= travel * sheetDismissFraction;
}
