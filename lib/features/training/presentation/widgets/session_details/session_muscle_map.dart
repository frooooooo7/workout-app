import 'dart:math' as math;

import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../library/domain/models/exercise.dart';
import '../../../domain/models/training_history_models.dart';
import 'body_muscle_paths.dart';
import 'muscle_load.dart';
import 'session_details_formatters.dart';
import 'session_section_card.dart';

/// Sekcja „mapa mięśni": manekin z przodu i z tyłu z podświetlonymi partiami,
/// obok ranking najmocniej obciążonych mięśni.
///
/// Nie powtarza metryk sesji (czas, serie, objętość) — te żyją wyłącznie
/// w nagłówku ekranu. Tutaj liczy się wyłącznie rozkład obciążenia.
class SessionMuscleMap extends StatefulWidget {
  const SessionMuscleMap({super.key, required this.detail});

  final TrainingSessionDetail detail;

  @override
  State<SessionMuscleMap> createState() => _SessionMuscleMapState();
}

class _SessionMuscleMapState extends State<SessionMuscleMap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late List<MuscleLoad> _loads;
  MuscleGroup? _selected;

  @override
  void initState() {
    super.initState();
    _loads = computeMuscleLoads(widget.detail);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    )..forward();
  }

  @override
  void didUpdateWidget(SessionMuscleMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.detail != widget.detail) {
      _loads = computeMuscleLoads(widget.detail);
      _selected = null;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Map<MuscleGroup, double> get _intensityByMuscle => {
        for (final load in _loads) load.muscle: load.intensity,
      };

  void _toggleSelection(MuscleGroup? muscle) {
    setState(() => _selected = _selected == muscle ? null : muscle);
  }

  @override
  Widget build(BuildContext context) {
    if (_loads.isEmpty) return const _MuscleMapEmpty();

    final intensities = _intensityByMuscle;
    final selectedLoad = _selected == null
        ? null
        : _loads.firstWhere(
            (l) => l.muscle == _selected,
            orElse: () => _loads.first,
          );

    return SessionSectionCard(
      icon: Icons.accessibility_new_rounded,
      title: 'Mapa mięśni',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final figures = AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final view in BodyView.values) ...[
                      _BodyFigure(
                        view: view,
                        intensities: intensities,
                        selected: _selected,
                        progress: _controller.value,
                        onMuscleTap: _toggleSelection,
                      ),
                      if (view != BodyView.values.last)
                        const SizedBox(width: 6),
                    ],
                  ],
                ),
              );

              final ranking = _MuscleRanking(
                loads: _loads,
                selected: _selected,
                onSelect: _toggleSelection,
              );

              // Poniżej ~330 px ranking obok manekinów robi się nieczytelny,
              // więc ląduje pod nimi.
              if (constraints.maxWidth < 330) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: figures),
                    const SizedBox(height: 16),
                    ranking,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  figures,
                  const SizedBox(width: 16),
                  Expanded(child: ranking),
                ],
              );
            },
          ),
          if (selectedLoad != null) ...[
            const SizedBox(height: 14),
            _SelectedMuscleDetail(load: selectedLoad),
          ],
        ],
      ),
    );
  }
}

class _BodyFigure extends StatelessWidget {
  const _BodyFigure({
    required this.view,
    required this.intensities,
    required this.selected,
    required this.progress,
    required this.onMuscleTap,
  });

  final BodyView view;
  final Map<MuscleGroup, double> intensities;
  final MuscleGroup? selected;
  final double progress;
  final ValueChanged<MuscleGroup?> onMuscleTap;

  static const _size = Size(84, 202);

  void _handleTap(Offset localPosition) {
    final fit = _BodyFit.of(_size);
    final designPoint = fit.toDesign(localPosition);
    for (final shape in bodyMuscleShapes(view).reversed) {
      if (shape.path.contains(designPoint)) {
        onMuscleTap(shape.muscle);
        return;
      }
    }
    onMuscleTap(null);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => _handleTap(details.localPosition),
          child: Semantics(
            label: 'Sylwetka — widok ${view.label.toLowerCase()}. '
                'Dotknij mięśnia, aby zobaczyć jego obciążenie.',
            child: CustomPaint(
              size: _size,
              painter: _BodyPainter(
                view: view,
                intensities: intensities,
                selected: selected,
                progress: progress,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          view.label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Dopasowanie przestrzeni projektowej manekina do rozmiaru widgetu.
/// Ta sama transformacja obsługuje rysowanie i trafianie w mięsień.
class _BodyFit {
  const _BodyFit(this.scale, this.offset);

  final double scale;
  final Offset offset;

  factory _BodyFit.of(Size size) {
    final scale = math.min(
      size.width / bodyDesignSize.width,
      size.height / bodyDesignSize.height,
    );
    return _BodyFit(
      scale,
      Offset(
        (size.width - bodyDesignSize.width * scale) / 2,
        (size.height - bodyDesignSize.height * scale) / 2,
      ),
    );
  }

  Offset toDesign(Offset local) => (local - offset) / scale;
}

class _BodyPainter extends CustomPainter {
  const _BodyPainter({
    required this.view,
    required this.intensities,
    required this.selected,
    required this.progress,
  });

  final BodyView view;
  final Map<MuscleGroup, double> intensities;
  final MuscleGroup? selected;
  final double progress;

  Color _fillFor(double intensity) {
    if (intensity <= 0) return AppColors.surfaceVariant;
    final eased = Curves.easeOut.transform(intensity.clamp(0.0, 1.0));
    return Color.lerp(
      AppColors.primary.withValues(alpha: 0.32),
      AppColors.primaryVariant,
      eased,
    )!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final fit = _BodyFit.of(size);
    canvas.save();
    canvas.translate(fit.offset.dx, fit.offset.dy);
    canvas.scale(fit.scale);

    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 / fit.scale
      ..color = AppColors.background.withValues(alpha: 0.85);

    canvas.drawPath(
      bodySilhouette(view),
      Paint()..color = AppColors.surfaceVariant,
    );

    for (final shape in bodyMuscleShapes(view)) {
      final intensity = (intensities[shape.muscle] ?? 0) * progress;
      canvas.drawPath(shape.path, Paint()..color = _fillFor(intensity));
      canvas.drawPath(shape.path, outline);

      if (selected == shape.muscle) {
        canvas.drawPath(
          shape.path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2 / fit.scale
            ..color = Colors.white,
        );
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_BodyPainter old) =>
      old.progress != progress ||
      old.selected != selected ||
      old.view != view ||
      !mapEquals(old.intensities, intensities);
}

class _MuscleRanking extends StatelessWidget {
  const _MuscleRanking({
    required this.loads,
    required this.selected,
    required this.onSelect,
  });

  final List<MuscleLoad> loads;
  final MuscleGroup? selected;
  final ValueChanged<MuscleGroup?> onSelect;

  static const _maxRows = 5;

  @override
  Widget build(BuildContext context) {
    final visible = loads.take(_maxRows).toList(growable: false);
    final rest = loads.length - visible.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'NAJMOCNIEJ OBCIĄŻONE',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 10),
        for (final load in visible)
          _MuscleBar(
            load: load,
            isSelected: load.muscle == selected,
            onTap: () => onSelect(load.muscle),
          ),
        if (rest > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '+$rest ${_moreLabel(rest)}',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  static String _moreLabel(int count) {
    if (count == 1) return 'kolejny mięsień';
    final lastDigit = count % 10;
    final lastTwo = count % 100;
    final isFew = lastDigit >= 2 &&
        lastDigit <= 4 &&
        !(lastTwo >= 12 && lastTwo <= 14);
    return isFew ? 'kolejne mięśnie' : 'kolejnych mięśni';
  }
}

class _MuscleBar extends StatelessWidget {
  const _MuscleBar({
    required this.load,
    required this.isSelected,
    required this.onTap,
  });

  final MuscleLoad load;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: '${load.muscle.label}, ${load.percent} procent obciążenia',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      load.muscle.shortLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${load.percent}%',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: load.intensity),
                  duration: const Duration(milliseconds: 620),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => LinearProgressIndicator(
                    value: value,
                    minHeight: 5,
                    backgroundColor: AppColors.surfaceVariant,
                    valueColor: AlwaysStoppedAnimation(
                      isSelected ? Colors.white : AppColors.primaryVariant,
                    ),
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

class _SelectedMuscleDetail extends StatelessWidget {
  const _SelectedMuscleDetail({required this.load});

  final MuscleLoad load;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      '${load.sets} ${_setsLabel(load.sets)}',
      if (load.volumeKg > 0) formatVolumeKg(load.volumeKg),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  load.muscle.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  parts.join('  ·  '),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${load.percent}%',
            style: const TextStyle(
              color: AppColors.primaryVariant,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  static String _setsLabel(int count) {
    if (count == 1) return 'seria';
    final lastDigit = count % 10;
    final lastTwo = count % 100;
    final isFew = lastDigit >= 2 &&
        lastDigit <= 4 &&
        !(lastTwo >= 12 && lastTwo <= 14);
    return isFew ? 'serie' : 'serii';
  }
}

class _MuscleMapEmpty extends StatelessWidget {
  const _MuscleMapEmpty();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.accessibility_new_rounded,
            color: AppColors.textMuted,
            size: 26,
          ),
          SizedBox(height: 10),
          Text(
            'Brak ukończonych serii — nie ma czego nanieść na mapę mięśni.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

