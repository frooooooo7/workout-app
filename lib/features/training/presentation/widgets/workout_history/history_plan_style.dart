import 'package:flutter/material.dart';

import '../../../../../core/theme/plan_colors.dart';
import '../../../domain/models/training_history_models.dart';

/// Kolory planu sesji w Historii: kropka legendy, podbarwione tło dnia
/// w kalendarzu i odznaka (ikona albo litera) na liście — z [PlanColors.of].
class HistoryPlanStyle {
  HistoryPlanStyle._(this.name, this.color, this.iconKey);

  factory HistoryPlanStyle.of(TrainingSessionListItem session) {
    final name = session.plan.name.trim();
    return HistoryPlanStyle._(
      name.isEmpty ? 'Trening siłowy' : name,
      PlanColors.of(name, colorKey: session.plan.colorKey),
      PlanColors.styles.iconKeyFor(name) ?? session.plan.iconKey,
    );
  }

  /// Ikona wybrana w planie; `null` — odznaka z literą.
  final String? iconKey;

  /// Nazwa do wyświetlenia (sesja bez nazwy planu to „Trening siłowy”).
  final String name;

  /// Akcent planu.
  final Color color;

  /// Jaśniejszy odcień akcentu — tekst na podbarwionym tle.
  Color get onTint => Color.lerp(color, Colors.white, 0.3)!;

  /// Podbarwione tło (dzień w kalendarzu, odznaka planu).
  Color tint(double alpha) => color.withValues(alpha: alpha);

  /// Pierwsza litera nazwy planu na odznace.
  String get letter => name.characters.first.toUpperCase();
}
