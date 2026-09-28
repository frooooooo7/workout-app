import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Pozycja arkusza akcji ([showAppActionSheet]).
class AppSheetAction<T> {
  const AppSheetAction({
    required this.value,
    required this.icon,
    required this.label,
    this.subtitle,
    this.destructive = false,
    this.enabled = true,
    this.selected = false,
  });

  final T value;
  final IconData icon;
  final String label;
  final String? subtitle;

  /// Czerwona pozycja (usuwanie) — zawsze na dole listy.
  final bool destructive;
  final bool enabled;

  /// Aktualnie wybrana opcja (arkusze wyboru, np. sortowania).
  final bool selected;
}

/// Dolny arkusz z listą akcji — wspólny wygląd menu „więcej” w aplikacji.
/// Zwraca [AppSheetAction.value] wybranej pozycji albo `null` po zamknięciu.
Future<T?> showAppActionSheet<T>(
  BuildContext context, {
  String? title,
  Widget? header,
  required List<AppSheetAction<T>> actions,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: AppColors.surface,
    barrierColor: Colors.black54,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
    ),
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xs,
          AppSpacing.sm,
          AppSpacing.xs,
          AppSpacing.xs,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (header != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  0,
                  AppSpacing.sm,
                  AppSpacing.sm,
                ),
                child: header,
              )
            else if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  0,
                  AppSpacing.sm,
                  AppSpacing.xs,
                ),
                child: Text(
                  title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            for (final action in actions)
              _ActionTile<T>(
                action: action,
                onTap: () => Navigator.of(sheetContext).pop(action.value),
              ),
          ],
        ),
      ),
    ),
  );
}

class _ActionTile<T> extends StatelessWidget {
  const _ActionTile({required this.action, required this.onTap});

  final AppSheetAction<T> action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = !action.enabled
        ? AppColors.textMuted
        : action.destructive
        ? AppColors.strengthWeak
        : AppColors.textPrimary;
    final iconColor = !action.enabled
        ? AppColors.textMuted
        : action.destructive
        ? AppColors.strengthWeak
        : AppColors.primaryVariant;

    return Material(
      color: action.selected
          ? AppColors.primary.withValues(alpha: 0.1)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: action.enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        splashColor: iconColor.withValues(alpha: 0.08),
        highlightColor: iconColor.withValues(alpha: 0.05),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: iconColor.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Icon(action.icon, size: 19, color: iconColor),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        action.label,
                        style: TextStyle(
                          color: color,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (action.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          action.subtitle!,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (action.selected) ...[
                  const SizedBox(width: AppSpacing.xs),
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 20,
                    color: AppColors.primary,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Potwierdzenie nieodwracalnej akcji (usuwanie). Zwraca `true` tylko po
/// świadomym „[confirmLabel]”.
Future<bool> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Usuń',
  bool destructive = true,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Text(
        message,
        style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Anuluj'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(
            confirmLabel,
            style: TextStyle(
              color: destructive ? AppColors.strengthWeak : AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
