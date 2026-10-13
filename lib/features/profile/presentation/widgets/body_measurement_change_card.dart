import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/body_measurement_entry.dart';
import '../utils/body_measurement_format.dart';
import '../utils/body_measurement_trend.dart';

/// Wiersz obwodu w karcie zmian (testy).
Key bodyMeasurementChangeRowKey(BodyMeasurementField field) =>
    ValueKey('body-measurement-change-${field.name}');

/// Karta „Zmiana od 3 sie”: zmiana wszystkich obwodów naraz jako słupki
/// rosnące od środka — w lewo spadek, w prawo wzrost, kolor wg celu.
/// Bez [changes] pokazuje [emptyMessage] (np. jeden wpis — nie ma czego
/// porównywać).
class BodyMeasurementChangeCard extends StatelessWidget {
  const BodyMeasurementChangeCard({
    super.key,
    required this.title,
    required this.changes,
    this.emptyMessage,
    this.onFieldTap,
  });

  final String title;

  /// Zmiana każdego obwodu, który zmierzono na początku i na końcu okresu.
  final Map<BodyMeasurementField, double> changes;
  final String? emptyMessage;
  final ValueChanged<BodyMeasurementField>? onFieldTap;

  @override
  Widget build(BuildContext context) {
    // Największa zmiana pierwsza; przy remisie spadek przed wzrostem.
    final rows = changes.entries.toList()
      ..sort((a, b) {
        final byChange = b.value.abs().compareTo(a.value.abs());
        return byChange != 0 ? byChange : a.value.compareTo(b.value);
      });
    final maxChange = rows.fold<double>(
      0,
      (max, e) => math.max(max, e.value.abs()),
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (rows.isNotEmpty) const _Legend(),
            ],
          ),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                emptyMessage ?? '',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            )
          else
            Stack(
              children: [
                // Oś zera przez wszystkie wiersze.
                const Positioned.fill(
                  child: Row(
                    children: [
                      SizedBox(width: _labelWidth + _gap),
                      Expanded(
                        child: Center(
                          child: VerticalDivider(
                            width: 1,
                            thickness: 1,
                            color: AppColors.borderStrong,
                          ),
                        ),
                      ),
                      SizedBox(width: _gap + _valueWidth),
                    ],
                  ),
                ),
                Column(
                  children: [
                    for (final (index, MapEntry(:key, :value)) in rows.indexed)
                      _ChangeRow(
                        key: bodyMeasurementChangeRowKey(key),
                        field: key,
                        change: value,
                        fraction: maxChange == 0
                            ? 0
                            : value.abs() / maxChange * _maxBarFraction,
                        delay: index,
                        onTap: onFieldTap == null
                            ? null
                            : () => onFieldTap!(key),
                      ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
}

const _labelWidth = 66.0;
const _valueWidth = 46.0;
const _gap = 8.0;

/// Najdłuższy słupek zajmuje taką część połowy toru — zostaje oddech
/// przy krawędzi.
const _maxBarFraction = 0.85;

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: AppColors.success,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        const Text(
          'w stronę celu',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ChangeRow extends StatelessWidget {
  const _ChangeRow({
    super.key,
    required this.field,
    required this.change,
    required this.fraction,
    required this.delay,
    this.onTap,
  });

  final BodyMeasurementField field;
  final double change;

  /// Długość słupka jako część połowy toru (0–1).
  final double fraction;

  /// Kolejność wiersza — słupki rosną po kolei.
  final int delay;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final color = measurementTrend(field, change).color;
    final label = measurementShortLabel(field);
    return Semantics(
      label: '$label ${formatMeasurementChange(field, change)}',
      button: onTap != null,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 26,
          child: Row(
            children: [
              SizedBox(
                width: _labelWidth,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.iconOnTile,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: _gap),
              Expanded(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: fraction),
                  duration: reduceMotion
                      ? Duration.zero
                      : Duration(milliseconds: 600 + 50 * delay),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => CustomPaint(
                    size: const Size.fromHeight(10),
                    painter: _BarPainter(
                      fraction: value,
                      sign: change.sign.toInt(),
                      color: color,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: _gap),
              SizedBox(
                width: _valueWidth,
                child: Text(
                  formatMeasurementDelta(change),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: color,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Słupek od środka toru; zerowa zmiana to krótka szara kreska na osi.
class _BarPainter extends CustomPainter {
  _BarPainter({
    required this.fraction,
    required this.sign,
    required this.color,
  });

  final double fraction;

  /// −1 spadek (słupek w lewo), 1 wzrost, 0 bez zmiany.
  final int sign;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.width / 2;
    if (sign == 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(mid, size.height / 2),
            width: 3,
            height: 6,
          ),
          const Radius.circular(2),
        ),
        Paint()..color = AppColors.textMuted,
      );
      return;
    }
    final length = mid * fraction;
    const radius = Radius.circular(5);
    final bar = sign < 0
        ? RRect.fromLTRBAndCorners(
            mid - length,
            0,
            mid,
            size.height,
            topLeft: radius,
            bottomLeft: radius,
          )
        : RRect.fromLTRBAndCorners(
            mid,
            0,
            mid + length,
            size.height,
            topRight: radius,
            bottomRight: radius,
          );
    canvas.drawRRect(bar, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_BarPainter oldDelegate) =>
      oldDelegate.fraction != fraction ||
      oldDelegate.sign != sign ||
      oldDelegate.color != color;
}
