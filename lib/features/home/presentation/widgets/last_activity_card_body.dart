import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/last_activity.dart';
import '../../domain/models/recent_activity.dart';
import 'last_activity_map_placeholder.dart';

class LastActivityCardBody extends StatelessWidget {
  const LastActivityCardBody({super.key, required this.activity});

  final LastActivity activity;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LastActivityMapPlaceholder(),
          const SizedBox(width: 14),
          Expanded(child: LastActivityStatsColumn(activity: activity)),
        ],
      ),
    );
  }
}

class LastActivityStatsColumn extends StatelessWidget {
  const LastActivityStatsColumn({super.key, required this.activity});

  final LastActivity activity;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LastActivityTitleRow(activity: activity),
        const SizedBox(height: 12),
        LastActivityStatGrid(activity: activity),
        const SizedBox(height: 14),
        LastActivityDetailButton(onTap: () {}),
      ],
    );
  }
}

class _KindVisual {
  const _KindVisual({required this.icon, required this.color});

  final IconData icon;
  final Color color;
}

_KindVisual _visualFor(RecentActivityKind kind) => switch (kind) {
      RecentActivityKind.strength => const _KindVisual(
          icon: Icons.fitness_center_rounded,
          color: Color(0xFF6C8EFF),
        ),
      RecentActivityKind.run => const _KindVisual(
          icon: Icons.directions_run_rounded,
          color: Color(0xFF4CAF7D),
        ),
      RecentActivityKind.cycling => const _KindVisual(
          icon: Icons.directions_bike_rounded,
          color: Color(0xFFFF9F43),
        ),
      RecentActivityKind.yoga => const _KindVisual(
          icon: Icons.self_improvement_rounded,
          color: Color(0xFFFF6B9D),
        ),
    };

class LastActivityTitleRow extends StatelessWidget {
  const LastActivityTitleRow({super.key, required this.activity});

  final LastActivity activity;

  @override
  Widget build(BuildContext context) {
    final v = _visualFor(activity.kind);
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: v.color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(v.icon, color: v.color, size: 17),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                activity.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              Text(
                '${activity.date} · ${activity.time}',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatItem {
  const _StatItem({required this.value, required this.label});

  final String value;
  final String label;
}

class LastActivityStatGrid extends StatelessWidget {
  const LastActivityStatGrid({super.key, required this.activity});

  final LastActivity activity;

  static String _fmtVolume(int kg) {
    if (kg >= 1000) {
      return '${(kg / 1000).toStringAsFixed(kg % 1000 == 0 ? 0 : 1).replaceAll('.', ',')}\u202F${(kg % 1000).toString().padLeft(3, '0')}';
    }
    return '$kg';
  }

  @override
  Widget build(BuildContext context) {
    final stats = switch (activity) {
      StrengthActivity s => [
          _StatItem(value: s.durationLabel, label: 'Czas'),
          _StatItem(
            value: '${_fmtVolume(s.volumeKg)} kg',
            label: 'Objętość',
          ),
          _StatItem(value: '${s.caloriesKcal}', label: 'Kalorie'),
        ],
      CardioActivity c => [
          _StatItem(value: c.durationLabel, label: 'Czas'),
          _StatItem(
            value:
                '${c.distanceKm.toStringAsFixed(1).replaceAll('.', ',')} km',
            label: 'Dystans',
          ),
          _StatItem(value: '${c.avgPulseBpm} bpm', label: 'Śr. puls'),
        ],
    };

    return Row(
      children: stats
          .map(
            (s) => Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    s.label,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class LastActivityDetailButton extends StatelessWidget {
  const LastActivityDetailButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
          ),
        ),
        alignment: Alignment.center,
        child: const Text(
          'Zobacz szczegóły',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
