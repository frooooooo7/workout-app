import 'dart:convert';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:path_drawing/path_drawing.dart';

import '../models/body_gender.dart';
import '../models/body_model_data.dart';
import '../models/body_side.dart';
import '../models/body_view.dart';
import '../models/muscle_region.dart';

/// Singleton asset loader and cache manager for Anatomical Body Highlighter SVG data.
class BodyHighlighterAssetLoader {
  static final BodyHighlighterAssetLoader instance =
      BodyHighlighterAssetLoader._internal();

  BodyHighlighterAssetLoader._internal();

  final Map<String, BodyModelData> _cache = {};

  /// Loads JSON data from assets and parses SVG paths into Flutter [Path] objects once.
  Future<BodyModelData> loadModelData(
    BodyGender gender,
    BodyView view, {
    AssetBundle? bundle,
  }) async {
    final key = '${gender.name}_${view.name}';
    if (_cache.containsKey(key)) {
      return _cache[key]!;
    }

    final targetBundle = bundle ?? rootBundle;
    final jsonPath = 'assets/body_highlighter/$key.json';
    final jsonString = await targetBundle.loadString(jsonPath);
    final Map<String, dynamic> jsonMap = json.decode(jsonString);

    // Parse ViewBox
    final vbMap = jsonMap['viewBox'] as Map<String, dynamic>;
    final viewBox = Rect.fromLTWH(
      (vbMap['x'] as num).toDouble(),
      (vbMap['y'] as num).toDouble(),
      (vbMap['width'] as num).toDouble(),
      (vbMap['height'] as num).toDouble(),
    );

    // Parse Outline
    Path? outlinePath;
    final outlineStr = jsonMap['outline'] as String?;
    if (outlineStr != null && outlineStr.isNotEmpty) {
      outlinePath = parseSvgPathData(outlineStr);
    }

    // Parse Muscle Regions
    final musclesList = jsonMap['muscles'] as List<dynamic>;
    final regions = <MuscleRegion>[];

    for (final item in musclesList) {
      final id = item['id'] as String;
      final slug = item['slug'] as String;
      final sideStr = item['side'] as String;
      final side = BodySide.values.firstWhere(
        (s) => s.name == sideStr,
        orElse: () => BodySide.common,
      );

      final pathsList = item['paths'] as List<dynamic>;
      final parsedPaths = <Path>[];
      for (final pStr in pathsList) {
        if (pStr is String && pStr.isNotEmpty) {
          parsedPaths.add(parseSvgPathData(pStr));
        }
      }

      regions.add(
        MuscleRegion(
          id: id,
          slug: slug,
          side: side,
          view: view,
          paths: parsedPaths,
        ),
      );
    }

    final data = BodyModelData(
      viewBox: viewBox,
      outline: outlinePath,
      regions: regions,
    );

    _cache[key] = data;
    return data;
  }

  /// Preloads all models into memory cache.
  Future<void> preloadAll({AssetBundle? bundle}) async {
    for (final gender in BodyGender.values) {
      for (final view in BodyView.values) {
        await loadModelData(gender, view, bundle: bundle);
      }
    }
  }

  /// Clears the loaded cache if needed.
  void clearCache() {
    _cache.clear();
  }
}
