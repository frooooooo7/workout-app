import 'dart:ui';

import '../../../../../core/theme/app_colors.dart';

/// Odcienie ekranu treningu na żywo, których nie ma w [AppColors] — pola
/// serii, wiersze tabeli, panel odpoczynku. Wszystko inne bierzemy z
/// [AppColors], żeby ekran nie rozjechał się z resztą aplikacji.
abstract final class WorkoutColors {
  /// Tło pól ciężaru / powtórzeń i miniatur.
  static const field = Color(0xFF0D121B);

  /// Krawędź pól aktywnej serii.
  static const fieldBorder = Color(0xFF34456B);

  /// Chipy „Ostatnio”, przycisk historii ćwiczenia.
  static const chip = Color(0xFF1A2030);

  /// Tekst drugiego planu (chipy, „Teraz: …”).
  static const textSoft = Color(0xFFA3ACBD);

  /// Nagłówki kolumn i wynik z poprzedniego treningu.
  static const textFaint = Color(0xFF6B7487);

  /// Ptaszek na zielonym przycisku zrobionej serii.
  static const onSuccess = Color(0xFF052E1F);

  /// Tło znaczka „+2,5” nad polem ciężaru.
  static const progressionTag = Color(0xFF12301F);

  /// Pusty segment paska postępu i tor bieżącego segmentu.
  static const segmentTrack = Color(0xFF1C2333);
  static const segmentTrackCurrent = Color(0xFF2A2F3A);

  /// Przerywana ramka „Dodaj serię”.
  static const dashedBorder = Color(0xFF2A3550);

  /// Link „Dodaj serię / ćwiczenie”.
  static const link = Color(0xFF7FA6FF);

  /// Karta „Następne” — ciszej niż karta bieżącego ćwiczenia.
  static const nextCard = Color(0xFF10151F);
  static const nextCardBorder = Color(0xFF1B2231);

  /// Panel odpoczynku: szkło, tor pierścienia i przycisk „+15 s”.
  static const restPanel = Color(0xF0171D2B);
  static const restTrack = Color(0xFF232C40);

  /// Przycisk „Zakończ” w nagłówku.
  static const finishText = Color(0xFF8FB2FF);

  /// Karta „Nowy rekord!” — ciepły gradient pod złotem [AppColors.record].
  static const recordCardStart = Color(0xFF3A2A0E);
  static const recordCardEnd = Color(0xFF1E1A12);
  static const recordText = Color(0xFFD9C391);
}
