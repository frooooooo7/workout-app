import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/exercise_tracking.dart';

/// „Co zapisujesz” w formularzu ćwiczenia: cztery kafelki trybu serii,
/// przy czasie + dystansie jednostka dystansu, a pod spodem podgląd, jak
/// będzie wyglądał wiersz serii na treningu.
class ExerciseTrackingPicker extends StatelessWidget {
  const ExerciseTrackingPicker({
    super.key,
    required this.tracking,
    required this.distanceUnit,
    required this.onTrackingChanged,
    required this.onDistanceUnitChanged,
    this.enabled = true,
  });

  final ExerciseTracking tracking;
  final DistanceUnit distanceUnit;
  final ValueChanged<ExerciseTracking> onTrackingChanged;
  final ValueChanged<DistanceUnit> onDistanceUnitChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final tileWidth = (constraints.maxWidth - _gap) / 2;
            return Wrap(
              spacing: _gap,
              runSpacing: _gap,
              children: [
                for (final option in ExerciseTracking.values)
                  SizedBox(
                    width: tileWidth,
                    child: _TrackingTile(
                      key: ValueKey('tracking-${option.apiName}'),
                      tracking: option,
                      selected: option == tracking,
                      onTap: enabled ? () => onTrackingChanged(option) : null,
                    ),
                  ),
              ],
            );
          },
        ),
        AnimatedSize(
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: tracking.tracksDistance
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _DistanceUnitRow(
                    unit: distanceUnit,
                    onChanged: enabled ? onDistanceUnitChanged : null,
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        const SizedBox(height: 12),
        _SetPreview(tracking: tracking, distanceUnit: distanceUnit),
      ],
    );
  }

  static const _gap = 10.0;
}

/// Krótkie etykiety kolumn trybu — te same, co w nagłówku tabeli serii.
List<String> trackingColumnTags(ExerciseTracking tracking) =>
    switch (tracking) {
      ExerciseTracking.weightReps => const ['KG', 'POWT.'],
      ExerciseTracking.reps => const ['POWT.'],
      ExerciseTracking.duration => const ['CZAS'],
      ExerciseTracking.durationDistance => const ['CZAS', 'DYSTANS', 'TEMPO'],
    };

class _TrackingTile extends StatelessWidget {
  const _TrackingTile({
    super.key,
    required this.tracking,
    required this.selected,
    required this.onTap,
  });

  final ExerciseTracking tracking;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      selected: selected,
      label: '${tracking.label}, ${tracking.example}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          constraints: const BoxConstraints(minHeight: 104),
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.10)
                : AppColors.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? AppColors.primaryVariant.withValues(alpha: 0.8)
                  : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      tracking.label,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  AnimatedOpacity(
                    opacity: selected ? 1 : 0,
                    duration: reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 160),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: AppColors.primaryVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final tag in trackingColumnTags(tracking))
                    _Tag(text: tag, highlighted: selected),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                tracking.example,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.highlighted});

  final String text;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: highlighted
            ? AppColors.primary.withValues(alpha: 0.22)
            : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: highlighted ? AppColors.primaryVariant : AppColors.textLabel,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _DistanceUnitRow extends StatelessWidget {
  const _DistanceUnitRow({required this.unit, required this.onChanged});

  final DistanceUnit unit;
  final ValueChanged<DistanceUnit>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dystans w',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'wioślarz zwykle w metrach',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final option in DistanceUnit.values)
                  _UnitSegment(
                    key: ValueKey('distance-unit-${option.name}'),
                    label: option.label,
                    selected: option == unit,
                    onTap: onChanged == null ? null : () => onChanged!(option),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UnitSegment extends StatelessWidget {
  const _UnitSegment({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 160),
          width: 52,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.borderStrong : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.textPrimary : AppColors.textSecondary,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

/// Przykładowy wiersz serii w wybranym trybie.
class _SetPreview extends StatelessWidget {
  const _SetPreview({required this.tracking, required this.distanceUnit});

  final ExerciseTracking tracking;
  final DistanceUnit distanceUnit;

  @override
  Widget build(BuildContext context) {
    final value = AppTextStyles.number(size: 18, color: AppColors.textPrimary);
    final muted = AppTextStyles.tabular(
      const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
      ),
    );
    const sampleSeconds = 480;
    final sampleMeters = distanceUnit == DistanceUnit.km ? 1600 : 2000;
    final cells = switch (tracking) {
      ExerciseTracking.weightReps => [
        Text('60 kg', style: value),
        Text('× 8', style: value),
      ],
      ExerciseTracking.reps => [Text('12 powt.', style: value)],
      ExerciseTracking.duration => [
        Text(formatSetDuration(sampleSeconds), style: value),
      ],
      ExerciseTracking.durationDistance => [
        Text(formatSetDuration(sampleSeconds), style: value),
        Text(distanceUnit.formatWithUnit(sampleMeters), style: value),
        Text(
          '${distanceUnit.pace(seconds: sampleSeconds, meters: sampleMeters)} '
          '${distanceUnit.paceSuffix}',
          style: muted,
        ),
      ],
    };
    return CustomPaint(
      painter: _DashedBorderPainter(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'PODGLĄD SERII',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              key: ValueKey('tracking-preview-${tracking.apiName}'),
              children: [
                Text('1', style: muted),
                const SizedBox(width: 18),
                for (var i = 0; i < cells.length; i++) ...[
                  if (i > 0) const Spacer(),
                  cells[i],
                ],
                if (cells.length == 1) const Spacer(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.borderStrong
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(14)),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 5), paint);
        distance += 9;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) => false;
}
