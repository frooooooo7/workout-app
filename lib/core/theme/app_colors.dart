import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xFF0A0D13);
  static const surface = Color(0xFF121722);
  static const surfaceGlass = Color(0xD9141824);
  static const surfaceVariant = Color(0xFF1A2130);
  static const primary = Color(0xFF2563EB);
  static const primaryVariant = Color(0xFF5B8DF6);
  static const onPrimary = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFFF5F7FB);
  static const textSecondary = Color(0xFF8A94A8);
  static const textMuted = Color(0xFF5E687C);
  static const border = Color(0xFF1F2635);
  static const success = Color(0xFF34D399);

  /// Złoto rekordów (PR, „do pobicia”).
  static const record = Color(0xFFF5B83D);

  /// Kafelek-przycisk w nagłówku (Wstecz, akcje) i jego krawędź.
  static const tile = Color(0xFF151A25);
  static const borderStrong = Color(0xFF232B3B);
  static const iconOnTile = Color(0xFFC9D1E0);

  static const strengthWeak = Color(0xFFEF4444);
  static const strengthMedium = Color(0xFFF59E0B);
  static const strengthStrong = Color(0xFF22C55E);

  static const gradientTop = Color(0xFF0A0D13);
  static const gradientHero = Color(0xFF141B28);

  /// Granatowa poświata u góry nagłówka profilu (przechodzi w [background]).
  static const heroGlow = Color(0xFF15254A);

  // ── Statystyki i wykresy ───────────────────────
  // Akcenty kafelków i serii danych. Jeden kolor = jedna miara na całym
  // ekranie (np. czas zawsze pomarańczowy), żeby wykres i kafelek się łączyły.
  static const statIndigo = Color(0xFF6C8EFF);
  static const statOrange = Color(0xFFFF8A4C);
  static const statTeal = Color(0xFF2DD4BF);
  static const statAmber = Color(0xFFF59E0B);
  static const statPink = Color(0xFFF472B6);

  /// Zmiana na plus / na minus względem poprzedniego okresu.
  static const trendUp = Color(0xFF34D399);
  static const trendDown = Color(0xFFF87171);

  /// Linie siatki wykresów — ciszej niż [border].
  static const chartGrid = Color(0xFF222B3A);

  /// Pusta kratka heatmapy i tor pasków.
  static const chartTrack = Color(0xFF1A2030);

  // ── Kolory planów ───────────────────────────────
  // Każdy plan ma własny akcent (karta „na dziś”, kalendarz historii, lista
  // sesji). Wybór koloru: [PlanColors.of].
  static const planPush = Color(0xFFFF8A4C);
  static const planPull = Color(0xFF2DD4BF);
  static const planLegs = Color(0xFFA78BFA);
  static const planBlue = Color(0xFF5B8DF6);
  static const planPink = Color(0xFFF472B6);
  static const planAmber = Color(0xFFF5B83D);
}
