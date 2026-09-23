import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/models/profile_details.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../utils/profile_details_draft.dart';
import 'edit_profile_cubit.dart';
import 'profile_details_draft_editor.dart';

class ProfileDetailsState {
  const ProfileDetailsState({
    this.initial,
    this.loading = false,
    this.loadError,
    this.draft = const ProfileDetailsDraft(),
    this.saving = false,
    this.error,
    this.saved,
  });

  /// Profil zapisany na serwerze — punkt odniesienia dla „czy są zmiany”.
  final UserProfile? initial;
  final bool loading;
  final String? loadError;
  final ProfileDetailsDraft draft;
  final bool saving;
  final String? error;

  /// Ustawiane po udanym zapisie — ekran się zamyka.
  final UserProfile? saved;

  ProfileDetails get savedDetails => initial?.details ?? ProfileDetails.empty;

  bool get hasChanges => initial != null && draft.toDetails() != savedDetails;

  bool get canSave => initial != null && !saving && hasChanges;

  ProfileDetailsState copyWith({
    UserProfile? initial,
    bool? loading,
    String? loadError,
    bool clearLoadError = false,
    ProfileDetailsDraft? draft,
    bool? saving,
    String? error,
    bool clearError = false,
    UserProfile? saved,
  }) {
    return ProfileDetailsState(
      initial: initial ?? this.initial,
      loading: loading ?? this.loading,
      loadError: clearLoadError ? null : (loadError ?? this.loadError),
      draft: draft ?? this.draft,
      saving: saving ?? this.saving,
      error: clearError ? null : (error ?? this.error),
      saved: saved ?? this.saved,
    );
  }
}

/// Edycja prywatnych danych o sobie i celu (Ustawienia → „Dane i cele”).
class ProfileDetailsCubit extends Cubit<ProfileDetailsState>
    with ProfileDetailsDraftEditor<ProfileDetailsState> {
  ProfileDetailsCubit(this._repository)
    : super(const ProfileDetailsState(loading: true));

  final ProfileRepository _repository;

  @override
  ProfileDetailsDraft get draft => state.draft;

  @override
  void updateDraft(ProfileDetailsDraft draft) =>
      emit(state.copyWith(draft: draft, clearError: true));

  /// Dane o sobie są tylko w `/profile/me` — zawsze świeży odczyt.
  Future<void> load() async {
    emit(state.copyWith(loading: true, clearLoadError: true));
    try {
      final profile = await _repository.getOwnProfile();
      if (isClosed) return;
      emit(
        ProfileDetailsState(
          initial: profile,
          draft: ProfileDetailsDraft.fromDetails(profile.details),
        ),
      );
    } catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          loading: false,
          loadError: error is ApiException && error.statusCode == null
              ? 'Brak połączenia z internetem. Spróbuj ponownie.'
              : 'Nie udało się wczytać danych. Spróbuj ponownie.',
        ),
      );
    }
  }

  Future<void> save() async {
    if (!state.canSave) return;
    emit(state.copyWith(saving: true, clearError: true));
    try {
      final updated = await _repository.updateProfile(
        details: state.draft.toDetails(),
      );
      if (isClosed) return;
      emit(state.copyWith(initial: updated, saving: false, saved: updated));
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
}
