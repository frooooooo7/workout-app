/// Formats a duration in seconds as a human-readable Polish string.
///
/// Examples:
/// - 3600 → "1h 0 min"
/// - 5400 → "1h 30 min"
/// - 300  → "5 min"
String formatDuration(int durationSec) {
  final duration = Duration(seconds: durationSec);
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours == 0) return '$minutes min';
  return '${hours}h $minutes min';
}
