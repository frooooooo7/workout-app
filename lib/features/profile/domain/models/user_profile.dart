import 'profile_stats.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.handle,
    this.bio,
    this.avatarUrl,
    required this.stats,
    required this.isOwnProfile,
    this.isFollowing = false,
    this.isFollowedBy = false,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String handle;
  final String? bio;
  final String? avatarUrl;
  final ProfileStats stats;
  final bool isOwnProfile;

  /// Zalogowany użytkownik obserwuje ten profil.
  final bool isFollowing;

  /// Ten profil obserwuje zalogowanego użytkownika.
  final bool isFollowedBy;

  String get fullName => '$firstName $lastName';

  String get displayHandle => handle.startsWith('@') ? handle : '@$handle';

  UserProfile copyWith({
    String? firstName,
    String? lastName,
    String? handle,
    String? bio,
    bool clearBio = false,
    String? avatarUrl,
    bool clearAvatarUrl = false,
    ProfileStats? stats,
    bool? isOwnProfile,
    bool? isFollowing,
    bool? isFollowedBy,
  }) {
    return UserProfile(
      id: id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      handle: handle ?? this.handle,
      bio: clearBio ? null : (bio ?? this.bio),
      avatarUrl: clearAvatarUrl ? null : (avatarUrl ?? this.avatarUrl),
      stats: stats ?? this.stats,
      isOwnProfile: isOwnProfile ?? this.isOwnProfile,
      isFollowing: isFollowing ?? this.isFollowing,
      isFollowedBy: isFollowedBy ?? this.isFollowedBy,
    );
  }
}
