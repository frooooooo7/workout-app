import 'dart:math' as math;
import 'dart:ui';

import '../../../body_highlighter/models/body_model_data.dart';
import '../../domain/models/body_measurement_entry.dart';

/// Pierścień obwodu na sylwetce (elipsa), we współrzędnych rysunku.
typedef MeasurementRing = ({Offset center, double rx, double ry});

/// Strona sylwetki, po której stoi podpis obwodu — tak, żeby linie
/// odniesienia się nie krzyżowały.
bool measurementLabelOnLeft(BodyMeasurementField field) => switch (field) {
  BodyMeasurementField.neck ||
  BodyMeasurementField.arm ||
  BodyMeasurementField.hips ||
  BodyMeasurementField.calf => true,
  _ => false,
};

/// Prostokąt, w który wpisujemy sylwetkę: obrys z głową i włosami, z małym
/// marginesem na grubość linii (viewBox plików ma duże puste pola).
Rect silhouetteFigureBounds(BodyModelData data) {
  var bounds = data.outline?.getBounds() ?? data.viewBox;
  for (final region in data.regions) {
    if (region.slug == 'head' || region.slug == 'hair') {
      for (final path in region.paths) {
        bounds = bounds.expandToInclude(path.getBounds());
      }
    }
  }
  return bounds.inflate(8);
}

/// Miejsca pomiaru obwodów wyliczone z obrysów mięśni, więc pasują do
/// sylwetki męskiej i kobiecej bez ręcznych współrzędnych. Proporcje są
/// dobrane tak, żeby na męskiej sylwetce pierścienie leżały jak na makiecie:
/// szyja w 2/3 wysokości szyi, klatka przez środek piersi, talia na wysokości
/// pępka, biodra tuż pod pachwiną, udo i łydka w najszerszym miejscu.
Map<BodyMeasurementField, MeasurementRing> measurementRings(
  BodyModelData data,
) {
  final figure = silhouetteFigureBounds(data);
  final midX = figure.center.dx;

  Rect? bounds(String slug, {bool? imageLeft}) {
    Rect? result;
    for (final region in data.regions) {
      if (region.slug != slug) continue;
      for (final path in region.paths) {
        final b = path.getBounds();
        if (imageLeft != null && (b.center.dx < midX) != imageLeft) continue;
        result = result?.expandToInclude(b) ?? b;
      }
    }
    return result;
  }

  MeasurementRing ring(double cx, double y, double rx) =>
      (center: Offset(cx, y), rx: rx, ry: math.min(math.max(rx * 0.16, 7), 14));

  MeasurementRing? across(Rect? b, double atHeight, {double widthFactor = 1}) {
    if (b == null) return null;
    return ring(
      b.center.dx,
      b.top + b.height * atHeight,
      b.width / 2 * widthFactor,
    );
  }

  final thighQuad = bounds('quadriceps', imageLeft: false);
  final thighInner = bounds('adductors', imageLeft: false);
  final thigh = thighQuad == null
      ? null
      : thighInner?.expandToInclude(thighQuad) ?? thighQuad;

  final rings = <BodyMeasurementField, MeasurementRing?>{
    BodyMeasurementField.neck: across(bounds('neck'), 0.66, widthFactor: 0.86),
    BodyMeasurementField.chest: across(
      bounds('chest'),
      0.56,
      widthFactor: 1.05,
    ),
    BodyMeasurementField.arm: across(
      bounds('biceps', imageLeft: true),
      0.52,
      widthFactor: 1.34,
    ),
    BodyMeasurementField.waist: across(bounds('obliques'), 0.76),
    BodyMeasurementField.hips: across(bounds('quadriceps'), 0.08),
    BodyMeasurementField.thigh: thigh == null
        ? null
        : ring(
            thigh.center.dx,
            thighQuad!.top + thighQuad.height * 0.43,
            thigh.width / 2,
          ),
    BodyMeasurementField.calf: across(bounds('calves', imageLeft: true), 0.41),
  };
  return {for (final MapEntry(:key, :value) in rings.entries) key: ?value};
}
