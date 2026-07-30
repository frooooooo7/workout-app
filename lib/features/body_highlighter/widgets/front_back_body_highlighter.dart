import 'package:flutter/material.dart';

import '../models/body_gender.dart';
import '../models/body_highlighter_style.dart';
import '../models/body_view.dart';
import '../models/muscle_highlight.dart';
import '../models/muscle_region.dart';
import 'muscle_body_highlighter.dart';

/// High-level component showing both Front and Back body mannequin views.
/// Adapts responsively to screen size.
class FrontBackBodyHighlighter extends StatelessWidget {
  final BodyGender gender;
  final Set<MuscleHighlight> frontHighlights;
  final Set<MuscleHighlight> backHighlights;
  final BodyHighlighterStyle style;
  final ValueChanged<MuscleRegion>? onMuscleTap;
  final double spacing;

  const FrontBackBodyHighlighter({
    super.key,
    this.gender = BodyGender.male,
    this.frontHighlights = const {},
    this.backHighlights = const {},
    this.style = const BodyHighlighterStyle.dark(),
    this.onMuscleTap,
    this.spacing = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 500;

        final frontWidget = MuscleBodyHighlighter(
          view: BodyView.front,
          gender: gender,
          highlights: frontHighlights,
          style: style,
          onMuscleTap: onMuscleTap,
        );

        final backWidget = MuscleBodyHighlighter(
          view: BodyView.back,
          gender: gender,
          highlights: backHighlights,
          style: style,
          onMuscleTap: onMuscleTap,
        );

        if (isWide) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: frontWidget),
              SizedBox(width: spacing),
              Expanded(child: backWidget),
            ],
          );
        } else {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: frontWidget),
              SizedBox(width: spacing),
              Expanded(child: backWidget),
            ],
          );
        }
      },
    );
  }
}
