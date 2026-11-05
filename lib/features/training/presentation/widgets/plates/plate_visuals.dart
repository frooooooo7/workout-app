import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/units/weight_unit.dart';
import '../../../domain/models/plate_equipment.dart';

/// Kolory talerzy wg standardu IWF (25 czerwony, 20 niebieski, 15 żółty,
/// 10 zielony, 5 biały…) — ten sam nominał ma ten sam kolor na rysunku
/// gryfu, w legendzie, w panelu przerwy i w ustawieniach.
abstract final class PlateColors {
  static const red = Color(0xFFE5484D);
  static const blue = Color(0xFF3B82F6);
  static const yellow = Color(0xFFF5B83D);
  static const green = Color(0xFF2FBF71);
  static const white = Color(0xFFE6E9EF);
  static const silver = Color(0xFF9AA3B2);

  /// Nietypowy (własny) nominał.
  static const other = Color(0xFF7C869A);

  /// Gryf (też na tarczy talerza w ustawieniach), jasna stal zacisku i
  /// ciemny korpus zacisku.
  static const shaft = Color(0xFF2A3242);
  static const steel = Color(0xFFC9D1E0);
  static const clampBody = Color(0xFF1B2230);

  static Color of(double weight, WeightUnit unit) {
    if (unit == WeightUnit.kg) {
      return switch (weight) {
        25 => red,
        20 => blue,
        15 => yellow,
        10 => green,
        5 => white,
        2.5 => red,
        1.25 || 0.5 || 0.25 => silver,
        _ => other,
      };
    }
    return switch (weight) {
      45 => blue,
      35 => yellow,
      25 => green,
      10 => white,
      5 => red,
      2.5 => silver,
      _ => other,
    };
  }

  /// Ciemny tekst na jasnym talerzu (5 kg), jasny na pozostałych.
  static Color onPlate(Color plate) =>
      plate.computeLuminance() > 0.5 ? const Color(0xFF1A2130) : Colors.white;
}

/// Względna wielkość talerza (0,3–1) — duże talerze pełnej wysokości,
/// małe wyraźnie niższe, jak na prawdziwym gryfie.
double plateSizeFraction(double weight, WeightUnit unit) {
  final heaviest = PlateEquipment.heaviestStandardPlate(unit);
  return math.sqrt(weight / heaviest).clamp(0.3, 1.0);
}

/// `100`, `102,5`, `101,25` — do dwóch miejsc po przecinku, bez zbędnych
/// zer. [formatDisplayNumber] zaokrągla do 0,1, a talerz 1,25 kg tego nie
/// zniesie.
String formatPlateNumber(double value) {
  final rounded = (value * 100).round() / 100;
  if (rounded == rounded.roundToDouble()) return rounded.toInt().toString();
  var text = rounded.toStringAsFixed(2);
  if (text.endsWith('0')) text = text.substring(0, text.length - 1);
  return text.replaceAll('.', ',');
}

/// Talerze od najlżejszego do najcięższego — w tej kolejności są rysowane
/// od lewej (od końca tulei) i wypisywane w legendzie.
List<double> ascendingPlates(Iterable<double> plates) => [...plates]..sort();

/// Metal z pionowym połyskiem — tuleja, kołnierz i gryf.
Paint _metalPaint(Rect rect, {bool dark = false}) =>
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: dark
            ? const [Color(0xFF7C869A), Color(0xFF4A546A), Color(0xFF2C3446)]
            : const [Color(0xFFD2D9E6), Color(0xFF8F99AD), Color(0xFF4B556A)],
      ).createShader(rect);

/// Jedna strona gryfu z boku. Od lewej: koniec tulei, zacisk, talerze od
/// najlżejszego do najcięższego, kołnierz (granica tulei) i kawałek gryfu —
/// jak na prawdziwej sztandze, na której najcięższy talerz leży przy
/// kołnierzu. Przy wielu talerzach rysunek się zwęża.
class BarbellSleeve extends StatelessWidget {
  const BarbellSleeve({
    super.key,
    required this.plates,
    required this.unit,
    this.height = 120,
  });

  /// W dowolnej kolejności — rysunek sam układa je od najlżejszego.
  final List<double> plates;
  final WeightUnit unit;
  final double height;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final ordered = ascendingPlates(plates);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: TweenAnimationBuilder<double>(
        // Przy każdej zmianie układu talerze lekko „osadzają się” na tulei.
        // Start od 70%, nie od zera — przy przeciąganiu linijki rysunek
        // zmienia się co klatkę i nie może migać.
        key: ValueKey(ordered.join('|')),
        tween: Tween(begin: reduceMotion ? 1 : 0.7, end: 1),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        builder: (context, progress, _) => CustomPaint(
          painter: _SleevePainter(
            plates: ordered,
            unit: unit,
            progress: progress,
          ),
        ),
      ),
    );
  }
}

class _SleevePainter extends CustomPainter {
  _SleevePainter({
    required this.plates,
    required this.unit,
    required this.progress,
  });

  /// Od najlżejszego (z lewej) do najcięższego (przy kołnierzu).
  final List<double> plates;
  final WeightUnit unit;
  final double progress;

  static const _shaftLength = 46.0;
  static const _flangeWidth = 8.0;
  static const _clampWidth = 11.0;
  static const _gap = 1.5;
  static const _tipPad = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final cy = h / 2;
    final flangeX = size.width - _shaftLength - _flangeWidth;

    _paintShaft(canvas, size, cy, h, flangeX + _flangeWidth);
    _paintSleeve(canvas, cy, h, flangeX);
    _paintFlange(canvas, cy, h, flangeX);
    final platesLeft = _paintPlates(canvas, cy, h, flangeX);
    _paintClamp(canvas, cy, h, platesLeft);
  }

  /// Gryf za kołnierzem: cieńszy od tulei, z radełkowaniem, blednie ku
  /// środkowi gryfu.
  void _paintShaft(Canvas canvas, Size size, double cy, double h, double x) {
    final rect = Rect.fromLTRB(x - 1, cy - h * 0.04, size.width, cy + h * 0.04);
    canvas.saveLayer(rect.inflate(1), Paint());
    canvas.drawRect(rect, _metalPaint(rect, dark: true));
    final knurl = Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..strokeWidth = 1;
    for (var kx = x + 4; kx < size.width; kx += 4) {
      canvas.drawLine(Offset(kx, rect.top), Offset(kx - 2, rect.bottom), knurl);
    }
    canvas.drawRect(
      rect,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = const LinearGradient(
          colors: [Colors.white, Colors.white, Colors.transparent],
          stops: [0, 0.35, 1],
        ).createShader(rect),
    );
    canvas.restore();
  }

  /// Tuleja, na której leżą talerze: gruba metalowa rura z zaokrąglonym
  /// końcem po lewej.
  void _paintSleeve(Canvas canvas, double cy, double h, double flangeX) {
    final rect = Rect.fromLTRB(0, cy - h * 0.065, flangeX + 2, cy + h * 0.065);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        rect,
        topLeft: const Radius.circular(6),
        bottomLeft: const Radius.circular(6),
      ),
      _metalPaint(rect),
    );
    canvas.drawRect(
      Rect.fromLTRB(5, rect.top + 1.5, flangeX, rect.top + 2.5),
      Paint()..color = Colors.white.withValues(alpha: 0.4),
    );
  }

  /// Kołnierz — granica między tuleją a gryfem. Niższy od talerzy, bez
  /// koloru i ze stopniem w stronę gryfu, żeby nie wyglądał jak talerz.
  void _paintFlange(Canvas canvas, double cy, double h, double flangeX) {
    final step = Rect.fromLTRB(
      flangeX + _flangeWidth - 1,
      cy - h * 0.085,
      flangeX + _flangeWidth + 3,
      cy + h * 0.085,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(step, const Radius.circular(2)),
      _metalPaint(step, dark: true),
    );
    final rect = Rect.fromLTRB(
      flangeX,
      cy - h * 0.11,
      flangeX + _flangeWidth,
      cy + h * 0.11,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(3));
    canvas.drawRRect(rrect, _metalPaint(rect));
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFF1B2230),
    );
  }

  /// Talerze od kołnierza w lewo (najcięższy przy kołnierzu). Zwraca lewą
  /// krawędź najlżejszego talerza — tam kończy się miejsce na zacisk.
  double _paintPlates(Canvas canvas, double cy, double h, double flangeX) {
    final widths = [
      for (final plate in plates) 6 + 10 * plateSizeFraction(plate, unit),
    ];
    final natural =
        widths.fold<double>(0, (a, b) => a + b) +
        _gap * widths.length +
        _clampWidth +
        _gap;
    final available = flangeX - _tipPad;
    final squeeze = natural > available ? available / natural : 1.0;

    // Talerze wjeżdżają na tuleję od jej końca, z lewej.
    var x = flangeX - (1 - progress) * 36;
    for (var i = plates.length - 1; i >= 0; i--) {
      final w = widths[i] * squeeze;
      final ph = h * 0.96 * plateSizeFraction(plates[i], unit);
      x -= w;
      final rect = Rect.fromLTRB(x, cy - ph / 2, x + w, cy + ph / 2);
      final base = PlateColors.of(plates[i], unit);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(math.min(4, w / 2))),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(base, Colors.white, 0.2)!.withValues(alpha: progress),
              base.withValues(alpha: progress),
              Color.lerp(base, Colors.black, 0.25)!.withValues(alpha: progress),
            ],
          ).createShader(rect),
      );
      // Odblask na krawędzi — talerz nie wygląda jak płaski pasek.
      if (w > 5) {
        canvas.drawRRect(
          RRect.fromLTRBR(
            x + 1.5,
            rect.top + 4,
            x + 3,
            rect.bottom - 4,
            const Radius.circular(1),
          ),
          Paint()..color = Colors.white.withValues(alpha: 0.28 * progress),
        );
      }
      x -= _gap * squeeze;
    }
    return x;
  }

  /// Zacisk (spring collar): ciemny korpus z jasną obwódką, szczeliną
  /// i dźwignią — kształtem różni się od każdego talerza.
  void _paintClamp(Canvas canvas, double cy, double h, double right) {
    final bodyHeight = h * 0.3;
    final left = right - _clampWidth;
    final steel = PlateColors.steel.withValues(alpha: progress);
    final body = RRect.fromRectAndRadius(
      Rect.fromLTRB(left, cy - bodyHeight / 2, right, cy + bodyHeight / 2),
      const Radius.circular(3),
    );
    canvas.drawRRect(
      body,
      Paint()..color = PlateColors.clampBody.withValues(alpha: progress),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = steel,
    );
    canvas.drawLine(
      Offset(left + 2.5, cy),
      Offset(right - 2.5, cy),
      Paint()
        ..strokeWidth = 1.2
        ..color = steel.withValues(alpha: 0.55 * progress),
    );
    // Dźwignia wystająca nad korpus.
    final leverTop = cy - bodyHeight / 2 - h * 0.13;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          left + 3.5,
          leverTop,
          left + 7.5,
          cy - bodyHeight / 2 + 1,
        ),
        const Radius.circular(2),
      ),
      Paint()..color = steel,
    );
    canvas.drawCircle(
      Offset(left + 5.5, leverTop),
      3.2,
      Paint()..color = steel,
    );
  }

  @override
  bool shouldRepaint(_SleevePainter old) =>
      old.progress != progress ||
      old.unit != unit ||
      old.plates.join('|') != plates.join('|');
}

/// Miniatura w panelu odpoczynku — ta sama kolejność co duży rysunek:
/// talerze od najlżejszego (z lewej) do najcięższego przy kołnierzu.
class MiniPlateStack extends StatelessWidget {
  const MiniPlateStack({super.key, required this.plates, required this.unit});

  static const width = 56.0;
  static const _maxPlates = 5;

  final List<double> plates;
  final WeightUnit unit;

  @override
  Widget build(BuildContext context) {
    final ordered = ascendingPlates(plates);
    // Przy większej liczbie talerzy zostają najcięższe, przy kołnierzu.
    final shown = ordered.length > _maxPlates
        ? ordered.sublist(ordered.length - _maxPlates)
        : ordered;
    return SizedBox(
      width: width,
      height: 30,
      child: CustomPaint(
        painter: _MiniPainter(plates: shown, unit: unit),
      ),
    );
  }
}

class _MiniPainter extends CustomPainter {
  _MiniPainter({required this.plates, required this.unit});

  final List<double> plates;
  final WeightUnit unit;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    const flangeX = 49.0;

    final sleeve = Rect.fromLTRB(0, cy - 2.5, flangeX + 1, cy + 2.5);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        sleeve,
        topLeft: const Radius.circular(2.5),
        bottomLeft: const Radius.circular(2.5),
      ),
      _metalPaint(sleeve),
    );
    final shaft = Rect.fromLTRB(flangeX + 2, cy - 1.5, size.width, cy + 1.5);
    canvas.drawRect(shaft, _metalPaint(shaft, dark: true));
    final flange = Rect.fromLTRB(flangeX, cy - 5, flangeX + 2.5, cy + 5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(flange, const Radius.circular(1)),
      _metalPaint(flange),
    );

    var x = flangeX;
    final paint = Paint();
    for (var i = plates.length - 1; i >= 0; i--) {
      final f = plateSizeFraction(plates[i], unit);
      final w = 3 + 4 * f;
      final ph = size.height * f;
      x -= w;
      paint.color = PlateColors.of(plates[i], unit);
      canvas.drawRRect(
        RRect.fromLTRBR(
          x,
          cy - ph / 2,
          x + w,
          cy + ph / 2,
          const Radius.circular(2),
        ),
        paint,
      );
      x -= 1;
    }
  }

  @override
  bool shouldRepaint(_MiniPainter old) =>
      old.unit != unit || old.plates.join('|') != plates.join('|');
}

/// Talerz od frontu (ustawienia sprzętu): tarcza, piasta i otwór.
class PlateDisc extends StatelessWidget {
  const PlateDisc({
    super.key,
    required this.weight,
    required this.unit,
    this.size = 40,
    this.enabled = true,
  });

  final double weight;
  final WeightUnit unit;
  final double size;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _DiscPainter(
          color: enabled ? PlateColors.of(weight, unit) : PlateColors.shaft,
          fraction: plateSizeFraction(weight, unit),
        ),
      ),
    );
  }
}

class _DiscPainter extends CustomPainter {
  _DiscPainter({required this.color, required this.fraction});

  final Color color;
  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outer = size.width / 2 * (0.55 + 0.45 * fraction);
    canvas.drawCircle(center, outer, Paint()..color = color);
    canvas.drawCircle(
      center,
      outer * 0.45,
      Paint()..color = Colors.black.withValues(alpha: 0.22),
    );
    canvas.drawCircle(
      center,
      outer * 0.45,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.18),
    );
    canvas.drawCircle(
      center,
      math.max(2.5, outer * 0.16),
      Paint()..color = AppColors.background,
    );
  }

  @override
  bool shouldRepaint(_DiscPainter old) =>
      old.color != color || old.fraction != fraction;
}
