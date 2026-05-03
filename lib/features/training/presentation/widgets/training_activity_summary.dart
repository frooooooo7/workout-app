import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

// ──────────────────────────────────────────────
// Models
// ──────────────────────────────────────────────

enum _Period { week, month }

class _StatData {
  const _StatData({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.unit,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String unit;
  final String label;
}

// ──────────────────────────────────────────────
// Mock data
// ──────────────────────────────────────────────

const _weekStats = _SummaryStats(
  workouts: 3,
  durationH: 3,
  durationMin: 40,
  sets: 48,
  reps: 386,
  volumeKg: 4720,
  distanceKm: 12.4,
  caloriesKcal: 1840,
);

const _monthStats = _SummaryStats(
  workouts: 12,
  durationH: 14,
  durationMin: 55,
  sets: 192,
  reps: 1544,
  volumeKg: 18960,
  distanceKm: 47.2,
  caloriesKcal: 7360,
);

class _SummaryStats {
  const _SummaryStats({
    required this.workouts,
    required this.durationH,
    required this.durationMin,
    required this.sets,
    required this.reps,
    required this.volumeKg,
    required this.distanceKm,
    required this.caloriesKcal,
  });

  final int workouts;
  final int durationH;
  final int durationMin;
  final int sets;
  final int reps;
  final int volumeKg;
  final double distanceKm;
  final int caloriesKcal;
}

// ──────────────────────────────────────────────
// Public widget
// ──────────────────────────────────────────────

class TrainingActivitySummary extends StatefulWidget {
  const TrainingActivitySummary({super.key});

  @override
  State<TrainingActivitySummary> createState() =>
      _TrainingActivitySummaryState();
}

class _TrainingActivitySummaryState extends State<TrainingActivitySummary> {
  _Period _period = _Period.week;

  _SummaryStats get _stats =>
      _period == _Period.week ? _weekStats : _monthStats;

  static String _formatVolume(int kg) {
    if (kg >= 1000) {
      final thousands = kg ~/ 1000;
      final remainder = (kg % 1000).toString().padLeft(3, '0');
      return '$thousands\u2009$remainder';
    }
    return '$kg';
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;

    final topRow = [
      _StatData(
        icon: Icons.fitness_center_rounded,
        iconColor: const Color(0xFF6C8EFF),
        value: '${stats.workouts}',
        unit: stats.workouts == 1 ? 'trening' : (stats.workouts <= 4 ? 'treningi' : 'treningów'),
        label: 'Sesje',
      ),
      _StatData(
        icon: Icons.timer_rounded,
        iconColor: const Color(0xFFFF6B35),
        value: '${stats.durationH}h ${stats.durationMin}min',
        unit: '',
        label: 'Czas aktywności',
      ),
    ];

    final middleRow = [
      _StatData(
        icon: Icons.format_list_numbered_rounded,
        iconColor: AppColors.primaryVariant,
        value: '${stats.sets}',
        unit: 'serii',
        label: 'Serie',
      ),
      _StatData(
        icon: Icons.repeat_rounded,
        iconColor: const Color(0xFF4DB6AC),
        value: '${stats.reps}',
        unit: 'powt.',
        label: 'Powtórzenia',
      ),
      _StatData(
        icon: Icons.monitor_weight_rounded,
        iconColor: const Color(0xFFF59E0B),
        value: _formatVolume(stats.volumeKg),
        unit: 'kg',
        label: 'Łączny ciężar',
      ),
    ];

    final bottomRow = [
      _StatData(
        icon: Icons.directions_run_rounded,
        iconColor: AppColors.success,
        value: stats.distanceKm.toStringAsFixed(1).replaceAll('.', ','),
        unit: 'km',
        label: 'Dystans',
      ),
      _StatData(
        icon: Icons.local_fire_department_rounded,
        iconColor: const Color(0xFFFF6B35),
        value: _formatVolume(stats.caloriesKcal),
        unit: 'kcal',
        label: 'Spalone kalorie',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Podsumowanie aktywności',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            GestureDetector(
              onTap: () {},
              child: const Row(
                children: [
                  Text(
                    'Historia',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Card body
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Period toggle
              _PeriodToggle(
                selected: _period,
                onChanged: (p) => setState(() => _period = p),
              ),
              const SizedBox(height: 16),

              // Top row — 2 wide tiles
              Row(
                children: topRow
                    .map(
                      (s) => Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: s == topRow.last ? 0 : 8,
                          ),
                          child: _SummaryTile(stat: s, compact: false),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 8),

              // Middle row — 3 compact tiles
              Row(
                children: middleRow
                    .map(
                      (s) => Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: s == middleRow.last ? 0 : 8,
                          ),
                          child: _SummaryTile(stat: s, compact: true),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 8),

              // Bottom row — 2 wide tiles
              Row(
                children: bottomRow
                    .map(
                      (s) => Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: s == bottomRow.last ? 0 : 8,
                          ),
                          child: _SummaryTile(stat: s, compact: false),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────
// Period toggle
// ──────────────────────────────────────────────

class _PeriodToggle extends StatelessWidget {
  const _PeriodToggle({
    required this.selected,
    required this.onChanged,
  });

  final _Period selected;
  final ValueChanged<_Period> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: _Period.values
            .map((p) => _PeriodOption(
                  period: p,
                  isSelected: p == selected,
                  onTap: () => onChanged(p),
                ))
            .toList(),
      ),
    );
  }
}

class _PeriodOption extends StatelessWidget {
  const _PeriodOption({
    required this.period,
    required this.isSelected,
    required this.onTap,
  });

  final _Period period;
  final bool isSelected;
  final VoidCallback onTap;

  String get _label => switch (period) {
        _Period.week => 'Tydzień',
        _Period.month => 'Miesiąc',
      };

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border.all(color: AppColors.border)
                : null,
          ),
          alignment: Alignment.center,
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              color: isSelected ? Colors.white : AppColors.textSecondary,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
            child: Text(_label),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Stat tile
// ──────────────────────────────────────────────

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.stat,
    required this.compact,
  });

  final _StatData stat;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon circle
          Container(
            width: compact ? 28 : 32,
            height: compact ? 28 : 32,
            decoration: BoxDecoration(
              color: stat.iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              stat.icon,
              color: stat.iconColor,
              size: compact ? 14 : 16,
            ),
          ),
          SizedBox(height: compact ? 8 : 10),

          // Value
          Text(
            stat.value,
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 16 : 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          // Unit
          if (stat.unit.isNotEmpty) ...[
            const SizedBox(height: 1),
            Text(
              stat.unit,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],

          const SizedBox(height: 2),

          // Label
          Text(
            stat.label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w400,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
