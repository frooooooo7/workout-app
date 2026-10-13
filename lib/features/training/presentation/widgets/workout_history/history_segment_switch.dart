import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_typography.dart';

enum HistorySegment {
  sessions,
  stats;

  String get label => switch (this) {
    HistorySegment.sessions => 'Sesje',
    HistorySegment.stats => 'Statystyki',
  };
}

/// Dwie podzakładki Historii z przesuwanym podświetleniem.
class HistorySegmentSwitch extends StatelessWidget {
  const HistorySegmentSwitch({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final HistorySegment selected;
  final ValueChanged<HistorySegment> onChanged;

  /// Tło wybranej podzakładki — o ton jaśniejsze od [AppColors.surfaceVariant],
  /// żeby odcinało się od tła przełącznika.
  static const _selectedFill = Color(0xFF222A3C);

  @override
  Widget build(BuildContext context) {
    const segments = HistorySegment.values;
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.tile),
        border: Border.all(color: AppColors.border),
      ),
      child: Stack(
        // Wiersz segmentów musi mieć pełną wysokość — inaczej etykiety siedzą
        // u góry, a dolna połowa pigułki nie reaguje na dotyk.
        fit: StackFit.expand,
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: selected == HistorySegment.sessions
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 1 / segments.length,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _selectedFill,
                  borderRadius: BorderRadius.circular(AppRadius.md - 2),
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (final segment in segments)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: segment == selected,
                    excludeSemantics: true,
                    label: segment.label,
                    onTap: () => onChanged(segment),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (segment == selected) return;
                        HapticFeedback.selectionClick();
                        onChanged(segment);
                      },
                      child: _SegmentLabel(
                        segment: segment,
                        selected: segment == selected,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SegmentLabel extends StatelessWidget {
  const _SegmentLabel({required this.segment, required this.selected});

  final HistorySegment segment;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 200),
        style: TextStyle(
          fontFamily: AppFonts.ui,
          color: selected ? AppColors.textPrimary : AppColors.textSecondary,
          fontSize: 14,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
        ),
        child: Text(
          segment.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
