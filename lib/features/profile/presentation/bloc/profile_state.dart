import 'package:flutter/foundation.dart';

import '../../domain/models/following_user.dart';
import '../../domain/models/user_profile.dart';

class ProfileState {
  const ProfileState({
    this.profile,
    this.following = const [],
    this.loading = true,
    this.refreshing = false,
    this.error,
    this.offline = false,
    this.errorSeq = 0,
  });

  final UserProfile? profile;
  final List<FollowingUser> following;
  final bool loading;
  final bool refreshing;
  final String? error;

  /// Ostatni błąd wynikał z braku sieci (inna ikona, spokojniejszy ton).
  final bool offline;

  /// Rośnie z każdym błędem — ekran pokazuje SnackBar także przy powtórce.
  final int errorSeq;

  ProfileState copyWith({
    UserProfile? profile,
    List<FollowingUser>? following,
    bool? loading,
    bool? refreshing,
    String? error,
    bool clearError = false,
    bool? offline,
    int? errorSeq,
  }) {
    return ProfileState(
      profile: profile ?? this.profile,
      following: following ?? this.following,
      loading: loading ?? this.loading,
      refreshing: refreshing ?? this.refreshing,
      error: clearError ? null : (error ?? this.error),
      offline: offline ?? this.offline,
      errorSeq: errorSeq ?? this.errorSeq,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProfileState &&
        other.profile == profile &&
        listEquals(other.following, following) &&
        other.loading == loading &&
        other.refreshing == refreshing &&
        other.error == error &&
        other.offline == offline &&
        other.errorSeq == errorSeq;
  }

  @override
  int get hashCode => Object.hash(
    profile,
    Object.hashAll(following),
    loading,
    refreshing,
    error,
    offline,
    errorSeq,
  );
}
