/// Miesiąc PRO dla nowego konta: liczony od daty założenia konta.
///
/// Czysta logika bez zależności od UI — [now] podaje wywołujący, więc da się
/// ją testować na stałych datach.
class ProTrial {
  const ProTrial._({
    required this.end,
    required this.daysLeft,
    required this.dayNumber,
    required this.isEnded,
  });

  /// Długość okresu próbnego.
  static const lengthDays = 30;

  /// Na tylu ostatnich dniach pokazujemy pasek na ekranie Trening.
  static const warningDays = 7;

  factory ProTrial.of(DateTime createdAt, {required DateTime now}) {
    final end = createdAt.add(const Duration(days: lengthDays));
    final remaining = end.difference(now);
    final ended = remaining <= Duration.zero;
    // Zaokrąglamy w górę: ostatniego dnia wciąż jest „1 dzień”.
    final left = ended
        ? 0
        : (remaining.inMinutes / Duration.minutesPerDay).ceil().clamp(
            1,
            lengthDays,
          );
    final day = ended
        ? lengthDays
        : (lengthDays - left + 1).clamp(1, lengthDays);
    return ProTrial._(end: end, daysLeft: left, dayNumber: day, isEnded: ended);
  }

  final DateTime end;

  /// Pełne dni do końca (0 po zakończeniu).
  final int daysLeft;

  /// Który to dzień okresu próbnego (1–30).
  final int dayNumber;

  final bool isEnded;

  bool get isActive => !isEnded;

  /// Ostatni tydzień trialu.
  bool get isEnding => isActive && daysLeft <= warningDays;

  /// 0–1, do paska postępu.
  double get progress => isEnded ? 1 : dayNumber / lengthDays;
}

/// „Zostało 7 dni” / „Został 1 dzień” / „Zostały 3 dni” (polska odmiana).
String proDaysLeftLabel(int days) {
  if (days == 1) return 'Został 1 dzień';
  final lastTwo = days % 100;
  final last = days % 10;
  final few = last >= 2 && last <= 4 && !(lastTwo >= 12 && lastTwo <= 14);
  return few ? 'Zostały $days dni' : 'Zostało $days dni';
}
