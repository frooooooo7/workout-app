import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xFF0B0E14);
  static const surface = Color(0xFF141820);
  static const surfaceGlass = Color(0xD9141824);
  static const surfaceVariant = Color(0xFF1E2433);
  static const primary = Color(0xFF2563EB);
  static const primaryVariant = Color(0xFF3B82F6);
  static const onPrimary = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF9CA3AF);
  static const textMuted = Color(0xFF6B7280);
  static const border = Color(0xFF2A3344);
  static const success = Color(0xFF22C55E);
  static const strengthWeak = Color(0xFFEF4444);
  static const strengthMedium = Color(0xFFF59E0B);
  static const strengthStrong = Color(0xFF22C55E);

  static const gradientTop = Color(0xFF0B0E14);
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
}
