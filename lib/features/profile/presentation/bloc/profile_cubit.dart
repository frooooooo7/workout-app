import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/models/following_user.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import 'profile_state.dart';

/// Nagłówek własnego profilu: dane, liczniki i obserwowane osoby. Oś czasu
/// ładuje osobno `ProfilePostsCubit`.
class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit(this._repository) : super(const ProfileState());

  final ProfileRepository _repository;

  Future<void> load() => _fetchProfile(isRefresh: false);

  Future<void> refresh() => _fetchProfile(isRefresh: true);

  static bool _isOffline(Object error) =>
      error is ApiException && error.statusCode == null;

  Future<void> _fetchProfile({required bool isRefresh}) async {
    if (isRefresh && state.refreshing) return;
    if (isClosed) return;

    emit(
      state.copyWith(
        loading: !isRefresh && state.profile == null,
        refreshing: isRefresh,
        clearError: true,
      ),
    );

    try {
      final results = await Future.wait([
        _repository.getOwnProfile(),
        _repository.getFollowing(limit: 20),
      ]);
      if (isClosed) return;
      emit(
        state.copyWith(
          profile: results[0] as UserProfile,
          following: results[1] as List<FollowingUser>,
          loading: false,
          refreshing: false,
          offline: false,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      final offline = _isOffline(e);
      final hasProfile = state.profile != null;
      emit(
        state.copyWith(
          loading: false,
          refreshing: false,
          offline: offline,
          errorSeq: state.errorSeq + 1,
          // Wcześniej trafiał tu surowy `ApiException(null): network_error`.
          error: switch ((offline, hasProfile)) {
            (true, false) =>
              'Profil wczyta się, gdy wrócisz online — treningi możesz '
                  'zapisywać bez przeszkód.',
            (true, true) => 'Brak połączenia — pokazuję ostatnie dane profilu.',
            (false, false) => 'Nie udało się wczytać profilu. Spróbuj ponownie.',
            (false, true) => 'Nie udało się odświeżyć profilu.',
          },
        ),
      );
    }
  }

  /// Profil zwrócony przez ekran edycji — widoczny od razu, bez czekania
  /// na ponowne pobranie.
  void applyProfile(UserProfile profile) {
    if (isClosed) return;
    emit(state.copyWith(profile: profile, clearError: true));
  }
}
