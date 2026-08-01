import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';

/// Jedna metryka rzędu: ikona + wartość nad etykietą.
class SessionMetricSpec {
  const SessionMetricSpec({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;
}

/// Rząd metryk sesji (czas / ćwiczenia / serie / objętość) z ikonami i
/// pionowymi separatorami — używany zarówno w nagłówku szczegółów sesji, jak
/// i w wierszach listy historii, żeby oba miejsca wyglądały identycznie.
class SessionMetricsRow extends StatelessWidget {
  const SessionMetricsRow({super.key, required this.entries});

  final List<SessionMetricSpec> entries;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < entries.length; i++) {
      if (i != 0) children.add(const _MetricDivider());
      children.add(_Metric(spec: entries[i]));
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.spec});

  final SessionMetricSpec spec;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(spec.icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    spec.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  Text(
                    spec.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: AppColors.border.withValues(alpha: 0.35),
    );
  }
}
