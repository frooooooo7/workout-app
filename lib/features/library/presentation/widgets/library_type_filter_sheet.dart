import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../domain/models/exercise.dart';
import 'exercise_category_badge.dart';

/// Filtr typu ćwiczenia (wielostaw, izolacja…) pod przyciskiem „tune”
/// w wyszukiwarce. Zwraca nowy zbiór typów albo `null` po zamknięciu bez
/// zatwierdzenia. Pusty zbiór oznacza „wszystkie typy”.
Future<Set<ExerciseCategory>?> showLibraryTypeFilterSheet(
  BuildContext context, {
  required Set<ExerciseCategory> selected,
}) {
  return showModalBottomSheet<Set<ExerciseCategory>>(
    context: context,
    backgroundColor: AppColors.surface,
    barrierColor: Colors.black54,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
    ),
    builder: (_) => _TypeFilterSheet(initial: selected),
  );
}

class _TypeFilterSheet extends StatefulWidget {
  const _TypeFilterSheet({required this.initial});

  final Set<ExerciseCategory> initial;

  @override
  State<_TypeFilterSheet> createState() => _TypeFilterSheetState();
}

class _TypeFilterSheetState extends State<_TypeFilterSheet> {
  late Set<ExerciseCategory> _selected = {...widget.initial};

  void _toggle(ExerciseCategory type) {
    setState(() {
      _selected = _selected.contains(type)
          ? ({..._selected}..remove(type))
          : {..._selected, type};
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Typ ćwiczenia',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
                if (_selected.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(() => _selected = {}),
                    child: const Text('Wyczyść'),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Pokaż tylko wybrane rodzaje ćwiczeń.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.lg),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.9,
              children: [
                for (final type in ExerciseCategory.values)
                  _TypeTile(
                    type: type,
                    selected: _selected.contains(type),
                    onTap: () => _toggle(type),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(_selected),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  _selected.isEmpty
                      ? 'Pokaż wszystkie'
                      : 'Pokaż wybrane (${_selected.length})',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeTile extends StatelessWidget {
  const _TypeTile({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final ExerciseCategory type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = ExerciseCategoryBadge.colorFor(type);
    return Semantics(
      button: true,
      selected: selected,
      label: type.label,
      child: AppPressable(
        onTap: onTap,
        pressedScale: 0.97,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.14)
                : AppColors.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? color.withValues(alpha: 0.6) : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  type.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              AnimatedOpacity(
                opacity: selected ? 1 : 0,
                duration: const Duration(milliseconds: 160),
                child: Icon(Icons.check_rounded, size: 18, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
