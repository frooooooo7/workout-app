import 'package:flutter/material.dart';
import '../../domain/onboarding_data.dart';
import '../widgets/onboarding_scaffold.dart';
import '../../../../core/theme/app_colors.dart';
import 'onboarding_days_screen.dart';

class OnboardingGoalScreen extends StatefulWidget {
  const OnboardingGoalScreen({super.key, required this.data});

  final OnboardingData data;

  @override
  State<OnboardingGoalScreen> createState() => _OnboardingGoalScreenState();
}

class _OnboardingGoalScreenState extends State<OnboardingGoalScreen> {
  FitnessGoal? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.data.fitnessGoal;
  }

  void _handleNext() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => OnboardingDaysScreen(
        data: widget.data.copyWith(fitnessGoal: _selected),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      step: 5,
      totalSteps: 6,
      title: 'Twój główny cel',
      subtitle: 'Wybierz to, co najbardziej pasuje do Twoich ambicji.',
      onBack: () => Navigator.of(context).pop(),
      onSkip: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => OnboardingDaysScreen(data: widget.data),
      )),
      onNext: _handleNext,
      nextEnabled: _selected != null,
      child: ListView(
        children: [
          _GoalCard(
            emoji: '💪',
            title: 'Zbuduj masę mięśniową',
            description: 'Rozbuduj sylwetkę i zwiększ obwody mięśni',
            selected: _selected == FitnessGoal.buildMuscle,
            onTap: () => setState(() => _selected = FitnessGoal.buildMuscle),
          ),
          const SizedBox(height: 10),
          _GoalCard(
            emoji: '🔥',
            title: 'Schudnij / redukcja',
            description: 'Spalaj tkankę tłuszczową i chudnij w zdrowy sposób',
            selected: _selected == FitnessGoal.loseWeight,
            onTap: () => setState(() => _selected = FitnessGoal.loseWeight),
          ),
          const SizedBox(height: 10),
          _GoalCard(
            emoji: '🏋️',
            title: 'Zwiększ siłę',
            description: 'Bij rekordy na martwym ciągu, przysiadzie i wyciskaniu',
            selected: _selected == FitnessGoal.getStronger,
            onTap: () => setState(() => _selected = FitnessGoal.getStronger),
          ),
          const SizedBox(height: 10),
          _GoalCard(
            emoji: '🏃',
            title: 'Popraw kondycję',
            description: 'Zwiększ wytrzymałość i wydolność aerobową',
            selected: _selected == FitnessGoal.improveEndurance,
            onTap: () => setState(() => _selected = FitnessGoal.improveEndurance),
          ),
          const SizedBox(height: 10),
          _GoalCard(
            emoji: '🌿',
            title: 'Bądź aktywny i zdrowy',
            description: 'Regularna aktywność dla dobrego samopoczucia',
            selected: _selected == FitnessGoal.stayHealthy,
            onTap: () => setState(() => _selected = FitnessGoal.stayHealthy),
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.emoji,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
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
            Text(emoji, style: const TextStyle(fontSize: 28)),
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
                  const SizedBox(height: 3),
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
