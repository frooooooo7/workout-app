import 'package:flutter/foundation.dart';
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
///
/// Poświata przewija się razem z treścią (śledzi pionowe przewijanie
/// potomków), więc karty nie „wjeżdżają” w nieruchomą niebieską plamę.
/// Stan przewinięcia udostępnia [AppTabScrollEdge].
class AppTabBackground extends StatefulWidget {
  const AppTabBackground({super.key, required this.child});

  final Widget child;

  static const glowHeight = 360.0;

  /// `true`, gdy treść zakładki jest przewinięta poniżej początku.
  static ValueListenable<bool>? scrolledOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_TabScrollScope>()
      ?.scrolled;

  @override
  State<AppTabBackground> createState() => _AppTabBackgroundState();
}

class _AppTabBackgroundState extends State<AppTabBackground> {
  final _offset = ValueNotifier<double>(0);
  final _scrolled = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _offset.dispose();
    _scrolled.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification notification) {
    final metrics = notification.metrics;
    if (metrics.axis != Axis.vertical) return false;
    final pixels = metrics.pixels - metrics.minScrollExtent;
    _offset.value = pixels.clamp(0, AppTabBackground.glowHeight);
    _scrolled.value = pixels > 0.5;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: _TabScrollScope(
        scrolled: _scrolled,
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: AppTabBackground.glowHeight,
              child: IgnorePointer(
                child: ValueListenableBuilder<double>(
                  valueListenable: _offset,
                  builder: (context, offset, child) => Transform.translate(
                    offset: Offset(0, -offset),
                    child: child,
                  ),
                  child: const DecoratedBox(
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
            ),
            Positioned.fill(child: widget.child),
          ],
        ),
      ),
    );
  }
}

class _TabScrollScope extends InheritedWidget {
  const _TabScrollScope({required this.scrolled, required super.child});

  final ValueListenable<bool> scrolled;

  @override
  bool updateShouldNotify(_TabScrollScope oldWidget) =>
      scrolled != oldWidget.scrolled;
}

/// Linia na górnej krawędzi przewijanej treści — pojawia się dopiero, gdy
/// coś jest pod nią przewinięte. Wstawiana tuż nad obszarem przewijania,
/// pod stałymi elementami zakładki (nagłówek, wyszukiwarka, pasek miesięcy).
class AppTabScrollEdge extends StatelessWidget {
  const AppTabScrollEdge({super.key});

  @override
  Widget build(BuildContext context) {
    final scrolled = AppTabBackground.scrolledOf(context);
    if (scrolled == null) return const SizedBox(height: 1);
    return ValueListenableBuilder<bool>(
      valueListenable: scrolled,
      builder: (context, isScrolled, _) => AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        height: 1,
        color: isScrolled
            ? AppColors.border.withValues(alpha: 0.9)
            : AppColors.border.withValues(alpha: 0),
      ),
    );
  }
}
