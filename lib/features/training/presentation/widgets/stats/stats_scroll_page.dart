import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';

/// Przewijana kolumna z odświeżaniem pociągnięciem.
///
/// Kolumna zamiast ListView: ListView niszczy karty poza ekranem, więc po
/// powrocie traciłyby stan (wybrane ćwiczenie, zaznaczony dzień) i animowały
/// się od nowa. Kart na ekranie jest kilka — budujemy wszystkie.
class StatsScrollPage extends StatelessWidget {
  const StatsScrollPage({
    super.key,
    this.controller,
    required this.onRefresh,
    required this.children,
  });

  final ScrollController? controller;
  final Future<void> Function() onRefresh;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () {
        HapticFeedback.lightImpact();
        return onRefresh();
      },
      child: SingleChildScrollView(
        controller: controller,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.pageGutter,
          AppSpacing.xxs,
          AppSpacing.pageGutter,
          AppSpacing.xl + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}
