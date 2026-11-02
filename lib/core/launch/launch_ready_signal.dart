import 'package:flutter/widgets.dart';

import 'app_launch_controller.dart';
import 'app_launch_scope.dart';

/// Docelowy ekran startu zgłasza nim nakładce ładowania: „jestem zbudowany”
/// (od tego liczy się limit czekania) i „mam dane” ([ready]).
///
/// Gotowość zgłasza po narysowaniu klatki z danymi, więc nakładka nie
/// znika przed tym, jak ekran pod nią jest faktycznie widoczny.
class LaunchReadySignal extends StatefulWidget {
  const LaunchReadySignal({
    super.key,
    required this.target,
    required this.ready,
    required this.child,
  });

  final LaunchTarget target;
  final bool ready;
  final Widget child;

  @override
  State<LaunchReadySignal> createState() => _LaunchReadySignalState();
}

class _LaunchReadySignalState extends State<LaunchReadySignal> {
  AppLaunchController? _launch;
  bool _reported = false;

  @override
  void initState() {
    super.initState();
    _launch = AppLaunchScope.maybeOf(context);
    _launch?.attach(widget.target);
    _reportWhenReady();
  }

  @override
  void didUpdateWidget(LaunchReadySignal oldWidget) {
    super.didUpdateWidget(oldWidget);
    _reportWhenReady();
  }

  void _reportWhenReady() {
    final launch = _launch;
    if (launch == null || _reported || !widget.ready) return;
    _reported = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      launch.markReady(widget.target);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
