import 'package:flutter/material.dart';

import 'library_screen.dart';

/// Wybór ćwiczeń do planu albo treningu: ta sama biblioteka co w zakładce
/// (ekran startowy z partiami, szukanie, filtry), ale stuknięcie zaznacza,
/// a na dole jest „Dodaj N ćwiczeń”. Zwraca `List<Exercise>` (kolejność
/// zaznaczania) albo `null` po wyjściu bez wyboru.
class PickExerciseScreen extends StatelessWidget {
  const PickExerciseScreen({super.key});

  @override
  Widget build(BuildContext context) => const LibraryScreen(pickMode: true);
}
