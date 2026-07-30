import 'package:flutter/material.dart';

import '../mapping/exercise_muscle_mapper.dart';
import '../models/body_gender.dart';
import '../models/body_highlighter_style.dart';
import '../models/body_side.dart';
import '../models/muscle_highlight.dart';
import '../models/muscle_intensity.dart';
import '../models/muscle_region.dart';
import '../widgets/front_back_body_highlighter.dart';

class BodyHighlighterDemoPage extends StatefulWidget {
  const BodyHighlighterDemoPage({super.key});

  @override
  State<BodyHighlighterDemoPage> createState() =>
      _BodyHighlighterDemoPageState();
}

class _BodyHighlighterDemoPageState extends State<BodyHighlighterDemoPage> {
  BodyGender _gender = BodyGender.male;
  bool _isDarkMode = true;
  MuscleRegion? _lastTappedRegion;

  Set<MuscleHighlight> _frontHighlights = {
    const MuscleHighlight(muscle: 'chest', intensity: MuscleIntensity.high),
    const MuscleHighlight(
      muscle: 'deltoids',
      intensity: MuscleIntensity.medium,
    ),
    const MuscleHighlight(
      muscle: 'biceps',
      side: BodySide.left,
      intensity: MuscleIntensity.low,
    ),
    const MuscleHighlight(muscle: 'abs', intensity: MuscleIntensity.medium),
  };

  Set<MuscleHighlight> _backHighlights = {
    const MuscleHighlight(
      muscle: 'upper-back',
      intensity: MuscleIntensity.high,
    ),
    const MuscleHighlight(
      muscle: 'triceps',
      side: BodySide.right,
      intensity: MuscleIntensity.high,
    ),
    const MuscleHighlight(muscle: 'lats', intensity: MuscleIntensity.medium),
    const MuscleHighlight(muscle: 'calves', intensity: MuscleIntensity.low),
  };

  void _setChestDayPreset() {
    final highlights = ExerciseMuscleMapper.mapExercisesToHighlights([
      const ExerciseMuscleMapping(
        primaryMuscles: ['chest'],
        secondaryMuscles: ['triceps', 'deltoids'],
        tertiaryMuscles: ['abs'],
      ),
    ]);

    setState(() {
      _frontHighlights = highlights;
      _backHighlights = highlights;
    });
  }

  void _setLegDayPreset() {
    final highlights = ExerciseMuscleMapper.mapExercisesToHighlights([
      const ExerciseMuscleMapping(
        primaryMuscles: ['quadriceps', 'gluteal'],
        secondaryMuscles: ['hamstring', 'calves', 'adductors'],
        tertiaryMuscles: ['abs', 'lower-back'],
      ),
    ]);

    setState(() {
      _frontHighlights = highlights;
      _backHighlights = highlights;
    });
  }

  void _setAsymmetryPreset() {
    setState(() {
      _frontHighlights = {
        const MuscleHighlight(
          muscle: 'biceps',
          side: BodySide.left,
          intensity: MuscleIntensity.high,
        ),
        const MuscleHighlight(
          muscle: 'forearm',
          side: BodySide.left,
          intensity: MuscleIntensity.medium,
        ),
        const MuscleHighlight(
          muscle: 'quadriceps',
          side: BodySide.right,
          intensity: MuscleIntensity.high,
        ),
      };

      _backHighlights = {
        const MuscleHighlight(
          muscle: 'triceps',
          side: BodySide.left,
          intensity: MuscleIntensity.medium,
        ),
        const MuscleHighlight(
          muscle: 'hamstring',
          side: BodySide.right,
          intensity: MuscleIntensity.high,
        ),
      };
    });
  }

  void _setAllLevelsPreset() {
    setState(() {
      _frontHighlights = {
        const MuscleHighlight(muscle: 'chest', intensity: MuscleIntensity.high),
        const MuscleHighlight(muscle: 'abs', intensity: MuscleIntensity.medium),
        const MuscleHighlight(
          muscle: 'quadriceps',
          intensity: MuscleIntensity.low,
        ),
        const MuscleHighlight(
          muscle: 'deltoids',
          intensity: MuscleIntensity.inactive,
        ),
      };

      _backHighlights = {
        const MuscleHighlight(
          muscle: 'upper-back',
          intensity: MuscleIntensity.high,
        ),
        const MuscleHighlight(
          muscle: 'lower-back',
          intensity: MuscleIntensity.medium,
        ),
        const MuscleHighlight(muscle: 'calves', intensity: MuscleIntensity.low),
      };
    });
  }

  void _onRegionTapped(MuscleRegion region) {
    setState(() {
      _lastTappedRegion = region;

      final existingFront = _frontHighlights
          .where(
            (h) =>
                h.muscle == region.slug &&
                (h.side == BodySide.common || h.side == region.side),
          )
          .firstOrNull;

      final existingBack = _backHighlights
          .where(
            (h) =>
                h.muscle == region.slug &&
                (h.side == BodySide.common || h.side == region.side),
          )
          .firstOrNull;

      final current = existingFront ?? existingBack;

      MuscleIntensity nextIntensity;
      if (current == null || current.intensity == MuscleIntensity.inactive) {
        nextIntensity = MuscleIntensity.low;
      } else if (current.intensity == MuscleIntensity.low) {
        nextIntensity = MuscleIntensity.medium;
      } else if (current.intensity == MuscleIntensity.medium) {
        nextIntensity = MuscleIntensity.high;
      } else {
        nextIntensity = MuscleIntensity.inactive;
      }

      final newHighlight = MuscleHighlight(
        muscle: region.slug,
        side: region.side,
        intensity: nextIntensity,
      );

      final updatedFront = Set<MuscleHighlight>.from(_frontHighlights)
        ..removeWhere((h) => h.muscle == region.slug && h.side == region.side)
        ..add(newHighlight);

      final updatedBack = Set<MuscleHighlight>.from(_backHighlights)
        ..removeWhere((h) => h.muscle == region.slug && h.side == region.side)
        ..add(newHighlight);

      _frontHighlights = updatedFront;
      _backHighlights = updatedBack;
    });
  }

  @override
  Widget build(BuildContext context) {
    final style = _isDarkMode
        ? const BodyHighlighterStyle.dark()
        : const BodyHighlighterStyle.light();

    final bgColor = _isDarkMode
        ? const Color(0xFF0F172A)
        : const Color(0xFFF8FAFC);
    final cardColor = _isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final textColor = _isDarkMode ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Flutter Anatomical Body Highlighter'),
        backgroundColor: _isDarkMode
            ? const Color(0xFF1E293B)
            : Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isDarkMode ? Icons.light_mode : Icons.dark_mode),
            tooltip: 'Przełącz motyw',
            onPressed: () => setState(() => _isDarkMode = !_isDarkMode),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              color: cardColor,
              child: Column(
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        SegmentedButton<BodyGender>(
                          segments: const [
                            ButtonSegment(
                              value: BodyGender.male,
                              label: Text('Mężczyzna'),
                              icon: Icon(Icons.male),
                            ),
                            ButtonSegment(
                              value: BodyGender.female,
                              label: Text('Kobieta'),
                              icon: Icon(Icons.female),
                            ),
                          ],
                          selected: {_gender},
                          onSelectionChanged: (set) {
                            setState(() => _gender = set.first);
                          },
                        ),
                        const SizedBox(width: 12),
                        ActionChip(
                          avatar: const Icon(Icons.fitness_center, size: 18),
                          label: const Text('Trening Klatki'),
                          onPressed: _setChestDayPreset,
                        ),
                        const SizedBox(width: 8),
                        ActionChip(
                          avatar: const Icon(Icons.directions_run, size: 18),
                          label: const Text('Trening Nóg'),
                          onPressed: _setLegDayPreset,
                        ),
                        const SizedBox(width: 8),
                        ActionChip(
                          avatar: const Icon(Icons.compare_arrows, size: 18),
                          label: const Text('Asymetria (L/R)'),
                          onPressed: _setAsymmetryPreset,
                        ),
                        const SizedBox(width: 8),
                        ActionChip(
                          avatar: const Icon(Icons.palette, size: 18),
                          label: const Text('Wszystkie Poziomy'),
                          onPressed: _setAllLevelsPreset,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_lastTappedRegion != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        'Kliknięto: ${_lastTappedRegion!.slug.toUpperCase()} | Strona: ${_lastTappedRegion!.side.name} | Widok: ${_lastTappedRegion!.view.name} (ID: ${_lastTappedRegion!.id})',
                        style: TextStyle(
                          color: _isDarkMode
                              ? Colors.blue.shade200
                              : Colors.blue.shade900,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    )
                  else
                    Text(
                      'Kliknij dowolną partię mięśniową, aby zmienić jej podświetlenie.',
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: FrontBackBodyHighlighter(
                  gender: _gender,
                  frontHighlights: _frontHighlights,
                  backHighlights: _backHighlights,
                  style: style,
                  onMuscleTap: _onRegionTapped,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
