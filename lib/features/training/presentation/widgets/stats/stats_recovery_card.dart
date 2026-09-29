import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/polish_plural.dart';
import '../../../../library/domain/models/exercise.dart';
import '../../../domain/models/training_stats.dart';
import '../session_details/session_section_card.dart';
import 'stats_format.dart';

/// Regeneracja: kiedy ostatnio pracowała każda pozycja rankingu mięśni
/// i ile serii tygodniowo dostaje w wybranym zakresie.
class StatsRecoveryCard extends StatefulWidget {
  const StatsRecoveryCard({super.key, required this.recovery});

  /// Od ostatnio trenowanej pozycji.
  final List<MuscleRecoveryStat> recovery;

  @override
  State<StatsRecoveryCard> createState() => _StatsRecoveryCardState();
}

class _StatsRecoveryCardState extends State<StatsRecoveryCard> {
  static const _collapsedRows = 6;

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final all = widget.recovery;
    final visible = _expanded ? all : all.take(_collapsedRows).toList();
    return SessionSectionCard(
      icon: Icons.self_improvement_rounded,
      title: 'Regeneracja',
      child: all.isEmpty
          ? const _EmptyNote()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < visible.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.border.withValues(alpha: 0.5),
                    ),
                  _RecoveryRow(stat: visible[i]),
                ],
                if (all.length > _collapsedRows)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setState(() => _expanded = !_expanded),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primaryVariant,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        visualDensity: VisualDensity.compact,
                        textStyle: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      icon: Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 18,
                      ),
                      label: Text(_expanded ? 'Zwiń' : 'Pokaż wszystkie'),
                    ),
                  ),
                const SizedBox(height: AppSpacing.xs),
                const Text(
                  'Orientacyjnie 10–20 serii tygodniowo na partię wystarcza '
                  'większości osób do przyrostu siły i masy.',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ],
            ),
    );
  }
}

/// Grupy zbiorcze pełną nazwą („Nogi”, „Plecy”), granularne skróconą.
String _label(MuscleGroup group) =>
    group.isCoarse ? group.label : group.shortLabel;

/// Status regeneracji wynika wyłącznie z liczby dni od ostatniego treningu.
enum _RecoveryStatus {
  recovering,
  ready,
  longAgo;

  static _RecoveryStatus of(int daysSince) {
    if (daysSince <= 1) return _RecoveryStatus.recovering;
    if (daysSince <= 6) return _RecoveryStatus.ready;
    return _RecoveryStatus.longAgo;
  }

  String get label => switch (this) {
    _RecoveryStatus.recovering => 'Regeneracja',
    _RecoveryStatus.ready => 'Gotowe',
    _RecoveryStatus.longAgo => 'Dawno bez treningu',
  };

  Color get color => switch (this) {
    _RecoveryStatus.recovering => AppColors.statAmber,
    _RecoveryStatus.ready => AppColors.statTeal,
    _RecoveryStatus.longAgo => AppColors.textSecondary,
  };

  Color get background => switch (this) {
    _RecoveryStatus.longAgo => AppColors.surfaceVariant,
    _ => color.withValues(alpha: 0.12),
  };

  Color get border => switch (this) {
    _RecoveryStatus.longAgo => AppColors.border,
    _ => color.withValues(alpha: 0.3),
  };
}

/// „dziś”, „wczoraj”, „5 dni temu”, „2 miesiące temu”, „rok temu”.
String _relativeText(int daysSince) {
  if (daysSince <= 0) return 'dziś';
  if (daysSince == 1) return 'wczoraj';
  if (daysSince < 60) {
    return '$daysSince ${polishPlural(daysSince, 'dzień', 'dni', 'dni')} temu';
  }
  if (daysSince < 365) {
    final months = daysSince ~/ 30;
    return '$months ${polishPlural(months, 'miesiąc', 'miesiące', 'miesięcy')} '
        'temu';
  }
  final years = daysSince ~/ 365;
  if (years == 1) return 'rok temu';
  return '$years ${polishPlural(years, 'rok', 'lata', 'lat')} temu';
}

/// Serie bywają ułamkowe — „8,5 serii” (ułamek zawsze w dopełniaczu).
String _setsUnit(double sets) {
  final rounded = double.parse(sets.toStringAsFixed(1));
  if (rounded != rounded.roundToDouble()) return 'serii';
  return polishPlural(rounded.round(), 'seria', 'serie', 'serii');
}

class _RecoveryRow extends StatelessWidget {
  const _RecoveryRow({required this.stat});

  final MuscleRecoveryStat stat;

  /// Wartość, od której tygodniowa objętość zaczyna wystarczać.
  static const _target = 10.0;

  /// Wartość, przy której pasek jest pełny.
  static const _full = 20.0;

  @override
  Widget build(BuildContext context) {
    final status = _RecoveryStatus.of(stat.daysSince);
    final name = _label(stat.muscle);
    final relative = _relativeText(stat.daysSince);
    final weekly = formatStatsDecimal(stat.setsPerWeek);
    final unit = _setsUnit(stat.setsPerWeek);
    final idle = double.parse(stat.setsPerWeek.toStringAsFixed(1)) == 0;
    final fill = (stat.setsPerWeek / _full).clamp(0.0, 1.0);
    final barColor = stat.setsPerWeek >= _target
        ? AppColors.statTeal
        : AppColors.statIndigo;

    return Semantics(
      container: true,
      excludeSemantics: true,
      label:
          '$name: ostatnio $relative, ${status.label.toLowerCase()}, '
          '$weekly $unit tygodniowo',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) => Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  // Przy dużej czcionce pigułka nie może wypchnąć nazwy.
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth * 0.62,
                    ),
                    child: _StatusPill(status: status),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Expanded(
                  child: Text(
                    relative,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: weekly,
                          style: TextStyle(
                            color: idle
                                ? AppColors.textMuted
                                : AppColors.textPrimary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        TextSpan(
                          text: ' $unit / tydz.',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            _WeeklyBar(fill: fill, markerAt: _target / _full, color: barColor),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final _RecoveryStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: status.background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: status.border),
      ),
      child: Text(
        status.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: status.color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
      ),
    );
  }
}

/// Cienki pasek objętości tygodniowej z subtelnym znacznikiem progu.
class _WeeklyBar extends StatelessWidget {
  const _WeeklyBar({
    required this.fill,
    required this.markerAt,
    required this.color,
  });

  final double fill;
  final double markerAt;
  final Color color;

  static const _trackHeight = 5.0;
  static const _markerOverhang = 2.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return SizedBox(
          height: _trackHeight + _markerOverhang * 2,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: _markerOverhang,
                height: _trackHeight,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: fill),
                    duration: const Duration(milliseconds: 520),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: value,
                      minHeight: _trackHeight,
                      backgroundColor: AppColors.chartTrack,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: width * markerAt - 0.75,
                top: 0,
                bottom: 0,
                width: 1.5,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(
          Icons.self_improvement_rounded,
          size: 18,
          color: AppColors.textMuted,
        ),
        SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            'Brak danych o partiach — przypisz mięśnie do ćwiczeń.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
