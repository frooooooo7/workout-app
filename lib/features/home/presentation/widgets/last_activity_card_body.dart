import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/last_activity.dart';

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
          _LastActivityThumbnail(exerciseCount: activity.exerciseCount),
          const SizedBox(width: 14),
          Expanded(child: LastActivityStatsColumn(activity: activity)),
        ],
      ),
    );
  }
}

class _LastActivityThumbnail extends StatelessWidget {
  const _LastActivityThumbnail({required this.exerciseCount});

  final int exerciseCount;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 130,
        height: 140,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.35),
                AppColors.primary.withValues(alpha: 0.08),
                const Color(0xFF0D1117),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -8,
                bottom: -12,
                child: Icon(
                  Icons.fitness_center_rounded,
                  size: 88,
                  color: AppColors.primary.withValues(alpha: 0.18),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.35),
                        ),
                      ),
                      child: const Icon(
                        Icons.fitness_center_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$exerciseCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Text(
                      'ćwiczeń',
                      style: TextStyle(
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

class LastActivityTitleRow extends StatelessWidget {
  const LastActivityTitleRow({super.key, required this.activity});

  final LastActivity activity;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFF6C8EFF).withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.fitness_center_rounded,
            color: Color(0xFF6C8EFF),
            size: 17,
          ),
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
    final stats = [
      _StatItem(value: activity.durationLabel, label: 'Czas'),
      _StatItem(
        value: '${_fmtVolume(activity.volumeKg)} kg',
        label: 'Objętość',
      ),
      _StatItem(value: '${activity.caloriesKcal}', label: 'Kalorie'),
    ];

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
