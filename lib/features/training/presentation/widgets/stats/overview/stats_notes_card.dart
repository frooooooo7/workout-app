import 'package:flutter/material.dart';

import '../../../../../../core/theme/app_colors.dart';
import '../../../../domain/models/training_stats.dart';
import '../../../../../../core/widgets/app_pressable.dart';

/// Jedna uwaga „do poprawy” z opcjonalnym przejściem do danych.
class StatsNote {
  const StatsNote({required this.text, this.onTap});

  final String text;
  final VoidCallback? onTap;
}

/// Najwyżej [max] uwag z wniosków o tonie „uwaga”. Wniosek o bezczynności
/// dotyczy dzisiaj, więc przy oglądaniu minionego okresu odpada.
List<StatsNote> buildStatsNotes(
  TrainingStatsSnapshot s, {
  required VoidCallback? Function(StatsInsight) onOpen,
  int max = 2,
}) {
  final notes = <StatsNote>[];
  for (final insight in s.insights) {
    if (insight.tone != StatsInsightTone.attention) continue;
    if (insight.kind == StatsInsightKind.inactivity && s.offset > 0) continue;
    notes.add(StatsNote(text: insight.text, onTap: onOpen(insight)));
    if (notes.length == max) break;
  }
  return notes;
}

/// Karta z uwagami; gdy nie ma nic do poprawy, jej po prostu nie ma.
class StatsNotesCard extends StatelessWidget {
  const StatsNotesCard({super.key, required this.notes});

  final List<StatsNote> notes;

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < notes.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                indent: 16,
                endIndent: 16,
                color: AppColors.border.withValues(alpha: 0.7),
              ),
            _NoteRow(note: notes[i]),
          ],
        ],
      ),
    );
  }
}

class _NoteRow extends StatelessWidget {
  const _NoteRow({required this.note});

  final StatsNote note;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.statAmber,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              note.text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (note.onTap != null)
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.textMuted,
            ),
        ],
      ),
    );
    if (note.onTap == null) return row;
    return Semantics(
      button: true,
      label: note.text,
      excludeSemantics: true,
      onTap: note.onTap,
      child: AppPressable(pressedScale: 0.99, onTap: note.onTap, child: row),
    );
  }
}
