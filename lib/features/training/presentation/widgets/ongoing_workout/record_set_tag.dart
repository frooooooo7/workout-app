import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import 'workout_colors.dart';

/// Złoty znaczek „Rekord!” na serii, która pobiła rekord ćwiczenia.
/// Wskakuje sprężyście (elasticOut) przy pojawieniu się.
class RecordSetTag extends StatelessWidget {
  const RecordSetTag({super.key});

  @override
  Widget build(BuildContext context) {
    final tag = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.record,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: AppColors.record.withValues(alpha: 0.35),
            blurRadius: 8,
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.emoji_events_rounded,
            size: 11,
            color: WorkoutColors.recordCardStart,
          ),
          SizedBox(width: 3),
          Text(
            'Rekord!',
            style: TextStyle(
              color: WorkoutColors.recordCardStart,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
    if (MediaQuery.disableAnimationsOf(context)) return tag;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: tag,
    );
  }
}
