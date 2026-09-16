import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/models/following_user.dart';
import '../../domain/models/profile_activity.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import 'profile_state.dart';

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit(this._repository, {this.hiddenActivityIds})
    : super(const ProfileState());

  final ProfileRepository _repository;

  /// Id aktywności (= id sesji) ukrywanych na profilu — treningi usunięte na
  /// tym urządzeniu, zanim usunięcie dotarło na serwer.
  final Future<Set<String>> Function()? hiddenActivityIds;

  Future<void> load() => _fetchProfile(isRefresh: false);

  Future<void> refresh() => _fetchProfile(isRefresh: true);

  static bool _isOffline(Object error) =>
      error is ApiException && error.statusCode == null;

  Future<void> _fetchProfile({required bool isRefresh}) async {
    if (isRefresh && state.refreshing) return;
    // Bez sieci odświeżenie się nie uda — usunięty trening i tak ma zniknąć.
    if (isRefresh) await _hideRemovedActivities();
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
        _repository.getRecentActivities(limit: 5),
        _repository.getFollowing(limit: 20),
      ]);
      final profile = results[0] as UserProfile;
      final activities = await _visible(results[1] as List<ProfileActivity>);
      final following = results[2] as List<FollowingUser>;

      if (isClosed) return;
      emit(
        state.copyWith(
          profile: profile,
          following: following,
          highlightActivity: activities.isNotEmpty ? activities.first : null,
          clearHighlight: activities.isEmpty,
          recentActivities: activities.length > 1
              ? activities.sublist(1)
              : const [],
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

  Future<List<ProfileActivity>> _visible(
    List<ProfileActivity> activities,
  ) async {
    final hiddenIds = hiddenActivityIds;
    if (hiddenIds == null || activities.isEmpty) return activities;
    final Set<String> hidden;
    try {
      hidden = await hiddenIds();
    } catch (_) {
      return activities;
    }
    if (hidden.isEmpty) return activities;
    return activities
        .where((activity) => !hidden.contains(activity.id))
        .toList(growable: false);
  }

  Future<void> _hideRemovedActivities() async {
    final highlight = state.highlightActivity;
    final current = [?highlight, ...state.recentActivities];
    final visible = await _visible(current);
    if (isClosed || visible.length == current.length) return;
    emit(
      state.copyWith(
        highlightActivity: visible.isNotEmpty ? visible.first : null,
        clearHighlight: visible.isEmpty,
        recentActivities: visible.length > 1 ? visible.sublist(1) : const [],
      ),
    );
  }

  /// Profil zwrócony przez ekran edycji — widoczny od razu, bez czekania
  /// na ponowne pobranie.
  void applyProfile(UserProfile profile) {
    if (isClosed) return;
    emit(state.copyWith(profile: profile, clearError: true));
  }
}
