import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../domain/models/library_sort.dart';

class LibraryResultsBar extends StatelessWidget {
  const LibraryResultsBar({
    super.key,
    required this.count,
    required this.sort,
    required this.onSortTap,
  });

  final int count;
  final LibrarySort sort;
  final VoidCallback onSortTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$count ĆWICZEŃ',
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        Semantics(
          button: true,
          label: 'Sortuj: ${sort.title}',
          child: AppPressable(
            onTap: onSortTap,
            child: Padding(
              // Pasek jest niski — padding powiększa pole dotyku.
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  const Text(
                    'Sortuj: ',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    switchInCurve: Curves.easeOutCubic,
                    child: Text(
                      sort.label,
                      key: ValueKey(sort),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.primary,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
