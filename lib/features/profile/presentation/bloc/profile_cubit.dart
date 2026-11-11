import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import 'profile_state.dart';

/// Nagłówek własnego profilu: dane i liczniki. Oś czasu ładuje osobno
/// `ProfilePostsCubit`.
class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit(this._repository) : super(const ProfileState());

  final ProfileRepository _repository;

  /// Zwiększane przy [applyProfile] — odpowiedź pobrania wysłanego wcześniej
  /// nie może cofnąć profilu, który ekran edycji właśnie zwrócił.
  int _appliedVersion = 0;

  Future<void> load() => _fetchProfile(isRefresh: false);

  Future<void> refresh() => _fetchProfile(isRefresh: true);

  static bool _isOffline(Object error) =>
      error is ApiException && error.statusCode == null;

  Future<void> _fetchProfile({required bool isRefresh}) async {
    if (isRefresh && state.refreshing) return;
    if (isClosed) return;
    final version = _appliedVersion;

    emit(
      state.copyWith(
        loading: !isRefresh && state.profile == null,
        refreshing: isRefresh,
        clearError: true,
      ),
    );

    if (!isRefresh && state.profile == null) {
      // Lokalna kopia profilu z ostatniej wizyty — ekran jest od razu,
      // a świeże dane dochodzą po odpowiedzi serwera.
      UserProfile? cached;
      try {
        cached = await _repository.cachedOwnProfile();
      } catch (_) {
        /* bez kopii czekamy na serwer */
      }
      if (isClosed) return;
      if (cached != null &&
          state.profile == null &&
          version == _appliedVersion) {
        emit(state.copyWith(profile: cached, loading: false));
      }
    }

    try {
      final profile = await _repository.getOwnProfile();
      if (isClosed) return;
      emit(
        state.copyWith(
          profile: version == _appliedVersion ? profile : state.profile,
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
            (false, false) =>
              'Nie udało się wczytać profilu. Spróbuj ponownie.',
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
    _appliedVersion++;
    emit(state.copyWith(profile: profile, clearError: true));
  }
}
