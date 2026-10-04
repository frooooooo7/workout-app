import '../../domain/models/training_stats.dart';
import 'stats/stats_format.dart';

/// Wspólne podpisy rekordów — karta rekordów w statystykach, podsumowanie
/// treningu i post w feedzie mówią o rekordzie tymi samymi słowami.

String personalRecordKindLabel(PersonalRecordKind kind) => switch (kind) {
  PersonalRecordKind.weight => 'Ciężar',
  PersonalRecordKind.oneRepMax => '1RM',
  PersonalRecordKind.reps => 'Powtórzenia',
};

/// „85 kg × 3”, „e1RM 101 kg”, „15 powt.”
String personalRecordValue(PersonalRecord r) {
  switch (r.primaryKind) {
    case PersonalRecordKind.weight:
      final w = r.weightKg;
      if (w == null) break;
      final kg = '${formatStatsDecimal(w)} kg';
      return r.reps == null ? kg : '$kg × ${r.reps}';
    case PersonalRecordKind.oneRepMax:
      final orm = r.oneRepMaxKg;
      if (orm == null) break;
      return 'e1RM ${formatStatsDecimal(orm, digits: 0)} kg';
    case PersonalRecordKind.reps:
      if (r.reps == null) break;
      return '${r.reps} powt.';
  }
  return '—';
}

String? personalRecordImprovement(PersonalRecord r) {
  final diff = r.improvement;
  if (diff == null || diff <= 0) return null;
  return switch (r.primaryKind) {
    PersonalRecordKind.reps => '+${diff.round()} powt.',
    _ => '+${formatStatsDecimal(diff)} kg',
  };
}
