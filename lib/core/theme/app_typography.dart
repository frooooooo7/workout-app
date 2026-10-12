import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Rodziny fontów i powtarzalne style tekstu.
///
/// Manrope to krój interfejsu (ustawiony w motywie), Barlow Condensed — duże
/// liczby: ciężary, czasy, liczniki. Liczby zawsze mają cyfry tabelaryczne,
/// żeby nie skakały przy zmianie wartości (licznik czasu, animowane sumy).
abstract final class AppFonts {
  static const ui = 'Manrope';
  static const numeric = 'Barlow Condensed';
}

abstract final class AppTextStyles {
  static const tabularFigures = [FontFeature.tabularFigures()];

  /// Duża liczba: `81,3`, `24:13`, `95`.
  static TextStyle number({
    double size = 28,
    FontWeight weight = FontWeight.w700,
    Color color = AppColors.textPrimary,
    double? height = 1,
  }) => TextStyle(
    fontFamily: AppFonts.numeric,
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    fontFeatures: tabularFigures,
  );

  /// Liczba w treści (Manrope) z cyframi tabelarycznymi.
  static TextStyle tabular(TextStyle base) =>
      base.copyWith(fontFeatures: tabularFigures);

  /// Nadtytuł nad nagłówkiem / etykieta sekcji: `CZWARTEK, 15 PAŹDZIERNIKA`.
  static const eyebrow = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.96,
    color: AppColors.textSecondary,
  );

  /// Tytuł zakładki (Trening, Historia, Profil…).
  static const screenTitle = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    color: AppColors.textPrimary,
    height: 1.15,
  );

  /// Tytuł karty / sekcji.
  static const cardTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.2,
    color: AppColors.textPrimary,
  );

  /// Drobny opis pod wartością.
  static const caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
  );
}
