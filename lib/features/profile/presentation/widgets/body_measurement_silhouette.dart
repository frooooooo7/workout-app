import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../body_highlighter/data/body_highlighter_asset_loader.dart';
import '../../../body_highlighter/models/body_gender.dart';
import '../../../body_highlighter/models/body_highlighter_style.dart';
import '../../../body_highlighter/models/body_model_data.dart';
import '../../../body_highlighter/models/body_view.dart';
import '../../../body_highlighter/painters/body_highlighter_painter.dart';
import '../../domain/models/body_measurement_entry.dart';
import '../utils/body_measurement_comparison.dart';
import '../utils/body_measurement_format.dart';
import '../utils/body_measurement_trend.dart';
import 'body_measurement_silhouette_geometry.dart';

/// Podpis obwodu na sylwetce (testy).
Key bodyMeasurementLabelKey(BodyMeasurementField field) =>
    ValueKey('body-measurement-label-${field.name}');

/// Sylwetka (rysunek z body_highlighter) z pierścieniem w miejscu pomiaru
/// każdego obwodu i podpisem z wartością i zmianą na linii odniesienia.
/// Pusty [deltas] — sama sylwetka (stan bez pomiarów).
class BodyMeasurementSilhouette extends StatefulWidget {
  const BodyMeasurementSilhouette({
    super.key,
    required this.gender,
    required this.deltas,
    this.onFieldTap,
  });

  final BodyGender gender;

  /// Obwody do pokazania; tkanka tłuszczowa jest pomijana.
  final Map<BodyMeasurementField, BodyMeasurementDelta> deltas;

  /// Dotknięcie podpisu — np. wykres tego obwodu.
  final ValueChanged<BodyMeasurementField>? onFieldTap;

  static const height = 362.0;

  @override
  State<BodyMeasurementSilhouette> createState() =>
      _BodyMeasurementSilhouetteState();
}

class _BodyMeasurementSilhouetteState extends State<BodyMeasurementSilhouette> {
  _Figure? _figure;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant BodyMeasurementSilhouette oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gender != widget.gender) _load();
  }

  Future<void> _load() async {
    final gender = widget.gender;
    final data = await BodyHighlighterAssetLoader.instance.loadModelData(
      gender,
      BodyView.front,
    );
    if (!mounted || gender != widget.gender) return;
    setState(() => _figure = _Figure(data));
  }

  @override
  Widget build(BuildContext context) {
    final figure = _figure;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return SizedBox(
      height: BodyMeasurementSilhouette.height,
      child: AnimatedOpacity(
        opacity: figure == null ? 0 : 1,
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        child: figure == null
            ? const SizedBox.expand()
            : LayoutBuilder(
                builder: (context, constraints) =>
                    _buildFigure(figure, constraints.maxWidth),
              ),
      ),
    );
  }

  Widget _buildFigure(_Figure figure, double width) {
    // Kolumny podpisów po bokach, sylwetka 175 × 340 pośrodku.
    final boxWidth = math.min(175.0, width - 2 * (_labelWidth + 4));
    final box = Rect.fromLTWH((width - boxWidth) / 2, 10, boxWidth, 340);
    final fit = _Fit(figure.bounds, box);

    final marks = _spread([
      for (final MapEntry(key: field, value: ring) in figure.rings.entries)
        if (widget.deltas[field] case final delta?)
          _Mark(field, delta, fit.ring(ring), measurementLabelOnLeft(field)),
    ]);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: box.center.dx - 210,
          top: box.center.dy - 175,
          width: 420,
          height: 420,
          child: const IgnorePointer(child: _Glow()),
        ),
        Positioned.fromRect(
          rect: box,
          child: CustomPaint(
            painter: _FigureFillPainter(figure.data.outline, figure.bounds),
            foregroundPainter: BodyHighlighterPainter(
              data: figure.fitted,
              animatedMuscleColors: const {},
              highlights: const {},
              style: _style,
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _RingsPainter(marks, box)),
          ),
        ),
        for (final mark in marks)
          Positioned(
            left: mark.onLeft ? box.left - 3 - _labelWidth : box.right + 4,
            top: mark.labelTop,
            width: _labelWidth,
            child: _Label(
              key: bodyMeasurementLabelKey(mark.field),
              field: mark.field,
              delta: mark.delta,
              alignRight: mark.onLeft,
              onTap: widget.onFieldTap == null
                  ? null
                  : () => widget.onFieldTap!(mark.field),
            ),
          ),
        if (marks.isNotEmpty)
          const Positioned(
            right: 0,
            bottom: 8,
            child: Text(
              'cm',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }

  /// Linia trafia w podpis między nazwą a wartością; podpisy po jednej
  /// stronie nie mogą na siebie nachodzić, więc niższy schodzi w dół.
  static List<_Mark> _spread(List<_Mark> marks) {
    final result = <_Mark>[];
    for (final left in [true, false]) {
      final side = marks.where((m) => m.onLeft == left).toList()
        ..sort((a, b) => a.ring.center.dy.compareTo(b.ring.center.dy));
      var minTop = double.negativeInfinity;
      for (final mark in side) {
        mark.labelTop = math.max(
          mark.ring.center.dy - _labelLineOffset,
          minTop,
        );
        minTop = mark.labelTop + _labelSpacing;
        result.add(mark);
      }
    }
    return result;
  }
}

const _labelWidth = 88.0;
const _labelSpacing = 40.0;

/// Odległość linii odniesienia od góry podpisu.
const _labelLineOffset = 19.0;

/// Kontur sylwetki i linie odniesienia — jaśniej niż krawędzie mięśni.
const _outlineColor = Color(0xFF3A4760);
const _style = BodyHighlighterStyle(
  inactiveFill: AppColors.surfaceVariant,
  inactiveStroke: Color(0xFF2C3649),
  outlineColor: _outlineColor,
  lowColor: AppColors.surfaceVariant,
  mediumColor: AppColors.surfaceVariant,
  highColor: AppColors.surfaceVariant,
  activeStroke: Color(0xFF2C3649),
  glowEnabled: false,
  strokeWidth: 0.6,
);

/// Wczytany rysunek i wyliczone z niego miejsca pomiaru.
class _Figure {
  _Figure(this.data)
    : bounds = silhouetteFigureBounds(data),
      rings = measurementRings(data);

  final BodyModelData data;
  final Rect bounds;
  final Map<BodyMeasurementField, MeasurementRing> rings;

  /// Ten sam rysunek z viewBox przyciętym do postaci — malarz z
  /// body_highlighter wpisuje go wtedy w całe pole.
  late final fitted = BodyModelData(
    viewBox: bounds,
    outline: data.outline,
    regions: data.regions,
  );
}

/// Przeliczenie współrzędnych rysunku na pole [box] (wpisanie z
/// zachowaniem proporcji, wyśrodkowane — jak w [BodyHighlighterPainter]).
class _Fit {
  _Fit(Rect source, Rect box)
    : scale = math.min(box.width / source.width, box.height / source.height),
      _source = source,
      _box = box;

  final double scale;
  final Rect _source;
  final Rect _box;

  Offset map(Offset p) => Offset(
    _box.left +
        (_box.width - _source.width * scale) / 2 +
        (p.dx - _source.left) * scale,
    _box.top +
        (_box.height - _source.height * scale) / 2 +
        (p.dy - _source.top) * scale,
  );

  MeasurementRing ring(MeasurementRing r) =>
      (center: map(r.center), rx: r.rx * scale, ry: r.ry * scale);
}

class _Mark {
  _Mark(this.field, this.delta, this.ring, this.onLeft);

  final BodyMeasurementField field;
  final BodyMeasurementDelta delta;
  final MeasurementRing ring;
  final bool onLeft;
  double labelTop = 0;

  /// Pierścień: zielony / czerwony wg kierunku, szary bez zmiany.
  Color get color {
    final change = delta.change;
    if (change == null) return AppColors.textSecondary;
    final trend = measurementTrend(field, change);
    return trend == MeasurementTrend.neutral
        ? AppColors.textSecondary
        : trend.color;
  }
}

/// Wypełnienie całej postaci pod mięśniami, żeby szczeliny między nimi
/// nie prześwitywały tłem.
class _FigureFillPainter extends CustomPainter {
  _FigureFillPainter(this.outline, this.bounds);

  final Path? outline;
  final Rect bounds;

  @override
  void paint(Canvas canvas, Size size) {
    final outline = this.outline;
    if (outline == null) return;
    final fit = _Fit(bounds, Offset.zero & size);
    final origin = fit.map(Offset.zero);
    canvas
      ..save()
      ..translate(origin.dx, origin.dy)
      ..scale(fit.scale)
      ..drawPath(outline, Paint()..color = AppColors.surface)
      ..restore();
  }

  @override
  bool shouldRepaint(_FigureFillPainter oldDelegate) =>
      oldDelegate.outline != outline || oldDelegate.bounds != bounds;
}

/// Pierścienie (tył przerywany, przód pełny) i przerywane linie do podpisów.
class _RingsPainter extends CustomPainter {
  _RingsPainter(this.marks, this.box);

  final List<_Mark> marks;
  final Rect box;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = _outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final mark in marks) {
      final ring = mark.ring;
      // Od podpisu do końca pierścienia; podpis odsunięty od sąsiada
      // dochodzi do pierścienia ukośnie.
      final labelY = mark.labelTop + _labelLineOffset;
      final edgeX = mark.onLeft ? box.left : box.right;
      final ringX = mark.onLeft
          ? ring.center.dx - ring.rx
          : ring.center.dx + ring.rx;
      final bend = mark.onLeft ? edgeX + 8 : edgeX - 8;
      canvas.drawPath(
        dashPath(
          Path()
            ..moveTo(edgeX, labelY)
            ..lineTo(bend, labelY)
            ..lineTo(ringX, ring.center.dy),
          dashArray: CircularIntervalList([3, 3]),
        ),
        linePaint,
      );

      final oval = Rect.fromCenter(
        center: ring.center,
        width: ring.rx * 2,
        height: ring.ry * 2,
      );
      canvas.drawPath(
        dashPath(
          Path()..addArc(oval, math.pi, math.pi),
          dashArray: CircularIntervalList([2.2, 2.2]),
        ),
        Paint()
          ..color = mark.color.withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1,
      );
      canvas.drawArc(
        oval,
        0,
        math.pi,
        false,
        Paint()
          ..color = mark.color
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 1.6,
      );
    }
  }

  @override
  bool shouldRepaint(_RingsPainter oldDelegate) =>
      oldDelegate.marks != marks || oldDelegate.box != box;
}

class _Label extends StatelessWidget {
  const _Label({
    super.key,
    required this.field,
    required this.delta,
    required this.alignRight,
    this.onTap,
  });

  final BodyMeasurementField field;
  final BodyMeasurementDelta delta;
  final bool alignRight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final change = delta.change;
    final name = measurementShortLabel(field);
    return Semantics(
      button: onTap != null,
      label:
          '$name ${formatMeasurement(field, delta.value)}'
          '${change == null ? '' : ', zmiana ${formatMeasurementChange(field, change)}'}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: alignRight
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              name,
              maxLines: 1,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: formatMeasurementFixed(delta.value),
                    style: AppTextStyles.number(size: 19, height: 1.2),
                  ),
                  if (change != null)
                    TextSpan(
                      text: ' ${formatMeasurementDelta(change)}',
                      style: TextStyle(
                        color: measurementTrend(field, change).color,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
              maxLines: 1,
              softWrap: false,
            ),
          ],
        ),
      ),
    );
  }
}

/// Zielona poświata za sylwetką.
class _Glow extends StatelessWidget {
  const _Glow();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            AppColors.success.withValues(alpha: 0.10),
            AppColors.success.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}
