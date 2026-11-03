import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';

/// Wspólna oprawa sekcji na ekranie szczegółów sesji: ta sama powierzchnia,
/// promień i nagłówek dla mapy mięśni, osi czasu i listy ćwiczeń.
class SessionSectionCard extends StatelessWidget {
  const SessionSectionCard({
    super.key,
    this.icon,
    this.title,
    required this.child,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 16),
  });

  /// Bez ikony tytuł zaczyna się od lewej krawędzi (statystyki). Bez tytułu
  /// nie ma nagłówka — treść stoi sama, a [trailing] ląduje nad nią.
  final IconData? icon;
  final String? title;
  final Widget child;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null || trailing != null) ...[
            LayoutBuilder(
              // Długi dopisek (albo duża czcionka) nie może wypchnąć tytułu:
              // zawija się w 2/3 szerokości zamiast przepełniać wiersz.
              builder: (context, constraints) => Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 17, color: AppColors.primary),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      title ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                  if (trailing != null)
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth * 0.66,
                      ),
                      child: trailing,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}
