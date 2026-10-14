import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

const notificationBellKey = Key('notification-bell');
const notificationBellBadgeKey = Key('notification-bell-badge');

/// `9+` powyżej dziewięciu — plakietka zostaje okrągła.
String formatUnreadBadge(int count) => count > 9 ? '9+' : '$count';

/// Dzwonek w nagłówku „Aktywności”. Plakietka wskakuje sprężyście, a gdy
/// licznik rośnie, dzwonek się kołysze.
class NotificationBellButton extends StatefulWidget {
  const NotificationBellButton({
    super.key,
    required this.count,
    required this.onPressed,
  });

  final ValueListenable<int> count;
  final VoidCallback onPressed;

  @override
  State<NotificationBellButton> createState() => _NotificationBellButtonState();
}

class _NotificationBellButtonState extends State<NotificationBellButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wiggle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  /// ±12°, wygaszane: 0 → +12 → −12 → +6 → 0.
  late final Animation<double> _angle = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0, end: 12), weight: 1),
    TweenSequenceItem(tween: Tween(begin: 12, end: -12), weight: 2),
    TweenSequenceItem(tween: Tween(begin: -12, end: 6), weight: 2),
    TweenSequenceItem(tween: Tween(begin: 6, end: 0), weight: 1),
  ]).animate(CurvedAnimation(parent: _wiggle, curve: Curves.easeOut));

  late int _last;

  /// Ostatnia niezerowa wartość — plakietka znika z nią, a nie z „0”.
  late int _shown = math.max(widget.count.value, 1);

  @override
  void initState() {
    super.initState();
    _last = widget.count.value;
    widget.count.addListener(_onCount);
  }

  @override
  void didUpdateWidget(NotificationBellButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.count != widget.count) {
      oldWidget.count.removeListener(_onCount);
      widget.count.addListener(_onCount);
      _last = widget.count.value;
    }
  }

  @override
  void dispose() {
    widget.count.removeListener(_onCount);
    _wiggle.dispose();
    super.dispose();
  }

  void _onCount() {
    final value = widget.count.value;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (value > _last && !reduceMotion) _wiggle.forward(from: 0);
    _last = value;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: widget.count,
      builder: (context, count, child) {
        if (count > 0) _shown = count;
        return Semantics(
          button: true,
          label: count == 0
              ? 'Powiadomienia'
              : 'Powiadomienia, nieprzeczytane: $count',
          excludeSemantics: true,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              child!,
              Positioned(
                top: -4,
                right: -4,
                child: IgnorePointer(
                  child: AnimatedScale(
                    key: notificationBellBadgeKey,
                    scale: count > 0 ? 1 : 0,
                    duration: const Duration(milliseconds: 240),
                    curve: count > 0 ? Curves.elasticOut : Curves.easeIn,
                    child: _Badge(label: formatUnreadBadge(_shown)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      child: IconButton(
        key: notificationBellKey,
        onPressed: widget.onPressed,
        tooltip: 'Powiadomienia',
        icon: AnimatedBuilder(
          animation: _angle,
          builder: (context, child) => Transform.rotate(
            angle: _angle.value * math.pi / 180,
            alignment: const Alignment(0, -0.85),
            child: child,
          ),
          child: const Icon(Icons.notifications_none_rounded, size: 22),
        ),
        color: AppColors.iconOnTile,
        style: IconButton.styleFrom(
          backgroundColor: AppColors.tile,
          fixedSize: const Size.square(AppSpacing.minTapTarget),
          minimumSize: const Size.square(AppSpacing.minTapTarget),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.tile),
            side: const BorderSide(color: AppColors.borderStrong),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.background, width: 2),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.onPrimary,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}
