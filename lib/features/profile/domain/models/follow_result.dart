/// Odpowiedź `POST|DELETE /users/:userId/follow`.
class FollowResult {
  const FollowResult({
    required this.isFollowing,
    required this.followersCount,
  });

  final bool isFollowing;

  /// Liczba obserwujących użytkownika, którego (od)obserwowano.
  final int followersCount;
}
