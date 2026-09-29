import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../domain/models/training_stats.dart';
import 'stats_format.dart';

/// Pasek zakresów statystyk: pigułka z gotowymi zakresami i przycisk
/// kalendarza dla własnego przedziału dat.
///
/// Wybrany zakres podświetla się kolorem głównym. Przy [StatsRange.custom]
/// żaden z gotowych nie jest podświetlony — świeci przycisk kalendarza, a pod
/// paskiem pojawia się chip z wybranymi datami.
class StatsRangeSelector extends StatelessWidget {
  const StatsRangeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.onPickCustom,
    this.customRange,
  });

  final StatsRange selected;

  /// Gotowy zakres z pigułki albo wyjście z własnego zakresu (×).
  final ValueChanged<StatsRange> onChanged;

  /// Otwiera kalendarz — sam wybór dat robi wołający.
  final VoidCallback onPickCustom;

  /// Daty do chipa; pokazujemy je tylko przy [StatsRange.custom].
  final StatsDateRange? customRange;

  @override
  Widget build(BuildContext context) {
    final custom = selected == StatsRange.custom;
    final range = customRange;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _PresetPill(selected: selected, onChanged: onChanged),
            ),
            const SizedBox(width: AppSpacing.xs),
            _CalendarButton(
              key: const ValueKey('stats-range-calendar'),
              active: custom,
              onTap: () {
                HapticFeedback.selectionClick();
                onPickCustom();
              },
            ),
          ],
        ),
        AnimatedSize(
          duration: _kAnimation,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topLeft,
          child: AnimatedSwitcher(
            duration: _kAnimation,
            switchInCurve: Curves.easeOutCubic,
            // Domyślny układ centruje dzieci — chip ma trzymać się lewej.
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.topLeft,
              children: [...previous, ?current],
            ),
            // Stały klucz: zmiana dat między dwoma własnymi zakresami tylko
            // podmienia tekst, bez przenikania chipa z chipem.
            child: custom && range != null
                ? _RangeChip(
                    key: const ValueKey('stats-range-chip'),
                    range: range,
                    onEdit: onPickCustom,
                    onClear: () {
                      HapticFeedback.selectionClick();
                      onChanged(StatsRange.month);
                    },
                  )
                : const SizedBox.shrink(key: ValueKey('stats-range-none')),
          ),
        ),
      ],
    );
  }
}

const _kAnimation = Duration(milliseconds: 200);

/// Wysokość pigułki i przycisku kalendarza.
const _kControlHeight = 40.0;

/// `12 wrz – 2 paź 2026`. Rok stoi raz na końcu, gdy oba dni są w tym samym
/// roku; przy różnych latach każda data ma własny rok. Jeden dzień to jedna
/// data.
String formatStatsDateRange(StatsDateRange range) {
  final a = range.start;
  final b = range.end;
  final end = '${formatStatsDayMonth(b)} ${b.year}';
  if (a == b) return end;
  final start = a.year == b.year
      ? formatStatsDayMonth(a)
      : '${formatStatsDayMonth(a)} ${a.year}';
  return '$start – $end';
}

/// Pełny opis dla czytnika ekranu (bez skrótów miesięcy).
String _describeRange(StatsDateRange range) {
  if (range.start == range.end) return formatStatsLongDate(range.start);
  return 'od ${formatStatsLongDate(range.start)} '
      'do ${formatStatsLongDate(range.end)}';
}

class _PresetPill extends StatelessWidget {
  const _PresetPill({required this.selected, required this.onChanged});

  final StatsRange selected;
  final ValueChanged<StatsRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _kControlHeight,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          for (final range in StatsRange.presets)
            Expanded(
              child: _RangeOption(
                range: range,
                selected: range == selected,
                onTap: () {
                  if (range == selected) return;
                  HapticFeedback.selectionClick();
                  onChanged(range);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _RangeOption extends StatelessWidget {
  const _RangeOption({
    required this.range,
    required this.selected,
    required this.onTap,
  });

  final StatsRange range;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Zakres ${range.label}',
      excludeSemantics: true,
      // excludeSemantics usuwa akcję GestureDetectora — bez onTap czytnik
      // ekranu ogłasza przycisk, którego nie da się użyć.
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: _kAnimation,
          curve: Curves.easeOutCubic,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: AnimatedDefaultTextStyle(
            duration: _kAnimation,
            style: TextStyle(
              color: selected ? AppColors.onPrimary : AppColors.textSecondary,
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            ),
            // Przy „3 mies.” i większej czcionce systemowej etykieta nie
            // mieści się w piątej części pigułki na wąskim telefonie —
            // zamiast uciętego tekstu skalujemy ją w dół.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(range.label, maxLines: 1),
            ),
          ),
        ),
      ),
    );
  }
}

/// Kwadratowy przycisk obok pigułki; przy własnym zakresie wypełniony kolorem
/// głównym, żeby było widać, że pigułka nie jest już aktywna.
class _CalendarButton extends StatelessWidget {
  const _CalendarButton({super.key, required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: 'Wybierz własny zakres dat',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: _kAnimation,
          curve: Curves.easeOutCubic,
          width: _kControlHeight,
          height: _kControlHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: active ? AppColors.primary : AppColors.border,
            ),
          ),
          child: TweenAnimationBuilder<Color?>(
            duration: _kAnimation,
            curve: Curves.easeOutCubic,
            tween: ColorTween(
              end: active ? AppColors.onPrimary : AppColors.textSecondary,
            ),
            builder: (context, color, _) =>
                Icon(Icons.date_range_rounded, size: 20, color: color),
          ),
        ),
      ),
    );
  }
}

/// Wybrane daty z przyciskiem wyjścia z własnego zakresu. Dotknięcie dat
/// otwiera kalendarz, żeby dało się je poprawić bez zaczynania od zera.
class _RangeChip extends StatelessWidget {
  const _RangeChip({
    super.key,
    required this.range,
    required this.onEdit,
    required this.onClear,
  });

  final StatsDateRange range;
  final VoidCallback onEdit;
  final VoidCallback onClear;

  static const _height = 34.0;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: Container(
          height: _height,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: AppColors.primaryVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            // Rozciągnięcie daje obu polom dotyku pełną wysokość chipa.
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: Semantics(
                  button: true,
                  label: 'Zakres ${_describeRange(range)}, zmień',
                  excludeSemantics: true,
                  onTap: onEdit,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onEdit,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: AppSpacing.sm,
                        right: AppSpacing.xxs,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.date_range_rounded,
                            size: 16,
                            color: AppColors.primaryVariant,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              formatStatsDateRange(range),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Semantics(
                button: true,
                label: 'Wyjdź z własnego zakresu dat',
                excludeSemantics: true,
                onTap: onClear,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onClear,
                  child: const SizedBox(
                    width: _height,
                    height: _height,
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: AppColors.textSecondary,
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
