import 'package:flutter/material.dart';

import 'app_spacing.dart';
import 'plan_colors.dart';

/// Ikony do wyboru jako znak planu, po kluczu zapisywanym w API
/// (`training_plans.icon_key`). Bez wyboru znakiem jest pierwsza litera.
abstract final class PlanIcons {
  static const choices = <String, IconData>{
    'dumbbell': Icons.fitness_center_rounded,
    'bolt': Icons.bolt_rounded,
    'flame': Icons.local_fire_department_rounded,
    'heart': Icons.favorite_border_rounded,
    'target': Icons.track_changes_rounded,
    'mountain': Icons.landscape_rounded,
    'trophy': Icons.emoji_events_outlined,
    'runner': Icons.directions_run_rounded,
    'shield': Icons.shield_outlined,
    'star': Icons.star_border_rounded,
    'timer': Icons.timer_outlined,
    'moon': Icons.dark_mode_outlined,
  };

  static const labels = <String, String>{
    'dumbbell': 'Hantla',
    'bolt': 'Błyskawica',
    'flame': 'Płomień',
    'heart': 'Serce',
    'target': 'Cel',
    'mountain': 'Góra',
    'trophy': 'Puchar',
    'runner': 'Biegacz',
    'shield': 'Tarcza',
    'star': 'Gwiazda',
    'timer': 'Stoper',
    'moon': 'Księżyc',
  };

  /// Ikona planu [planName] (wybór z planu albo zapisany przy sesji).
  static IconData? of(String? planName, {String? iconKey}) =>
      choices[PlanColors.styles.iconKeyFor(planName) ?? iconKey];
}

/// Znak planu na podbarwionym kafelku: wybrana ikona albo pierwsza litera
/// nazwy — w historii, na karcie „Ostatnio” i w podglądzie planu.
class PlanBadge extends StatelessWidget {
  const PlanBadge({
    super.key,
    required this.name,
    required this.color,
    this.iconKey,
    this.size = 40,
    this.radius = AppRadius.md,
  });

  final String name;
  final Color color;

  /// Klucz ikony; `null` = pierwsza litera nazwy.
  final String? iconKey;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final icon = PlanIcons.choices[iconKey];
    final onTint = Color.lerp(color, Colors.white, 0.3)!;
    final trimmed = name.trim();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.17),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: icon != null
          ? Icon(icon, size: size * 0.5, color: color)
          : Text(
              trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase(),
              style: TextStyle(
                color: onTint,
                fontSize: size * 0.4,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }
}
