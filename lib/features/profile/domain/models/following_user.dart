class FollowingUser {
  const FollowingUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.handle,
    this.avatarUrl,
    this.isFollowing = false,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String handle;
  final String? avatarUrl;

  /// Zalogowany użytkownik obserwuje tę osobę.
  final bool isFollowing;

  String get fullName => '$firstName $lastName';

  String get displayHandle => handle.startsWith('@') ? handle : '@$handle';

  FollowingUser copyWith({
    String? firstName,
    String? lastName,
    String? handle,
    String? avatarUrl,
    bool clearAvatarUrl = false,
    bool? isFollowing,
  }) {
    return FollowingUser(
      id: id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      handle: handle ?? this.handle,
      avatarUrl: clearAvatarUrl ? null : (avatarUrl ?? this.avatarUrl),
      isFollowing: isFollowing ?? this.isFollowing,
    );
  }
}
