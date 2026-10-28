import 'package:flutter/widgets.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/plan_colors.dart';
import '../../../domain/models/progression_settings.dart';

/// Kolor zaznaczenia na ekranie treningu: aktywna seria, check, przerwa.
///
/// Domyślnie niebieski aplikacji; plan z włączonym „Zaznaczenie w kolorze
/// planu” podmienia go na swój kolor.
@immutable
class WorkoutAccent {
  const WorkoutAccent({
    required this.fill,
    required this.strong,
    required this.onFill,
  });

  /// Kolor planu jako zaznaczenie.
  factory WorkoutAccent.plan(Color color) => WorkoutAccent(
    fill: color,
    strong: color,
    onFill: PlanColors.onAccent(color),
  );

  static const standard = WorkoutAccent(
    fill: AppColors.primary,
    strong: AppColors.primaryVariant,
    onFill: AppColors.onPrimary,
  );

  /// Wypełnienia (znaczek aktywnej serii, przycisk „Pomiń”, tło wiersza).
  final Color fill;

  /// Obrysy, pierścień przerwy i tekst na ciemnym tle.
  final Color strong;

  /// Tekst i ikony na [fill].
  final Color onFill;

  static WorkoutAccent of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<WorkoutAccentScope>()
          ?.accent ??
      standard;

  @override
  bool operator ==(Object other) =>
      other is WorkoutAccent &&
      other.fill == fill &&
      other.strong == strong &&
      other.onFill == onFill;

  @override
  int get hashCode => Object.hash(fill, strong, onFill);
}

class WorkoutAccentScope extends InheritedWidget {
  const WorkoutAccentScope({
    super.key,
    required this.accent,
    this.progression = ProgressionSettings.off,
    required super.child,
  });

  final WorkoutAccent accent;

  /// Metoda progresji treningu (planu albo konta).
  final ProgressionSettings progression;

  static ProgressionSettings progressionOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<WorkoutAccentScope>()
          ?.progression ??
      ProgressionSettings.off;

  @override
  bool updateShouldNotify(WorkoutAccentScope oldWidget) =>
      accent != oldWidget.accent || progression != oldWidget.progression;
}
