class ProfileStats {
  const ProfileStats({
    required this.followingCount,
    required this.followersCount,
    required this.workoutsCount,
  });

  final int followingCount;
  final int followersCount;
  final int workoutsCount;

  ProfileStats copyWith({
    int? followingCount,
    int? followersCount,
    int? workoutsCount,
  }) {
    return ProfileStats(
      followingCount: followingCount ?? this.followingCount,
      followersCount: followersCount ?? this.followersCount,
      workoutsCount: workoutsCount ?? this.workoutsCount,
    );
  }
}
