import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/exercise.dart';

class LibraryFilterChips extends StatelessWidget {
  const LibraryFilterChips({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final LibraryFilter selected;
  final ValueChanged<LibraryFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: LibraryFilter.values.map((filter) {
          final isSelected = filter == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _FilterChip(
              filter: filter,
              isSelected: isSelected,
              onTap: () => onSelected(filter),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.filter,
    required this.isSelected,
    required this.onTap,
  });

  final LibraryFilter filter;
  final bool isSelected;
  final VoidCallback onTap;

  String get _label => switch (filter) {
        LibraryFilter.all => 'Wszystkie',
        LibraryFilter.mine => 'Moje ćwiczenia',
        LibraryFilter.favourite => 'Ulubione',
        LibraryFilter.recent => 'Ostatnio używane',
      };

  IconData get _icon => switch (filter) {
        LibraryFilter.all => Icons.grid_view_rounded,
        LibraryFilter.mine => Icons.bookmark_rounded,
        LibraryFilter.favourite => Icons.star_rounded,
        LibraryFilter.recent => Icons.access_time_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.18)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _icon,
              size: 14,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              _label,
              style: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
