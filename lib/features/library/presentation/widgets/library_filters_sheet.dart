import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../domain/models/exercise.dart';
import '../../domain/models/library_part.dart';
import '../../domain/models/library_sort.dart';

/// Wybór z arkusza „Filtry”.
class LibraryFilterSelection {
  const LibraryFilterSelection({
    this.muscles = const {},
    this.equipment = const {},
    this.types = const {},
    this.sort = LibrarySort.popular,
  });

  final Set<MuscleGroup> muscles;
  final Set<ExerciseEquipment> equipment;
  final Set<ExerciseCategory> types;
  final LibrarySort sort;
}

/// Mięśnie w arkuszu, po partiach. Grupy zbiorcze (plecy, nogi, barki) są
/// pomijane — ich konkretne mięśnie wystarczą; ćwiczenie z tagiem zbiorczym
/// pasuje do każdego z nich.
const _musclesByRegion = <(String, IconData, List<MuscleGroup>)>[
  ('Klatka', Icons.fitness_center_rounded, [MuscleGroup.chest]),
  (
    'Plecy',
    Icons.accessibility_new_rounded,
    [
      MuscleGroup.lats,
      MuscleGroup.traps,
      MuscleGroup.rhomboids,
      MuscleGroup.lowerBack,
    ],
  ),
  (
    'Barki',
    Icons.sports_gymnastics_rounded,
    [MuscleGroup.frontDelts, MuscleGroup.sideDelts, MuscleGroup.rearDelts],
  ),
  (
    'Ramiona',
    Icons.fitness_center_rounded,
    [MuscleGroup.biceps, MuscleGroup.triceps, MuscleGroup.forearms],
  ),
  ('Core', Icons.self_improvement_rounded, [MuscleGroup.abs, MuscleGroup.obliques]),
  (
    'Nogi',
    Icons.directions_run_rounded,
    [
      MuscleGroup.quads,
      MuscleGroup.hamstrings,
      MuscleGroup.glutes,
      MuscleGroup.calves,
      MuscleGroup.adductors,
    ],
  ),
];

/// Arkusz „Filtry”: mięśnie, sprzęt i typ ćwiczenia. Zwraca nowy wybór albo
/// `null` po zamknięciu bez zatwierdzenia. Puste zbiory — bez ograniczeń.
Future<LibraryFilterSelection?> showLibraryFiltersSheet(
  BuildContext context, {
  required LibraryFilterSelection selected,
  required int Function(LibraryFilterSelection selection) countFor,
}) {
  return showModalBottomSheet<LibraryFilterSelection>(
    context: context,
    backgroundColor: AppColors.surface,
    barrierColor: Colors.black54,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
    ),
    builder: (_) => _FiltersSheet(initial: selected, countFor: countFor),
  );
}

class _FiltersSheet extends StatefulWidget {
  const _FiltersSheet({required this.initial, required this.countFor});

  final LibraryFilterSelection initial;
  final int Function(LibraryFilterSelection selection) countFor;

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late Set<MuscleGroup> _muscles = {...widget.initial.muscles};
  late Set<ExerciseEquipment> _equipment = {...widget.initial.equipment};
  late Set<ExerciseCategory> _types = {...widget.initial.types};
  late LibrarySort _sort = widget.initial.sort;

  LibraryFilterSelection get _selection => LibraryFilterSelection(
    muscles: _muscles,
    equipment: _equipment,
    types: _types,
    sort: _sort,
  );

  int get _count => _muscles.length + _equipment.length + _types.length;

  static Set<T> _toggled<T>(Set<T> set, T value) =>
      set.contains(value) ? ({...set}..remove(value)) : {...set, value};

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            0,
          ),
          child: Column(
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
                      'Filtry',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  if (_count > 0)
                    TextButton(
                      onPressed: () => setState(() {
                        _muscles = {};
                        _equipment = {};
                        _types = {};
                      }),
                      child: const Text('Wyczyść'),
                    ),
                ],
              ),
            ],
          ),
        ),
        Flexible(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            shrinkWrap: true,
            children: [
              const _Heading('Mięśnie'),
              for (final (region, icon, group) in _musclesByRegion) ...[
                _SubHeading(region, icon),
                _Chips(
                  children: [
                    for (final muscle in group)
                      _FilterChip(
                        label: muscle.label,
                        selected: _muscles.contains(muscle),
                        onTap: () =>
                            setState(() => _muscles = _toggled(_muscles, muscle)),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              const _Heading('Sprzęt'),
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Ćwiczenia bez podanego sprzętu są w „Inne”.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                ),
              ),
              _Chips(
                children: [
                  for (final item in ExerciseEquipment.values)
                    _FilterChip(
                      label: item.label,
                      selected: _equipment.contains(item),
                      onTap: () => setState(
                        () => _equipment = _toggled(_equipment, item),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              const _Heading('Typ ćwiczenia'),
              _Chips(
                children: [
                  for (final type in ExerciseCategory.values)
                    _FilterChip(
                      label: type.label,
                      selected: _types.contains(type),
                      onTap: () =>
                          setState(() => _types = _toggled(_types, type)),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              const _Heading('Sortowanie'),
              _Chips(
                children: [
                  for (final sort in LibrarySort.values)
                    _FilterChip(
                      label: sort.label,
                      selected: _sort == sort,
                      onTap: () => setState(() => _sort = sort),
                    ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(_selection),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text('Pokaż ${exerciseCountLabel(widget.countFor(_selection))}'),
            ),
          ),
        ),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 4),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: AppColors.textLabel,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    ),
  );
}

class _SubHeading extends StatelessWidget {
  const _SubHeading(this.text, this.icon);

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 6),
    child: Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _Chips extends StatelessWidget {
  const _Chips({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 8, runSpacing: 8, children: children);
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: AppPressable(
        onTap: onTap,
        pressedScale: 0.97,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.16)
                : AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.7)
                  : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.textPrimary : AppColors.textSecondary,
              fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
