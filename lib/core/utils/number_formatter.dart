/// Liczniki na profilu: `987`, `1 234`, `12,3 tys.`, `1,2 mln`.
String formatCompactCount(int value) {
  final abs = value.abs();
  final sign = value < 0 ? '-' : '';
  if (abs < 10000) return '$sign${_groupThousands(abs)}';
  if (abs < 1000000) return '$sign${_oneDecimal(abs / 1000)} tys.';
  return '$sign${_oneDecimal(abs / 1000000)} mln';
}

String _groupThousands(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    // Twarda spacja — liczba nie łamie się między wierszami.
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

String _oneDecimal(double value) {
  final truncated = (value * 10).floor() / 10;
  final text = truncated == truncated.roundToDouble()
      ? truncated.toInt().toString()
      : truncated.toStringAsFixed(1);
  return text.replaceAll('.', ',');
}
