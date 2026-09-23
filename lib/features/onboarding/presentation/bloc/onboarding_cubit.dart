import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_client.dart';
import '../../../profile/domain/models/profile_details.dart';
import '../../../profile/domain/models/user_profile.dart';
import '../../../profile/domain/repositories/profile_repository.dart';
import '../../../profile/presentation/bloc/edit_profile_cubit.dart';
import '../../../profile/presentation/bloc/edit_profile_state.dart';
import '../../../profile/presentation/bloc/profile_details_draft_editor.dart';
import '../../../profile/presentation/utils/profile_details_draft.dart';
import 'onboarding_state.dart';

/// Onboarding po rejestracji. „Dalej” zapisuje bieżący krok na serwerze
/// (przerwany onboarding nic nie gubi), „Pomiń” przechodzi dalej bez
/// zapisu. Ostatni krok oznacza onboarding jako zakończony.
class OnboardingCubit extends Cubit<OnboardingState>
    with ProfileDetailsDraftEditor<OnboardingState> {
  OnboardingCubit(this._repository, {this.onCompleted})
      : super(const OnboardingState(loading: true));

  final ProfileRepository _repository;

  /// Po zakończeniu na serwerze — np. zapis flagi w sesji. Błąd tutaj nie
  /// cofa zakończenia.
  final Future<void> Function(UserProfile profile)? onCompleted;

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearLoadError: true));
    try {
      final profile = await _repository.getOwnProfile();
      if (isClosed) return;
      emit(OnboardingState.fromProfile(profile));
    } catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          loading: false,
          loadError: error is ApiException && error.statusCode == null
              ? 'Brak połączenia z internetem. Spróbuj ponownie.'
              : 'Nie udało się wczytać profilu. Spróbuj ponownie.',
        ),
      );
    }
  }

  void handleChanged(String value) =>
      emit(state.copyWith(handle: value, clearError: true));

  void bioChanged(String value) =>
      emit(state.copyWith(bio: value, clearError: true));

  void avatarPicked(Uint8List bytes, String filename) {
    if (bytes.lengthInBytes > kProfileAvatarMaxBytes) {
      emit(state.copyWith(error: 'Zdjęcie jest za duże — maksymalnie 5 MB.'));
      return;
    }
    emit(
      state.copyWith(
        avatarBytes: bytes,
        avatarFilename: filename,
        clearError: true,
      ),
    );
  }

  void avatarCleared() =>
      emit(state.copyWith(clearAvatar: true, clearError: true));

  void back() {
    if (!state.canGoBack) return;
    final previous = OnboardingStep.values[state.step.index - 1];
    emit(state.copyWith(step: previous, clearError: true));
  }

  /// Zapisuje bieżący krok i przechodzi dalej.
  Future<void> next() async {
    if (!state.canContinue) return;
    await _run(() async {
      switch (state.step) {
        case OnboardingStep.profile:
          await _saveProfileStep();
        case OnboardingStep.body:
          await _saveDetails(state.draft.bodyOnto);
        case OnboardingStep.goal:
          await _saveDetails(state.draft.goalOnto);
          await _complete();
          return;
        case OnboardingStep.done:
          return;
      }
      _advance();
    });
  }

  /// Przechodzi dalej bez zapisu; na ostatnim kroku kończy onboarding.
  Future<void> skip() async {
    if (state.profile == null || state.saving) return;
    if (state.step == OnboardingStep.goal) {
      await _run(_complete);
      return;
    }
    if (state.step == OnboardingStep.done) return;
    _advance();
  }

  Future<void> _saveProfileStep() async {
    final snapshot = state;
    if (snapshot.handleChanged || snapshot.bioChanged) {
      final updated = await _repository.updateProfile(
        handle: snapshot.handleChanged ? normalizeHandle(snapshot.handle) : null,
        bio: snapshot.bioChanged ? snapshot.bio.trim() : null,
      );
      if (isClosed) return;
      // Pola są już na serwerze — ponowna próba wyśle tylko zdjęcie.
      emit(
        state.copyWith(
          profile: updated,
          handle: updated.handle,
          bio: updated.bio ?? '',
        ),
      );
    }
    final bytes = snapshot.avatarBytes;
    if (bytes != null) {
      final updated = await _repository.uploadAvatar(
        bytes,
        snapshot.avatarFilename ?? 'avatar.jpg',
      );
      if (isClosed) return;
      emit(state.copyWith(profile: updated, clearAvatar: true));
    }
  }

  Future<void> _saveDetails(
    ProfileDetails Function(ProfileDetails base) merge,
  ) async {
    final saved = state.profile!.details ?? ProfileDetails.empty;
    final details = merge(saved);
    if (details == saved) return;
    final updated = await _repository.updateProfile(details: details);
    if (isClosed) return;
    emit(state.copyWith(profile: updated));
  }

  Future<void> _complete() async {
    final profile = await _repository.completeOnboarding();
    if (isClosed) return;
    await _notifyCompleted(profile);
    if (isClosed) return;
    emit(state.copyWith(profile: profile, step: OnboardingStep.done));
  }

  Future<void> _run(Future<void> Function() action) async {
    emit(state.copyWith(saving: true, clearError: true));
    try {
      await action();
      if (isClosed) return;
      emit(state.copyWith(saving: false));
    } catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          saving: false,
          error: EditProfileCubit.editProfileErrorMessage(error),
        ),
      );
    }
  }

  void _advance() {
    if (isClosed) return;
    final next = OnboardingStep.values[state.step.index + 1];
    emit(state.copyWith(step: next, clearError: true));
  }

  @override
  ProfileDetailsDraft get draft => state.draft;

  @override
  void updateDraft(ProfileDetailsDraft draft) =>
      emit(state.copyWith(draft: draft, clearError: true));

  Future<void> _notifyCompleted(UserProfile profile) async {
    final callback = onCompleted;
    if (callback == null) return;
    try {
      await callback(profile);
    } catch (_) {
      /* flaga w sesji jest pomocnicza — serwer już ją zapisał */
    }
  }
}
