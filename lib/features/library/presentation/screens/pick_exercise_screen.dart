import 'package:flutter/material.dart';

import 'library_screen.dart';

/// Wybór ćwiczeń do planu albo treningu: ta sama biblioteka co w zakładce
/// (ekran startowy z partiami, szukanie, filtry), ale stuknięcie zaznacza
/// i numeruje, a na dole jest „Dodaj N ćwiczeń”. Zwraca `List<Exercise>`
/// (kolejność zaznaczania) albo `null` po wyjściu bez wyboru.
class PickExerciseScreen extends StatelessWidget {
  const PickExerciseScreen({
    super.key,
    this.title = 'Wybierz ćwiczenia',
    this.subtitle,
    this.existingIds = const {},
    this.existingLabel = 'W planie',
  });

  final String title;

  /// Np. „Push A · 4 ćwiczenia w planie”.
  final String? subtitle;

  /// Id ćwiczeń, które już są w planie/treningu — dostają plakietkę „W planie”.
  final Set<String> existingIds;

  /// Tekst plakietki: „W planie” albo „W treningu”.
  final String existingLabel;

  @override
  Widget build(BuildContext context) => LibraryScreen(
    pickMode: true,
    pickTitle: title,
    pickSubtitle: subtitle,
    existingIds: existingIds,
    existingLabel: existingLabel,
  );
}
