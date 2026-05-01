import 'package:flutter/material.dart';
import '../../domain/onboarding_data.dart';
import '../widgets/onboarding_scaffold.dart';
import '../../../../core/theme/app_colors.dart';
import 'onboarding_goal_screen.dart';

class OnboardingActivityScreen extends StatefulWidget {
  const OnboardingActivityScreen({super.key, required this.data});

  final OnboardingData data;

  @override
  State<OnboardingActivityScreen> createState() =>
      _OnboardingActivityScreenState();
}

class _OnboardingActivityScreenState extends State<OnboardingActivityScreen> {
  ActivityLevel? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.data.activityLevel;
  }

  void _handleNext() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => OnboardingGoalScreen(
        data: widget.data.copyWith(activityLevel: _selected),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      step: 4,
      totalSteps: 6,
      title: 'Twój poziom\naktywności',
      subtitle: 'Jak aktywny jesteś na co dzień poza siłownią?',
      onBack: () => Navigator.of(context).pop(),
      onSkip: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => OnboardingGoalScreen(data: widget.data),
      )),
      onNext: _handleNext,
      nextEnabled: _selected != null,
      child: ListView(
        children: [
          _ActivityCard(
            icon: Icons.chair_outlined,
            iconColor: const Color(0xFF6C47FF),
            title: 'Siedzący',
            description: 'Praca przy biurku, mała aktywność fizyczna',
            selected: _selected == ActivityLevel.sedentary,
            onTap: () => setState(() => _selected = ActivityLevel.sedentary),
          ),
          const SizedBox(height: 10),
          _ActivityCard(
            icon: Icons.directions_walk_rounded,
            iconColor: const Color(0xFF22C55E),
            title: 'Lekko aktywny',
            description: '1–2 treningi w tygodniu, spacery',
            selected: _selected == ActivityLevel.light,
            onTap: () => setState(() => _selected = ActivityLevel.light),
          ),
          const SizedBox(height: 10),
          _ActivityCard(
            icon: Icons.directions_run_rounded,
            iconColor: const Color(0xFFF59E0B),
            title: 'Umiarkowanie aktywny',
            description: '3–4 treningi w tygodniu',
            selected: _selected == ActivityLevel.moderate,
            onTap: () => setState(() => _selected = ActivityLevel.moderate),
          ),
          const SizedBox(height: 10),
          _ActivityCard(
            icon: Icons.bolt_rounded,
            iconColor: const Color(0xFFEF4444),
            title: 'Bardzo aktywny',
            description: '5+ treningów w tygodniu, intensywny tryb',
            selected: _selected == ActivityLevel.active,
            onTap: () => setState(() => _selected = ActivityLevel.active),
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: selected ? Colors.white : AppColors.textSecondary,
                      fontSize: 15,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? AppColors.primary : AppColors.border,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
