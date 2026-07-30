import 'dart:math';
import 'package:flutter/material.dart';

import '../data/body_highlighter_asset_loader.dart';
import '../models/body_gender.dart';
import '../models/body_highlighter_style.dart';
import '../models/body_model_data.dart';
import '../models/body_side.dart';
import '../models/body_view.dart';
import '../models/muscle_highlight.dart';
import '../models/muscle_intensity.dart';
import '../models/muscle_region.dart';
import '../painters/body_highlighter_painter.dart';

/// Reusable anatomical body highlighter widget.
class MuscleBodyHighlighter extends StatefulWidget {
  final BodyView view;
  final BodyGender gender;
  final Set<MuscleHighlight> highlights;
  final BodyHighlighterStyle style;
  final ValueChanged<MuscleRegion>? onMuscleTap;
  final double? width;
  final double? height;
  final Duration animationDuration;

  const MuscleBodyHighlighter({
    super.key,
    this.view = BodyView.front,
    this.gender = BodyGender.male,
    this.highlights = const {},
    this.style = const BodyHighlighterStyle.dark(),
    this.onMuscleTap,
    this.width,
    this.height,
    this.animationDuration = const Duration(milliseconds: 300),
  });

  @override
  State<MuscleBodyHighlighter> createState() => _MuscleBodyHighlighterState();
}

class _MuscleBodyHighlighterState extends State<MuscleBodyHighlighter>
    with SingleTickerProviderStateMixin {
  BodyModelData? _modelData;
  bool _isLoading = true;

  late AnimationController _animController;
  late Animation<double> _animProgress;

  Map<String, Color> _oldColors = {};
  Map<String, Color> _targetColors = {};
  Map<String, Color> _currentColors = {};

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    )..addListener(_onAnimTick);

    _animProgress = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );

    _loadData();
  }

  @override
  void didUpdateWidget(covariant MuscleBodyHighlighter oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.view != widget.view || oldWidget.gender != widget.gender) {
      _loadData();
    } else if (oldWidget.highlights != widget.highlights ||
        oldWidget.style != widget.style) {
      _updateColorsWithAnimation();
    }
  }

  @override
  void dispose() {
    _animController.removeListener(_onAnimTick);
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final data = await BodyHighlighterAssetLoader.instance.loadModelData(
      widget.gender,
      widget.view,
    );

    if (!mounted) return;

    setState(() {
      _modelData = data;
      _isLoading = false;
      _targetColors = _computeTargetColors(data);
      _oldColors = Map.from(_targetColors);
      _currentColors = Map.from(_targetColors);
    });
  }

  Map<String, Color> _computeTargetColors(BodyModelData data) {
    final map = <String, Color>{};

    for (final region in data.regions) {
      final colorKey = '${region.slug}_${region.side.name}';
      final highlight = _findHighlightForRegion(region.slug, region.side);

      if (highlight != null &&
          highlight.intensity != MuscleIntensity.inactive) {
        map[colorKey] =
            highlight.customColor ??
            widget.style.getColorForIntensity(highlight.intensity);
      } else {
        map[colorKey] = widget.style.inactiveFill;
      }
    }

    return map;
  }

  MuscleHighlight? _findHighlightForRegion(String slug, BodySide regionSide) {
    for (final h in widget.highlights) {
      if (h.muscle == slug) {
        if (h.side == BodySide.common ||
            regionSide == BodySide.common ||
            h.side == regionSide) {
          return h;
        }
      }
    }
    return null;
  }

  void _updateColorsWithAnimation() {
    if (_modelData == null) return;

    _oldColors = Map.from(_currentColors);
    _targetColors = _computeTargetColors(_modelData!);

    _animController.duration = widget.animationDuration;
    _animController.forward(from: 0.0);
  }

  void _onAnimTick() {
    final t = _animProgress.value;
    final interpolated = <String, Color>{};

    _targetColors.forEach((key, targetColor) {
      final startColor = _oldColors[key] ?? widget.style.inactiveFill;
      interpolated[key] = Color.lerp(startColor, targetColor, t) ?? targetColor;
    });

    setState(() {
      _currentColors = interpolated;
    });
  }

  void _handleTap(TapUpDetails details) {
    if (_modelData == null || widget.onMuscleTap == null) return;

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;
    final vb = _modelData!.viewBox;

    final scale = min(size.width / vb.width, size.height / vb.height);
    if (scale <= 0) return;

    final dx = (size.width - vb.width * scale) / 2 - vb.left * scale;
    final dy = (size.height - vb.height * scale) / 2 - vb.top * scale;

    final svgX = (details.localPosition.dx - dx) / scale;
    final svgY = (details.localPosition.dy - dy) / scale;
    final svgPoint = Offset(svgX, svgY);

    // Hit test from topmost layer to bottommost layer
    for (final region in _modelData!.regions.reversed) {
      if (region.contains(svgPoint)) {
        widget.onMuscleTap!(region);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _modelData == null) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: const Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: widget.onMuscleTap != null ? _handleTap : null,
        child: CustomPaint(
          size: Size(
            widget.width ?? _modelData!.viewBox.width,
            widget.height ?? _modelData!.viewBox.height,
          ),
          painter: BodyHighlighterPainter(
            data: _modelData!,
            animatedMuscleColors: _currentColors,
            highlights: widget.highlights,
            style: widget.style,
          ),
        ),
      ),
    );
  }
}
