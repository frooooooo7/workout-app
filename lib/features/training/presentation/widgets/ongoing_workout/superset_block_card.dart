import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import 'workout_colors.dart';

/// Superseria na ekranie treningu: wspólna karta z literą grupy, rundą
/// i ćwiczeniami (A1, A2…) pod pomarańczowym paskiem.
class SupersetBlockCard extends StatelessWidget {
  const SupersetBlockCard({
    super.key,
    required this.group,
    required this.round,
    required this.totalRounds,
    required this.members,
  });

  final String group;
  final int round;
  final int totalRounds;

  /// Karty ćwiczeń grupy, w kolejności planu.
  final List<Widget> members;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.superset.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SupersetChip(group: group),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'na zmianę, bez przerwy',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Semantics(
                label: 'Runda $round z $totalRounds',
                excludeSemantics: true,
                child: Text.rich(
                  key: const ValueKey('superset-round-label'),
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Runda $round',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      TextSpan(text: ' z $totalRounds'),
                    ],
                  ),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: AppColors.superset, width: 3),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < members.length; i++) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 26,
                          height: 44,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '$group${i + 1}',
                              style: const TextStyle(
                                color: AppColors.superset,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        Expanded(child: members[i]),
                      ],
                    ),
                    if (i < members.length - 1)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(26, 10, 0, 12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.arrow_downward_rounded,
                              size: 14,
                              color: AppColors.textMuted,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'od razu',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Znaczek „SUPERSERIA A” — na treningu i w edycji planu.
class SupersetChip extends StatelessWidget {
  const SupersetChip({super.key, required this.group});

  final String group;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.superset.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'SUPERSERIA $group',
        style: const TextStyle(
          color: AppColors.superset,
          fontSize: 11.5,
          letterSpacing: 0.6,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Panel „Bez przerwy” w miejscu odpoczynku: w superserii po serii A1
/// od razu A2, przerwa dopiero po rundzie.
class SupersetNextPill extends StatelessWidget {
  const SupersetNextPill({
    super.key,
    required this.caption,
    required this.restAfterRound,
  });

  /// „Teraz: A2 · Wznosy bokiem, seria 2”.
  final String caption;

  /// „po rundzie przerwa 1:30”; `null`, gdy nie wiadomo.
  final String? restAfterRound;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('superset-next-pill'),
      height: 92,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: WorkoutColors.restPanel,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.superset.withValues(alpha: 0.16),
              border: Border.all(
                color: AppColors.superset.withValues(alpha: 0.55),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.arrow_forward_rounded,
              color: AppColors.superset,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Bez przerwy',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: WorkoutColors.textSoft,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (restAfterRound != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    restAfterRound!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: WorkoutColors.textFaint,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
