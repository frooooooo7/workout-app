import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';

enum HistorySegment {
  sessions,
  stats;

  String get label => switch (this) {
    HistorySegment.sessions => 'Sesje',
    HistorySegment.stats => 'Statystyki',
  };

  IconData get icon => switch (this) {
    HistorySegment.sessions => Icons.format_list_bulleted_rounded,
    HistorySegment.stats => Icons.insights_rounded,
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

  @override
  Widget build(BuildContext context) {
    const segments = HistorySegment.values;
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md + 2),
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
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppRadius.md - 2),
                  border: Border.all(color: AppColors.border),
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
    final color = selected ? AppColors.textPrimary : AppColors.textSecondary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(segment.icon, size: 16, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              color: color,
              fontSize: 13.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            ),
            child: Text(
              segment.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}
