import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Akcent planu treningowego — ten sam plan ma ten sam kolor na każdym
/// ekranie (trening, historia, kalendarz).
///
/// Nazwy w stylu Push / Pull / Legs (także po polsku) dostają stałe kolory,
/// reszta trafia do palety po stabilnym haszu nazwy, więc kolor nie zmienia
/// się między uruchomieniami ani urządzeniami.
abstract final class PlanColors {
  static const palette = [
    AppColors.planPush,
    AppColors.planPull,
    AppColors.planLegs,
    AppColors.planBlue,
    AppColors.planPink,
    AppColors.planAmber,
  ];

  /// Kolor sesji bez planu (trening „z ręki”).
  static const none = AppColors.planBlue;

  static Color of(String? planName) {
    final name = planName?.trim().toLowerCase() ?? '';
    if (name.isEmpty) return none;
    if (_matches(name, const ['push', 'pchanie', 'klatka'])) {
      return AppColors.planPush;
    }
    if (_matches(name, const ['pull', 'ciągnięcie', 'ciagniecie', 'plecy'])) {
      return AppColors.planPull;
    }
    if (_matches(name, const ['leg', 'nogi', 'nóg', 'nog'])) {
      return AppColors.planLegs;
    }
    return palette[_fnv1a(name) % palette.length];
  }

  static bool _matches(String name, List<String> keywords) =>
      keywords.any(name.contains);

  // `String.hashCode` nie jest gwarantowanie stabilny między platformami.
  static int _fnv1a(String text) {
    var hash = 0x811c9dc5;
    for (final unit in text.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash;
  }
}
