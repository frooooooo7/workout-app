/// Siatka odstępów (co 4 px) — zamiast liczb wpisywanych w widgetach.
abstract final class AppSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  /// Poziomy margines ekranu (lewa/prawa krawędź treści).
  static const pageGutter = md;

  /// Minimalny rozmiar celu dotyku.
  static const minTapTarget = 44.0;
}

/// Promienie zaokrągleń.
abstract final class AppRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const card = 24.0;
  static const pill = 999.0;
}
