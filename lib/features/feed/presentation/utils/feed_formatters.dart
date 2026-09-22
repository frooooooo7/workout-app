import '../../../../core/utils/polish_plural.dart';
import '../../../training/presentation/widgets/session_details/session_details_formatters.dart';
import '../../domain/models/feed_post.dart';

/// Znacznik czasu posta/komentarza: `Dziś, 18:05`, `Wczoraj, 18:05`,
/// `12 wrz, 18:05`, a spoza bieżącego roku `12 wrz 2025, 18:05`.
String formatFeedTimestamp(DateTime at, {DateTime? now}) {
  final local = at.toLocal();
  final current = (now ?? DateTime.now()).toLocal();
  // Różnica dni kalendarzowych w UTC — lokalna północ przy zmianie czasu
  // dawałaby dobę 23- albo 25-godzinną.
  final days = DateTime.utc(current.year, current.month, current.day)
      .difference(DateTime.utc(local.year, local.month, local.day))
      .inDays;
  final clock = formatClock(local);
  if (days <= 0) return 'Dziś, $clock';
  if (days == 1) return 'Wczoraj, $clock';
  final date = '${local.day} ${formatMonthShort(local)}';
  if (local.year == current.year) return '$date, $clock';
  return '$date ${local.year}, $clock';
}

/// Ćwiczenie z najmocniejszą serią posta (szacowany 1RM wg Epleya), żeby
/// porównywać różne ciężary i liczby powtórzeń. Tylko serie z ciężarem —
/// bez ciężaru nie ma czym się pochwalić na karcie; wtedy `null`.
TopExercise? pickBestSetExercise(List<TopExercise> exercises) {
  TopExercise? best;
  var bestScore = 0.0;
  for (final exercise in exercises) {
    final weight = exercise.bestSet?.weightKg;
    if (weight == null || weight <= 0) continue;
    final reps = exercise.bestSet?.reps ?? 1;
    final score = weight * (1 + reps / 30);
    if (score > bestScore) {
      best = exercise;
      bestScore = score;
    }
  }
  return best;
}

String formatKudosCount(int count) =>
    '$count ${polishPlural(count, 'kudos', 'kudosy', 'kudosów')}';

String formatCommentsCount(int count) =>
    '$count ${polishPlural(count, 'komentarz', 'komentarze', 'komentarzy')}';
