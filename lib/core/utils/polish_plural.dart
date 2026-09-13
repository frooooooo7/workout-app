/// Polska forma rzeczownika po liczebniku: 1 zmiana, 2–4 zmiany, 5+ zmian
/// (12–14 też „zmian”).
String polishPlural(int count, String one, String few, String many) {
  if (count == 1) return one;
  final lastDigit = count % 10;
  final lastTwoDigits = count % 100;
  final isFew = lastDigit >= 2 &&
      lastDigit <= 4 &&
      (lastTwoDigits < 12 || lastTwoDigits > 14);
  return isFew ? few : many;
}
