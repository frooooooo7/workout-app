import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'sync_status_indicator.dart';

/// Nagłówek zakładki głównej (Historia, Plany, Trening, Aktywność, Profil,
/// Biblioteka): tytuł po lewej, akcje-kafelki i wskaźnik synchronizacji po
/// prawej. Jeden wzór dla całej aplikacji — ekrany szczegółów używają
/// `AppHeader`.
class AppTabHeader extends StatelessWidget {
  const AppTabHeader({
    super.key,
    required this.title,
    this.leading,
    this.actions = const [],
    this.showSync = true,
    this.gutter = AppSpacing.pageGutter,
  });

  final String title;

  /// Np. [AppTabHeaderButton.back] na podstronie.
  final Widget? leading;

  /// Kafelki akcji ([AppTabHeaderButton]) przed wskaźnikiem synchronizacji.
  final List<Widget> actions;

  final bool showSync;

  /// Poziomy margines — taki sam jak treści zakładki, żeby tytuł i karty
  /// zaczynały się w jednej linii.
  final double gutter;

  static const height = AppSpacing.minTapTarget;

  @override
  Widget build(BuildContext context) {
    final trailing = [
      ...actions,
      if (showSync) const SyncStatusIndicator(size: AppSpacing.minTapTarget),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(
        gutter,
        AppSpacing.sm,
        gutter,
        AppSpacing.xs,
      ),
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ),
            for (final widget in trailing) ...[
              const SizedBox(width: AppSpacing.xs),
              widget,
            ],
          ],
        ),
      ),
    );
  }
}

/// Kafelek 44 px w [AppTabHeader] — ta sama forma co [SyncStatusIndicator].
/// [accent] wypełnia go kolorem głównym (akcja „dodaj”).
class AppTabHeaderButton extends StatelessWidget {
  const AppTabHeaderButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.accent = false,
  });

  /// Przycisk „Wstecz” na podstronach.
  const AppTabHeaderButton.back({super.key, required this.onPressed})
    : icon = Icons.arrow_back_rounded,
      tooltip = 'Wstecz',
      accent = false;

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: accent ? 24 : 21),
      color: accent ? AppColors.onPrimary : AppColors.textSecondary,
      style: IconButton.styleFrom(
        backgroundColor: accent ? AppColors.primary : AppColors.surface,
        fixedSize: const Size.square(AppSpacing.minTapTarget),
        minimumSize: const Size.square(AppSpacing.minTapTarget),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: accent
              ? BorderSide.none
              : const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}

/// Granatowa poświata u góry zakładki, przechodząca w [AppColors.background].
/// Owija treść ekranu, więc każda zakładka ma to samo tło.
class AppTabBackground extends StatelessWidget {
  const AppTabBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 360,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.heroGlow, AppColors.background],
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}
