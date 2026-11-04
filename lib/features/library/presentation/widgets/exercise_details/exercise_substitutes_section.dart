import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../domain/models/exercise.dart';
import '../exercise_card_illustration.dart';
import '../exercise_row.dart';

/// „Zamienniki”: poziomy rząd kart podobnych ćwiczeń (ten sam ruch lub
/// mięsień); dotknięcie otwiera kartę zamiennika.
class ExerciseSubstitutesSection extends StatelessWidget {
  const ExerciseSubstitutesSection({
    super.key,
    required this.exercises,
    required this.onOpen,
  });

  final List<Exercise> exercises;
  final ValueChanged<Exercise> onOpen;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 142,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: exercises.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final exercise = exercises[index];
          final subtitle = ExerciseRow.subtitleFor(exercise);
          return GestureDetector(
            onTap: () => onOpen(exercise),
            child: Container(
              width: 128,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ExerciseCardIllustration(exercise: exercise),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Text(
                      exercise.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11.5,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
