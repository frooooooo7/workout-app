import 'package:flutter/foundation.dart';

import '../../domain/models/following_user.dart';
import '../../domain/models/profile_activity.dart';
import '../../domain/models/user_profile.dart';

class ProfileState {
  const ProfileState({
    this.profile,
    this.following = const [],
    this.highlightActivity,
    this.recentActivities = const [],
    this.loading = true,
    this.refreshing = false,
    this.error,
  });

  final UserProfile? profile;
  final List<FollowingUser> following;
  final ProfileActivity? highlightActivity;
  final List<ProfileActivity> recentActivities;
  final bool loading;
  final bool refreshing;
  final String? error;

  ProfileState copyWith({
    UserProfile? profile,
    List<FollowingUser>? following,
    ProfileActivity? highlightActivity,
    bool clearHighlight = false,
    List<ProfileActivity>? recentActivities,
    bool? loading,
    bool? refreshing,
    String? error,
    bool clearError = false,
  }) {
    return ProfileState(
      profile: profile ?? this.profile,
      following: following ?? this.following,
      highlightActivity:
          clearHighlight ? null : (highlightActivity ?? this.highlightActivity),
      recentActivities: recentActivities ?? this.recentActivities,
      loading: loading ?? this.loading,
      refreshing: refreshing ?? this.refreshing,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProfileState &&
        other.profile == profile &&
        listEquals(other.following, following) &&
        other.highlightActivity == highlightActivity &&
        listEquals(other.recentActivities, recentActivities) &&
        other.loading == loading &&
        other.refreshing == refreshing &&
        other.error == error;
  }

  @override
  int get hashCode => Object.hash(
    profile,
    Object.hashAll(following),
    highlightActivity,
    Object.hashAll(recentActivities),
    loading,
    refreshing,
    error,
  );
}
