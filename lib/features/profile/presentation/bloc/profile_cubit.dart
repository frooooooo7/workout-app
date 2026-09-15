import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/models/following_user.dart';
import '../../domain/models/profile_activity.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import 'profile_state.dart';

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit(this._repository) : super(const ProfileState());

  final ProfileRepository _repository;

  Future<void> load() => _fetchProfile(isRefresh: false);

  Future<void> refresh() => _fetchProfile(isRefresh: true);

  static bool _isOffline(Object error) =>
      error is ApiException && error.statusCode == null;

  Future<void> _fetchProfile({required bool isRefresh}) async {
    if (isRefresh && state.refreshing) return;

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
        _repository.getRecentActivities(limit: 5),
        _repository.getFollowing(limit: 20),
      ]);
      final profile = results[0] as UserProfile;
      final activities = results[1] as List<ProfileActivity>;
      final following = results[2] as List<FollowingUser>;

      if (isClosed) return;
      emit(
        state.copyWith(
          profile: profile,
          following: following,
          highlightActivity: activities.isNotEmpty ? activities.first : null,
          recentActivities:
              activities.length > 1 ? activities.sublist(1) : const [],
          loading: false,
          refreshing: false,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          loading: false,
          refreshing: false,
          // Wcześniej trafiał tu surowy `ApiException(null): network_error`.
          error: _isOffline(e)
              ? 'Brak połączenia z internetem. Profil wczyta się, gdy wrócisz '
                  'online — treningi możesz zapisywać bez przeszkód.'
              : 'Nie udało się wczytać profilu. Spróbuj ponownie.',
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
