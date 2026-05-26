import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/models/following_user.dart';
import '../../domain/models/profile_activity.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import 'profile_state.dart';

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit(this._repository) : super(const ProfileState());

  final ProfileRepository _repository;
  bool _updatingBio = false;

  Future<void> load() => _fetchProfile(isRefresh: false);

  Future<void> refresh() => _fetchProfile(isRefresh: true);

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
      emit(
        state.copyWith(
          loading: false,
          refreshing: false,
          error: e.toString(),
        ),
      );
    }
  }

  Future<void> updateBio(String bio) async {
    if (_updatingBio || state.profile == null) return;

    _updatingBio = true;
    try {
      final updated = await _repository.updateBio(bio);
      emit(state.copyWith(profile: updated, clearError: true));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    } finally {
      _updatingBio = false;
    }
  }
}
