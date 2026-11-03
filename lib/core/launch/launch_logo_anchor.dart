import 'package:flutter/widgets.dart';

import 'app_launch_controller.dart';
import 'app_launch_scope.dart';

/// Oznacza logo w karcie logowania: ekran ładowania „leci” z logo właśnie
/// tam (pierwsze uruchomienie, start po wylogowaniu).
class LaunchLogoAnchor extends StatefulWidget {
  const LaunchLogoAnchor({super.key, required this.child});

  final Widget child;

  @override
  State<LaunchLogoAnchor> createState() => _LaunchLogoAnchorState();
}

class _LaunchLogoAnchorState extends State<LaunchLogoAnchor> {
  AppLaunchController? _launch;
  Rect? Function()? _provider;

  @override
  void initState() {
    super.initState();
    _launch = AppLaunchScope.maybeOf(context);
    _provider = _currentRect;
    _launch?.loginLogoRect = _provider;
  }

  @override
  void dispose() {
    if (_launch?.loginLogoRect == _provider) _launch?.loginLogoRect = null;
    super.dispose();
  }

  Rect? _currentRect() {
    if (!mounted) return null;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
