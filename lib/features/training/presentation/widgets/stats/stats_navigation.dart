import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Czy z [exerciseId] da się otworzyć szczegóły ćwiczenia.
bool canOpenStatsExercise(String exerciseId) => exerciseId.trim().isNotEmpty;

/// Szczegóły ćwiczenia ze statystyk. Id bywa lokalnym UUID albo id z serwera,
/// więc idzie w ścieżce zakodowane — `/` czy `%` nie rozbiją trasy. Bez
/// routera (testy widgetów) nic się nie dzieje.
void openStatsExercise(BuildContext context, String exerciseId) {
  final id = exerciseId.trim();
  if (id.isEmpty) return;
  GoRouter.maybeOf(context)?.push('/app/exercises/${Uri.encodeComponent(id)}');
}

/// Szczegóły treningu ze statystyk (heatmapa, rekordy sesji). Id to lokalny
/// identyfikator sesji — repozytorium historii znajduje ją też po id serwera.
void openStatsSession(BuildContext context, String sessionId) {
  final id = sessionId.trim();
  if (id.isEmpty) return;
  GoRouter.maybeOf(
    context,
  )?.push('/app/training/history/${Uri.encodeComponent(id)}');
}
