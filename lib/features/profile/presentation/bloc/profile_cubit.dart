import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/profile_repository.dart';
import 'profile_state.dart';

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit(this._repository) : super(const ProfileState());

  final ProfileRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final profile = await _repository.getOwnProfile();
      final activities = await _repository.getRecentActivities(limit: 5);
      emit(
        state.copyWith(
          profile: profile,
          highlightActivity: activities.isNotEmpty ? activities.first : null,
          recentActivities:
              activities.length > 1 ? activities.sublist(1) : const [],
          loading: false,
        ),
      );
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<void> refresh() async {
    if (state.refreshing) return;
    emit(state.copyWith(refreshing: true, clearError: true));
    try {
      final profile = await _repository.getOwnProfile();
      final activities = await _repository.getRecentActivities(limit: 5);
      emit(
        state.copyWith(
          profile: profile,
          highlightActivity: activities.isNotEmpty ? activities.first : null,
          recentActivities:
              activities.length > 1 ? activities.sublist(1) : const [],
          refreshing: false,
        ),
      );
    } catch (e) {
      emit(state.copyWith(refreshing: false, error: e.toString()));
    }
  }

  Future<void> updateBio(String bio) async {
    final profile = state.profile;
    if (profile == null) return;

    try {
      final updated = await _repository.updateBio(bio);
      emit(state.copyWith(profile: updated, clearError: true));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }
}
