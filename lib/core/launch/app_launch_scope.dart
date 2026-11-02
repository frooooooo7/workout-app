import 'package:flutter/widgets.dart';

import 'app_launch_controller.dart';

/// Udostępnia ekranom [AppLaunchController]. Poza aplikacją (testy, ekrany
/// bez nakładki) `maybeOf` zwraca `null` i wszystko działa jak bez ekranu
/// ładowania.
class AppLaunchScope extends InheritedWidget {
  const AppLaunchScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final AppLaunchController controller;

  static AppLaunchController? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppLaunchScope>()?.controller;

  @override
  bool updateShouldNotify(AppLaunchScope oldWidget) =>
      controller != oldWidget.controller;
}
