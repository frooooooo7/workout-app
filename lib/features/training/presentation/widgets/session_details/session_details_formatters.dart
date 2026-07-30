import '../../../domain/models/training_history_models.dart';

/// Objętość treningowa: `8 450 kg`, a od tony `12,4 t`. Spacja nierozdzielająca
/// jako separator tysięcy, żeby liczba nie łamała się na końcu wiersza.
String formatVolumeKg(double volumeKg) {
  if (volumeKg <= 0) return '—';
  if (volumeKg >= 1000) {
    final tons = volumeKg / 1000;
    return '${tons.toStringAsFixed(tons >= 10 ? 1 : 2).replaceAll('.', ',')} t';
  }
  return '${_groupThousands(volumeKg.round())} kg';
}

String _groupThousands(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Czas trwania w formacie zegarowym: `1:12:34` albo `12:34`.
String formatDigitalDuration(int seconds) {
  final duration = Duration(seconds: seconds);
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final secs = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$secs' : '$minutes:$secs';
}

/// Godzina lokalna `17:42`.
String formatClock(DateTime time) {
  final local = time.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

const _monthsShort = [
  'sty', 'lut', 'mar', 'kwi', 'maj', 'cze',
  'lip', 'sie', 'wrz', 'paź', 'lis', 'gru',
];

const _weekdaysShort = ['pon', 'wt', 'śr', 'czw', 'pt', 'sob', 'ndz'];

String formatDayNumber(DateTime date) => date.toLocal().day.toString();

String formatMonthShort(DateTime date) => _monthsShort[date.toLocal().month - 1];

String formatWeekdayShort(DateTime date) =>
    _weekdaysShort[date.toLocal().weekday - 1];

/// Pełna data z godziną: `30 cze 2026, 17:42`.
String formatDateWithTime(DateTime date) {
  final local = date.toLocal();
  return '${local.day} ${_monthsShort[local.month - 1]} ${local.year}, '
      '${formatClock(local)}';
}

String formatSessionStatus(TrainingSessionStatus status) => switch (status) {
      TrainingSessionStatus.completed => 'Ukończony',
      TrainingSessionStatus.cancelled => 'Anulowany',
      TrainingSessionStatus.active => 'W trakcie',
    };

/// Metryki serii jako `82,5 kg × 8`, z RIR-em gdy jest.
String formatSetMetrics(TrainingSetMetrics? metrics) {
  if (metrics == null) return '—';
  final weight = metrics.weightKg;
  final reps = metrics.reps;
  if (weight == null && reps == null) return '—';
  if (weight == null) return '$reps powt.';
  if (reps == null) return '${formatWeight(weight)} kg';
  return '${formatWeight(weight)} kg × $reps';
}

/// Ciężar bez zbędnego zera: `80`, `82,5`.
String formatWeight(double weight) {
  final rounded = weight.roundToDouble();
  if (weight == rounded) return rounded.toInt().toString();
  return weight.toStringAsFixed(1).replaceAll('.', ',');
}
