import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/models/profile_details.dart';
import '../utils/profile_details_draft.dart';

/// Obsługa pól [ProfileDetailsDraft] dla cubitów z formularzem danych
/// o sobie i celu (onboarding, ustawienia). `null` czyści wartość.
mixin ProfileDetailsDraftEditor<S> on Cubit<S> {
  ProfileDetailsDraft get draft;

  void updateDraft(ProfileDetailsDraft draft);

  void genderChanged(Gender? value) =>
      updateDraft(draft.copyWith(gender: value, clearGender: value == null));

  void birthDateChanged(DateTime? value) => updateDraft(
    draft.copyWith(birthDate: value, clearBirthDate: value == null),
  );

  void heightChanged(int? value) =>
      updateDraft(draft.copyWith(heightCm: value, clearHeight: value == null));

  void weightChanged(double? value) =>
      updateDraft(draft.copyWith(weightKg: value, clearWeight: value == null));

  void trainingGoalChanged(TrainingGoal? value) => updateDraft(
    draft.copyWith(trainingGoal: value, clearTrainingGoal: value == null),
  );

  void experienceLevelChanged(ExperienceLevel? value) => updateDraft(
    draft.copyWith(experienceLevel: value, clearExperienceLevel: value == null),
  );

  void weeklyTrainingDaysChanged(int? value) => updateDraft(
    draft.copyWith(
      weeklyTrainingDays: value,
      clearWeeklyTrainingDays: value == null,
    ),
  );
}
