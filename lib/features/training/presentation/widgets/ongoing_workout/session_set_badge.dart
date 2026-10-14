import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../domain/models/set_type.dart';
import '../set_type_badge.dart';
import 'workout_colors.dart';
import 'workout_accent.dart';

/// Numer serii (albo litera rodzaju: W, F, D) w wierszu treningu na żywo.
/// Zrobiona seria jest zielona, następna do zrobienia — niebieska.
/// Dotknięcie zmienia rodzaj serii.
class SessionSetBadge extends StatelessWidget {
  const SessionSetBadge({
    super.key,
    required this.label,
    required this.type,
    required this.completed,
    required this.active,
    required this.onTap,
  });

  final String label;
  final SetType type;
  final bool completed;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = setTypeColor(type);
    final highlight = WorkoutAccent.of(context);
    final (Color background, Color foreground) = accent != null
        ? (accent.withValues(alpha: 0.16), accent)
        : completed
        ? (AppColors.success.withValues(alpha: 0.16), AppColors.success)
        : active
        ? (highlight.fill, highlight.onFill)
        : (WorkoutColors.chip, AppColors.textSecondary);
    return Semantics(
      button: true,
      label: 'Rodzaj serii: ${type.label}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: accent != null ? 12 : 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
