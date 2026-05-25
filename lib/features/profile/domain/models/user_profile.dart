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
  });

  final String id;
  final String firstName;
  final String lastName;
  final String handle;
  final String? bio;
  final String? avatarUrl;
  final ProfileStats stats;
  final bool isOwnProfile;

  String get fullName => '$firstName $lastName';

  String get displayHandle => handle.startsWith('@') ? handle : '@$handle';
}
