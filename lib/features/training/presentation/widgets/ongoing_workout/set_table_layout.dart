import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../core/units/weight_unit.dart';
import 'workout_colors.dart';

/// Szerokości kolumn tabeli serii, wspólne dla nagłówka i wierszy: numer,
/// „Poprzednio”, pola (kg, powt., opcjonalnie RIR i tempo) i odhaczenie.
///
/// „Poprzednio” bierze resztę miejsca, a gdy z RIR i tempem na wąskim
/// telefonie zostaje go za mało, ustępuje polom.
class SetTableLayout {
  const SetTableLayout._({
    required this.previousWidth,
    required this.weightWidth,
    required this.repsWidth,
    required this.rirWidth,
    required this.tempoWidth,
  });

  factory SetTableLayout.of(
    double width, {
    required bool hasPrevious,
    required bool showRir,
    required bool showTempo,
    bool showWeight = true,
  }) {
    final weight = showWeight ? _weight : 0.0;
    final preferred = [
      if (showWeight) _weight,
      _reps,
      if (showRir) _rir,
      if (showTempo) _tempo,
    ];
    final inputsWidth = preferred.reduce((a, b) => a + b);
    // Odstępy: po numerze, przed odhaczeniem i między polami.
    final gaps = (preferred.length + 1) * gap;
    final available = width - rowPadding * 2 - badgeWidth - checkWidth - gaps;
    final previous = available - inputsWidth - gap;
    if (hasPrevious && previous >= _minPrevious) {
      return SetTableLayout._(
        previousWidth: previous,
        weightWidth: weight,
        repsWidth: _reps,
        rirWidth: showRir ? _rir : 0,
        tempoWidth: showTempo ? _tempo : 0,
      );
    }
    // Pola mogą się trochę ścisnąć, żeby „Poprzednio” zostało (np. z RIR).
    final squeeze = (available - gap - _minPrevious) / inputsWidth;
    if (hasPrevious && squeeze >= _minSqueeze) {
      return SetTableLayout._(
        previousWidth: _minPrevious,
        weightWidth: weight * squeeze,
        repsWidth: _reps * squeeze,
        rirWidth: showRir ? _rir * squeeze : 0,
        tempoWidth: showTempo ? _tempo * squeeze : 0,
      );
    }
    // Bez kolumny „Poprzednio” pola rosną (z umiarem), resztę zostawiamy
    // pustą; na bardzo wąskim ekranie się kurczą.
    final factor = math.min(available / inputsWidth, 1.4);
    return SetTableLayout._(
      previousWidth: null,
      weightWidth: weight * factor,
      repsWidth: _reps * factor,
      rirWidth: showRir ? _rir * factor : 0,
      tempoWidth: showTempo ? _tempo * factor : 0,
    );
  }

  static const badgeWidth = 30.0;
  static const checkWidth = 44.0;
  static const gap = 8.0;
  static const rowPadding = 6.0;
  static const _weight = 70.0;
  static const _reps = 54.0;
  static const _rir = 44.0;
  static const _tempo = 54.0;
  static const _minPrevious = 72.0;

  /// Najmocniej, jak ściskamy pola, zanim „Poprzednio” ustąpi.
  static const _minSqueeze = 0.8;

  /// `null` — kolumna „Poprzednio” się nie mieści albo nie ma danych.
  final double? previousWidth;

  /// 0 — ćwiczenie na same powtórzenia, bez kolumny ciężaru.
  final double weightWidth;
  final double repsWidth;

  /// 0 — kolumna ukryta.
  final double rirWidth;
  final double tempoWidth;

  bool get showPrevious => previousWidth != null;
  bool get showWeight => weightWidth > 0;
  bool get showRir => rirWidth > 0;
  bool get showTempo => tempoWidth > 0;
}

/// Nagłówek tabeli: `#  POPRZEDNIO  KG  POWT.  RIR  TEMPO`.
class SetTableHeader extends StatelessWidget {
  const SetTableHeader({super.key, required this.layout});

  final SetTableLayout layout;

  @override
  Widget build(BuildContext context) {
    Widget cell(String text, double width, {bool center = true}) => SizedBox(
      width: width,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: center ? Alignment.center : Alignment.centerLeft,
        child: Text(text, maxLines: 1, style: _style),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: SetTableLayout.rowPadding,
      ),
      child: Row(
        children: [
          cell('#', SetTableLayout.badgeWidth),
          const SizedBox(width: SetTableLayout.gap),
          if (layout.showPrevious) ...[
            cell('POPRZEDNIO', layout.previousWidth!, center: false),
            const SizedBox(width: SetTableLayout.gap),
          ] else
            const Spacer(),
          if (layout.showWeight) ...[
            cell(WeightUnits.current.columnLabel, layout.weightWidth),
            const SizedBox(width: SetTableLayout.gap),
          ],
          cell('POWT.', layout.repsWidth),
          if (layout.showRir) ...[
            const SizedBox(width: SetTableLayout.gap),
            cell('RIR', layout.rirWidth),
          ],
          if (layout.showTempo) ...[
            const SizedBox(width: SetTableLayout.gap),
            cell('TEMPO', layout.tempoWidth),
          ],
          const SizedBox(width: SetTableLayout.gap),
          const SizedBox(width: SetTableLayout.checkWidth),
        ],
      ),
    );
  }

  static const _style = TextStyle(
    color: WorkoutColors.textFaint,
    fontSize: 10.5,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.7,
  );
}
