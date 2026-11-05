import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_colors.dart';
import '../../features/training/domain/models/progression_settings.dart';

/// Akcent planu treningowego — ten sam plan ma ten sam kolor na każdym
/// ekranie (trening, historia, kalendarz).
///
/// Kolor wybrany w planie ([choices], klucz w `colorKey`) wygrywa. Bez
/// wyboru nazwy w stylu Push / Pull / Legs (także po polsku) dostają stałe
/// kolory, reszta trafia do palety po stabilnym haszu nazwy, więc kolor nie
/// zmienia się między uruchomieniami ani urządzeniami.
abstract final class PlanColors {
  static const palette = [
    AppColors.planPush,
    AppColors.planPull,
    AppColors.planLegs,
    AppColors.planBlue,
    AppColors.planPink,
    AppColors.planAmber,
  ];

  /// Kolory do wyboru w planie, po kluczu zapisywanym w API. Podobna
  /// jasność i nasycenie — ciemny tekst na każdym jest czytelny.
  static const choices = <String, Color>{
    'orange': AppColors.planPush,
    'amber': AppColors.planAmber,
    'lime': Color(0xFFA3E635),
    'green': Color(0xFF34D399),
    'teal': AppColors.planPull,
    'sky': Color(0xFF38BDF8),
    'blue': AppColors.planBlue,
    'indigo': Color(0xFF818CF8),
    'violet': AppColors.planLegs,
    'fuchsia': Color(0xFFE879F9),
    'pink': AppColors.planPink,
    'rose': Color(0xFFFB7185),
  };

  /// Nazwy kolorów do wyboru (podpis pod paletą i czytnik ekranu).
  static const choiceLabels = <String, String>{
    'orange': 'Pomarańcz',
    'amber': 'Bursztyn',
    'lime': 'Limonka',
    'green': 'Zieleń',
    'teal': 'Morski',
    'sky': 'Błękit',
    'blue': 'Niebieski',
    'indigo': 'Indygo',
    'violet': 'Fiolet',
    'fuchsia': 'Fuksja',
    'pink': 'Róż',
    'rose': 'Malina',
  };

  /// Kolor sesji bez planu (trening „z ręki”).
  static const none = AppColors.planBlue;

  /// Wybory z planów użytkownika (nazwa planu → klucz koloru i ikony),
  /// żeby historia i kalendarz, które znają tylko nazwę planu z sesji,
  /// rysowały go w wybranym kolorze. Uzupełnia go `TrainingPlansCubit`.
  static final styles = PlanStyleRegistry();

  /// Kolor planu o nazwie [planName]; [colorKey] — wybór zapisany przy
  /// sesji (plan mógł zostać usunięty), używany, gdy plan nie jest znany.
  static Color of(String? planName, {String? colorKey}) {
    final name = _normalize(planName);
    final chosen = choices[styles.colorKeyFor(name) ?? colorKey];
    if (chosen != null) return chosen;
    return automatic(planName);
  }

  /// Kolor dobierany z nazwy, bez wyboru użytkownika (opcja „Auto”).
  static Color automatic(String? planName) {
    final name = _normalize(planName);
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

  /// Kolor do rysowania na akcencie (tekst, ikona check) — ciemny odcień
  /// tego samego koloru, czytelny na każdym kolorze z palety.
  static Color onAccent(Color accent) =>
      Color.lerp(accent, const Color(0xFF05070B), 0.82)!;

  static String _normalize(String? planName) =>
      planName?.trim().toLowerCase() ?? '';

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

/// Wygląd i ustawienia treningu jednego planu — to, czego potrzebują
/// ekrany znające tylko nazwę planu z sesji (historia, trening na żywo).
@immutable
class PlanStyle {
  const PlanStyle({
    this.colorKey,
    this.iconKey,
    this.highlightPlanColor = true,
    this.showRir = true,
    this.showTempo = true,
    this.progression,
  });

  static const fallback = PlanStyle();

  final String? colorKey;
  final String? iconKey;
  final bool highlightPlanColor;
  final bool showRir;
  final bool showTempo;

  /// Metoda progresji planu; `null` = jak w ustawieniach konta.
  final ProgressionSettings? progression;

  @override
  bool operator ==(Object other) =>
      other is PlanStyle &&
      other.colorKey == colorKey &&
      other.iconKey == iconKey &&
      other.highlightPlanColor == highlightPlanColor &&
      other.showRir == showRir &&
      other.showTempo == showTempo &&
      other.progression == progression;

  @override
  int get hashCode => Object.hash(
    colorKey,
    iconKey,
    highlightPlanColor,
    showRir,
    showTempo,
    progression,
  );
}

/// Wygląd i ustawienia planów użytkownika, po znormalizowanej nazwie.
class PlanStyleRegistry extends ChangeNotifier {
  Map<String, PlanStyle> _byName = const {};

  String? colorKeyFor(String normalizedName) =>
      _byName[normalizedName]?.colorKey;

  String? iconKeyFor(String? planName) => styleFor(planName)?.iconKey;

  /// Wygląd planu o nazwie [planName]; `null`, gdy takiego planu nie ma.
  PlanStyle? styleFor(String? planName) =>
      _byName[planName?.trim().toLowerCase() ?? ''];

  /// Podmienia wybory; powiadamia tylko, gdy coś się zmieniło.
  void register(Iterable<({String name, PlanStyle style})> plans) {
    final next = <String, PlanStyle>{
      for (final plan in plans) plan.name.trim().toLowerCase(): plan.style,
    };
    if (mapEquals(next, _byName)) return;
    _byName = next;
    notifyListeners();
  }
}
