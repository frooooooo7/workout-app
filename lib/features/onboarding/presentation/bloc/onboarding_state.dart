import 'dart:typed_data';

import '../../../profile/domain/models/user_profile.dart';
import '../../../profile/presentation/bloc/edit_profile_state.dart';
import '../../../profile/presentation/utils/profile_details_draft.dart';

/// Kroki po założeniu konta: profil publiczny → dane o sobie → cel.
enum OnboardingStep { profile, body, goal, done }

class OnboardingState {
  const OnboardingState({
    this.step = OnboardingStep.profile,
    this.profile,
    this.loading = false,
    this.loadError,
    this.handle = '',
    this.bio = '',
    this.avatarBytes,
    this.avatarFilename,
    this.draft = const ProfileDetailsDraft(),
    this.saving = false,
    this.error,
  });

  factory OnboardingState.fromProfile(UserProfile profile) {
    return OnboardingState(
      profile: profile,
      handle: profile.handle,
      bio: profile.bio ?? '',
      draft: ProfileDetailsDraft.fromDetails(profile.details),
    );
  }

  final OnboardingStep step;

  /// Profil zapisany na serwerze — aktualizowany po każdym zapisie kroku.
  final UserProfile? profile;
  final bool loading;
  final String? loadError;

  final String handle;
  final String bio;

  /// Wybrane, jeszcze niewysłane zdjęcie.
  final Uint8List? avatarBytes;
  final String? avatarFilename;

  final ProfileDetailsDraft draft;

  final bool saving;
  final String? error;

  bool get handleChanged =>
      profile != null && normalizeHandle(handle) != profile!.handle;

  bool get bioChanged => profile != null && bio.trim() != (profile!.bio ?? '');

  String? get handleError => handleChanged ? handleInputError(handle) : null;

  String? get bioError => bio.trim().length > kProfileBioMaxLength
      ? 'Opis może mieć maksymalnie $kProfileBioMaxLength znaków.'
      : null;

  /// Czy „Dalej” może zapisać bieżący krok.
  bool get canContinue {
    if (profile == null || saving) return false;
    return switch (step) {
      OnboardingStep.profile => handleError == null && bioError == null,
      OnboardingStep.body || OnboardingStep.goal || OnboardingStep.done => true,
    };
  }

  bool get canGoBack =>
      !saving && (step == OnboardingStep.body || step == OnboardingStep.goal);

  OnboardingState copyWith({
    OnboardingStep? step,
    UserProfile? profile,
    bool? loading,
    String? loadError,
    bool clearLoadError = false,
    String? handle,
    String? bio,
    Uint8List? avatarBytes,
    String? avatarFilename,
    bool clearAvatar = false,
    ProfileDetailsDraft? draft,
    bool? saving,
    String? error,
    bool clearError = false,
  }) {
    return OnboardingState(
      step: step ?? this.step,
      profile: profile ?? this.profile,
      loading: loading ?? this.loading,
      loadError: clearLoadError ? null : (loadError ?? this.loadError),
      handle: handle ?? this.handle,
      bio: bio ?? this.bio,
      avatarBytes: clearAvatar ? null : (avatarBytes ?? this.avatarBytes),
      avatarFilename: clearAvatar
          ? null
          : (avatarFilename ?? this.avatarFilename),
      draft: draft ?? this.draft,
      saving: saving ?? this.saving,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
