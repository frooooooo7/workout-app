import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Przechowuje rastrowy "zdjęcie" narysowanej sylwetki.
///
/// Wektorowe rysowanie manekina (kilkadziesiąt ścieżek z obrysami, a przy
/// mocno obciążonych mięśniach także rozmyta poświata) jest drogie, a bez
/// ręcznego cache'u silnik powtarza je w każdej klatce rasteryzacji — również
/// podczas samego przewijania ekranu, gdy treść manekina się nie zmienia.
/// Gdy kolory się ustabilizują, rysujemy sylwetkę raz do [ui.Image] i potem
/// tylko wklejamy bitmapę.
///
/// Cache rozpoznaje wyłącznie rozmiar i DPR. O zmianie treści (dane, kolory,
/// podświetlenia, styl) dowiaduje się tylko z [invalidate], więc jego właściciel
/// musi je wołać przy każdej takiej zmianie — inaczej sylwetka będzie nieaktualna.
class BodySnapshotCache {
  ui.Image? _image;
  Size _size = Size.zero;
  double _devicePixelRatio = 1;

  /// Ostatnia próba zdjęcia się nie udała — nie ponawiamy jej w każdej klatce,
  /// dopiero po [invalidate] (zmianie treści).
  bool _failed = false;

  /// Ile razy faktycznie wyrenderowano zdjęcie (przydatne w testach).
  @visibleForTesting
  int renderCount = 0;

  bool get hasImage => _image != null;

  /// Zwraca zdjęcie pasujące do [size] i [devicePixelRatio] albo `null`, gdy
  /// trzeba je odtworzyć.
  ui.Image? imageFor(Size size, double devicePixelRatio) {
    if (_image == null) return null;
    if (_size != size || _devicePixelRatio != devicePixelRatio) return null;
    return _image;
  }

  /// Renderuje [paintContent] (rysujące w układzie o rozmiarze [size]) do
  /// bitmapy w natywnej rozdzielczości ekranu. Zwraca `null`, gdy platforma
  /// nie pozwoli zrobić zdjęcia — wtedy wołający rysuje wektorowo.
  ui.Image? render(
    Size size,
    double devicePixelRatio,
    void Function(ui.Canvas canvas) paintContent,
  ) {
    if (_failed) return null;
    final pixelWidth = (size.width * devicePixelRatio).ceil();
    final pixelHeight = (size.height * devicePixelRatio).ceil();
    if (pixelWidth <= 0 || pixelHeight <= 0) return null;

    try {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.scale(devicePixelRatio, devicePixelRatio);
      paintContent(canvas);
      final picture = recorder.endRecording();
      final image = picture.toImageSync(pixelWidth, pixelHeight);
      picture.dispose();

      _image?.dispose();
      _image = image;
      _size = size;
      _devicePixelRatio = devicePixelRatio;
      renderCount++;
      return image;
    } catch (_) {
      invalidate();
      _failed = true;
      return null;
    }
  }

  /// Wyrzuca zdjęcie — treść manekina się zmieniła.
  void invalidate() {
    _image?.dispose();
    _image = null;
    _failed = false;
  }

  void dispose() => invalidate();
}
