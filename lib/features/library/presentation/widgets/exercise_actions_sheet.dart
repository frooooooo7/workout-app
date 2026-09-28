import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_action_sheet.dart';
import '../../domain/models/exercise.dart';
import 'exercise_category_badge.dart';
import 'exercise_thumbnail.dart';

enum ExerciseAction { details, favourite, edit, delete }

/// Menu „więcej” ćwiczenia — z siatki biblioteki i z karty ćwiczenia.
/// Edycja i usuwanie są tylko dla własnych ćwiczeń.
Future<ExerciseAction?> showExerciseActionsSheet(
  BuildContext context, {
  required Exercise exercise,
  bool includeDetails = true,
}) {
  return showAppActionSheet<ExerciseAction>(
    context,
    header: ExerciseSheetHeader(exercise: exercise),
    actions: [
      if (includeDetails)
        const AppSheetAction(
          value: ExerciseAction.details,
          icon: Icons.open_in_full_rounded,
          label: 'Karta ćwiczenia',
          subtitle: 'Mięśnie, opis i Twoje rekordy',
        ),
      AppSheetAction(
        value: ExerciseAction.favourite,
        icon: exercise.isFavourite
            ? Icons.star_outline_rounded
            : Icons.star_rounded,
        label: exercise.isFavourite
            ? 'Usuń z ulubionych'
            : 'Dodaj do ulubionych',
      ),
      if (exercise.isMine) ...[
        const AppSheetAction(
          value: ExerciseAction.edit,
          icon: Icons.edit_outlined,
          label: 'Edytuj ćwiczenie',
        ),
        const AppSheetAction(
          value: ExerciseAction.delete,
          icon: Icons.delete_outline_rounded,
          label: 'Usuń ćwiczenie',
          destructive: true,
        ),
      ],
    ],
  );
}

Future<bool> confirmDeleteExercise(BuildContext context, Exercise exercise) {
  return showAppConfirmDialog(
    context,
    title: 'Usunąć ćwiczenie?',
    message:
        '„${exercise.name}” zniknie z biblioteki. Zapisane treningi '
        'pozostaną bez zmian.',
  );
}

/// Nagłówek arkusza: miniatura, nazwa i kategoria ćwiczenia.
class ExerciseSheetHeader extends StatelessWidget {
  const ExerciseSheetHeader({super.key, required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final accent = ExerciseCategoryBadge.colorFor(exercise.category);
    return Row(
      children: [
        ExerciseThumbnail(
          imageUrl: exercise.imageUrl,
          size: 48,
          borderRadius: 12,
          backgroundColor: accent.withValues(alpha: 0.12),
          borderColor: AppColors.border,
          placeholder: Icon(
            Icons.fitness_center_rounded,
            size: 22,
            color: accent.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                exercise.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                [
                  exercise.category.label,
                  ...exercise.workingMuscles.take(2).map((m) => m.shortLabel),
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
