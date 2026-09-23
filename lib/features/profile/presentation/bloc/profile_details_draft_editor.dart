import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/models/profile_details.dart';
import '../utils/profile_details_draft.dart';

/// Obsługa pól [ProfileDetailsDraft] dla cubitów z formularzem danych
/// o sobie i celu (onboarding, ustawienia). Wybory można odznaczyć (`null`).
mixin ProfileDetailsDraftEditor<S> on Cubit<S> {
  ProfileDetailsDraft get draft;

  void updateDraft(ProfileDetailsDraft draft);

  void genderChanged(Gender? value) =>
      updateDraft(draft.copyWith(gender: value, clearGender: value == null));

  void birthDateChanged(String value) =>
      updateDraft(draft.copyWith(birthDateText: value));

  void heightChanged(String value) =>
      updateDraft(draft.copyWith(heightText: value));

  void weightChanged(String value) =>
      updateDraft(draft.copyWith(weightText: value));

  void trainingGoalChanged(TrainingGoal? value) => updateDraft(
        draft.copyWith(trainingGoal: value, clearTrainingGoal: value == null),
      );

  void experienceLevelChanged(ExperienceLevel? value) => updateDraft(
        draft.copyWith(
          experienceLevel: value,
          clearExperienceLevel: value == null,
        ),
      );

  void weeklyTrainingDaysChanged(int? value) => updateDraft(
        draft.copyWith(
          weeklyTrainingDays: value,
          clearWeeklyTrainingDays: value == null,
        ),
      );
}
