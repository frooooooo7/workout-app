import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/last_activity.dart';
import '../../domain/models/recent_activity.dart';

class LastActivityCard extends StatelessWidget {
  const LastActivityCard({super.key, required this.activity});

  final LastActivity activity;

  static LastActivity get mock => StrengthActivity(
        title: 'Trening siłowy',
        date: 'Dzisiaj',
        time: '18:32',
        durationLabel: '1:15:24',
        volumeKg: 6450,
        caloriesKcal: 532,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(activity: activity),
          _CardBody(activity: activity),
        ],
      ),
    );
  }
}

// ── Header row ────────────────────────────────────────────────────────────────

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.activity});

  final LastActivity activity;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Ostatnia aktywność',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          GestureDetector(
            onTap: () {},
            child: const Row(
              children: [
                Text(
                  'Zobacz wszystkie',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(width: 2),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.primary,
                  size: 16,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Body (map + stats) ────────────────────────────────────────────────────────

class _CardBody extends StatelessWidget {
  const _CardBody({required this.activity});

  final LastActivity activity;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _MapPlaceholder(),
          const SizedBox(width: 14),
          Expanded(child: _StatsColumn(activity: activity)),
        ],
      ),
    );
  }
}

// ── Map placeholder ───────────────────────────────────────────────────────────

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 130,
        height: 140,
        child: CustomPaint(
          painter: _MapRoutePainter(),
        ),
      ),
    );
  }
}

class _MapRoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Dark map background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF0D1117),
    );

    // Fake street grid
    final streetPaint = Paint()
      ..color = const Color(0xFF1C2333)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    final streets = [
      [Offset(0, size.height * 0.3), Offset(size.width, size.height * 0.3)],
      [Offset(0, size.height * 0.65), Offset(size.width, size.height * 0.65)],
      [Offset(size.width * 0.25, 0), Offset(size.width * 0.25, size.height)],
      [Offset(size.width * 0.7, 0), Offset(size.width * 0.7, size.height)],
    ];
    for (final s in streets) {
      canvas.drawLine(s[0], s[1], streetPaint);
    }

    // Route path
    final routePath = Path()
      ..moveTo(size.width * 0.1, size.height * 0.82)
      ..cubicTo(
        size.width * 0.15, size.height * 0.55,
        size.width * 0.3, size.height * 0.65,
        size.width * 0.42, size.height * 0.45,
      )
      ..cubicTo(
        size.width * 0.5, size.height * 0.3,
        size.width * 0.6, size.height * 0.35,
        size.width * 0.72, size.height * 0.22,
      )
      ..cubicTo(
        size.width * 0.82, size.height * 0.12,
        size.width * 0.88, size.height * 0.18,
        size.width * 0.92, size.height * 0.15,
      );

    // Shadow under the route
    canvas.drawPath(
      routePath,
      Paint()
        ..color = AppColors.primary.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Gradient route line
    final routeBounds = routePath.getBounds();
    canvas.drawPath(
      routePath,
      Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0xFF4CAF7D),
            AppColors.primary,
          ],
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
        ).createShader(routeBounds)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );

    // Start dot (green)
    _drawDot(
      canvas,
      Offset(size.width * 0.1, size.height * 0.82),
      const Color(0xFF4CAF7D),
    );

    // End dot (purple)
    _drawDot(
      canvas,
      Offset(size.width * 0.92, size.height * 0.15),
      AppColors.primary,
    );

    // Mid marker icon background
    final markerCenter = Offset(size.width * 0.45, size.height * 0.43);
    canvas.drawCircle(
      markerCenter,
      13,
      Paint()..color = AppColors.primary.withValues(alpha: 0.85),
    );

    final iconPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    // Simple dumbbell icon
    final dbl = markerCenter;
    canvas.drawLine(
      Offset(dbl.dx - 6, dbl.dy),
      Offset(dbl.dx + 6, dbl.dy),
      iconPaint,
    );
    for (final dx in [-6.0, 6.0]) {
      canvas.drawLine(
        Offset(dbl.dx + dx, dbl.dy - 3.5),
        Offset(dbl.dx + dx, dbl.dy + 3.5),
        iconPaint..strokeWidth = 2.2,
      );
    }
  }

  void _drawDot(Canvas canvas, Offset center, Color color) {
    canvas.drawCircle(
      center,
      7,
      Paint()..color = color.withValues(alpha: 0.35),
    );
    canvas.drawCircle(
      center,
      4.5,
      Paint()..color = color,
    );
    canvas.drawCircle(
      center,
      4.5,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(_MapRoutePainter old) => false;
}

// ── Stats column ──────────────────────────────────────────────────────────────

class _StatsColumn extends StatelessWidget {
  const _StatsColumn({required this.activity});

  final LastActivity activity;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ActivityTitle(activity: activity),
        const SizedBox(height: 12),
        _StatGrid(activity: activity),
        const SizedBox(height: 14),
        _DetailButton(onTap: () {}),
      ],
    );
  }
}

class _ActivityTitle extends StatelessWidget {
  const _ActivityTitle({required this.activity});

  final LastActivity activity;

  static _KindVisual _visual(RecentActivityKind kind) => switch (kind) {
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

  @override
  Widget build(BuildContext context) {
    final v = _visual(activity.kind);
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

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.activity});

  final LastActivity activity;

  @override
  Widget build(BuildContext context) {
    final stats = switch (activity) {
      StrengthActivity s => [
          _StatItem(
            value: s.durationLabel,
            label: 'Czas',
          ),
          _StatItem(
            value: '${_fmtVolume(s.volumeKg)} kg',
            label: 'Objętość',
          ),
          _StatItem(
            value: '${s.caloriesKcal}',
            label: 'Kalorie',
          ),
        ],
      CardioActivity c => [
          _StatItem(
            value: c.durationLabel,
            label: 'Czas',
          ),
          _StatItem(
            value: '${c.distanceKm.toStringAsFixed(1).replaceAll('.', ',')} km',
            label: 'Dystans',
          ),
          _StatItem(
            value: '${c.avgPulseBpm} bpm',
            label: 'Śr. puls',
          ),
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

  static String _fmtVolume(int kg) {
    if (kg >= 1000) {
      return '${(kg / 1000).toStringAsFixed(kg % 1000 == 0 ? 0 : 1).replaceAll('.', ',')}\u202F${(kg % 1000).toString().padLeft(3, '0')}';
    }
    return '$kg';
  }
}

class _StatItem {
  const _StatItem({required this.value, required this.label});

  final String value;
  final String label;
}

class _DetailButton extends StatelessWidget {
  const _DetailButton({required this.onTap});

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

class _KindVisual {
  const _KindVisual({required this.icon, required this.color});

  final IconData icon;
  final Color color;
}
