import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class TrainingHeader extends StatelessWidget {
  const TrainingHeader({
    super.key,
    this.onAddTap,
    this.addTooltip = 'Dodaj trening',
    this.activePlanName,
    this.onActiveTap,
    this.onPlansTap,
    this.onLibraryTap,
  });

  final VoidCallback? onAddTap;
  final String addTooltip;
  final String? activePlanName;
  final VoidCallback? onActiveTap;
  final VoidCallback? onPlansTap;
  final VoidCallback? onLibraryTap;

  @override
  Widget build(BuildContext context) {
    final hasActiveSession =
        activePlanName != null && activePlanName!.trim().isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Trening',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'Co dzisiaj planujesz?',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        if (hasActiveSession) ...[
          _ActiveSessionButton(
            planName: activePlanName!,
            onTap: onActiveTap ?? () {},
          ),
          const SizedBox(width: 10),
        ],
        if (onPlansTap != null) ...[
          HeaderIconButton(
            tooltip: 'Plany treningowe',
            icon: Icons.format_list_bulleted_rounded,
            onTap: onPlansTap!,
          ),
          const SizedBox(width: 10),
        ],
        if (onLibraryTap != null) ...[
          HeaderIconButton(
            tooltip: 'Biblioteka ćwiczeń',
            icon: Icons.menu_book_rounded,
            onTap: onLibraryTap!,
          ),
          const SizedBox(width: 10),
        ],
        _AddButton(
          tooltip: addTooltip,
          onTap: onAddTap ?? () {},
        ),
      ],
    );
  }
}

class _ActiveSessionButton extends StatelessWidget {
  const _ActiveSessionButton({required this.planName, required this.onTap});

  final String planName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Wroc do aktywnego treningu',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 42,
            constraints: const BoxConstraints(maxWidth: 168),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.play_circle_fill_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Trwa',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        planName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HeaderIconButton extends StatelessWidget {
  const HeaderIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.isAccent = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final bool isAccent;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isAccent ? AppColors.primary : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: isAccent ? null : Border.all(color: AppColors.border),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.tooltip, required this.onTap});

  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}
