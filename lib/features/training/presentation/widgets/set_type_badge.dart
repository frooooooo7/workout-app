import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_action_sheet.dart';
import '../../domain/models/set_type.dart';

/// Kolor znaczka rodzaju serii; `null` dla zwykłej serii (bez akcentu).
Color? setTypeColor(SetType type) => switch (type) {
  SetType.normal => null,
  SetType.warmup => AppColors.strengthMedium,
  SetType.failure => AppColors.strengthWeak,
  SetType.drop => const Color(0xFFA78BFA),
};

/// Numer serii albo litera jej rodzaju (W / F / D). Z [onTap] jest przyciskiem
/// zmiany rodzaju serii; bez niego zwykłą etykietą (widoki tylko do odczytu).
class SetTypeBadge extends StatelessWidget {
  const SetTypeBadge({
    super.key,
    required this.label,
    required this.type,
    this.completed = false,
    this.onTap,
  });

  final String label;
  final SetType type;
  final bool completed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = setTypeColor(type);
    final color = completed ? AppColors.textMuted : (accent ?? Colors.white);
    final badge = Container(
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent?.withValues(alpha: completed ? 0.08 : 0.16),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      ),
    );
    if (onTap == null) return badge;
    return Semantics(
      button: true,
      label: 'Rodzaj serii: ${type.label}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: badge,
      ),
    );
  }
}

IconData _setTypeIcon(SetType type) => switch (type) {
  SetType.normal => Icons.fitness_center_rounded,
  SetType.warmup => Icons.local_fire_department_outlined,
  SetType.failure => Icons.bolt_rounded,
  SetType.drop => Icons.trending_down_rounded,
};

/// Arkusz wyboru rodzaju serii; `null`, gdy zamknięty bez wyboru.
Future<SetType?> showSetTypePicker(BuildContext context, SetType current) {
  return showAppActionSheet<SetType>(
    context,
    title: 'Rodzaj serii',
    actions: [
      for (final type in SetType.values)
        AppSheetAction<SetType>(
          value: type,
          icon: _setTypeIcon(type),
          label: type.label,
          subtitle: type.description,
          selected: type == current,
        ),
    ],
  );
}
