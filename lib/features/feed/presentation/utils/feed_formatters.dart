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

/// `Wyciskanie sztangi na ławce · 4 serie · 82,5 kg × 8`.
String formatTopExerciseLine(TopExercise exercise) {
  final parts = <String>[
    exercise.name,
    formatSetsCount(exercise.completedSets),
  ];
  final best = formatSetMetrics(exercise.bestSet);
  if (best != '—') parts.add(best);
  return parts.join(' · ');
}

String formatSetsCount(int count) =>
    '$count ${polishPlural(count, 'seria', 'serie', 'serii')}';

String formatKudosCount(int count) =>
    '$count ${polishPlural(count, 'kudos', 'kudosy', 'kudosów')}';

String formatCommentsCount(int count) =>
    '$count ${polishPlural(count, 'komentarz', 'komentarze', 'komentarzy')}';

String formatExercisesCount(int count) =>
    '$count ${polishPlural(count, 'ćwiczenie', 'ćwiczenia', 'ćwiczeń')}';
