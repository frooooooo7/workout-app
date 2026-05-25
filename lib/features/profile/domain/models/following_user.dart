class FollowingUser {
  const FollowingUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.handle,
    this.avatarUrl,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String handle;
  final String? avatarUrl;

  String get fullName => '$firstName $lastName';

  String get displayHandle => handle.startsWith('@') ? handle : '@$handle';
}
