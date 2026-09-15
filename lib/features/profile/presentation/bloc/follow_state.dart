/// Nieudana zmiana obserwowania — [id] rośnie z każdą porażką, więc
/// ekran pokazuje SnackBar także przy dwóch identycznych błędach z rzędu.
class FollowFailure {
  const FollowFailure({
    required this.id,
    required this.userId,
    required this.message,
  });

  final int id;
  final String userId;
  final String message;
}

/// Stan obserwowania dla wielu użytkowników naraz (lista, wyszukiwarka,
/// profil). Klucz — id użytkownika.
class FollowState {
  const FollowState({
    this.following = const {},
    this.pending = const {},
    this.followersCounts = const {},
    this.failure,
  });

  final Map<String, bool> following;

  /// Użytkownicy, dla których żądanie follow/unfollow jest w toku.
  final Set<String> pending;

  /// Liczba obserwujących — tylko dla użytkowników zasianych z profilu
  /// albo po odpowiedzi serwera.
  final Map<String, int> followersCounts;

  final FollowFailure? failure;

  bool isFollowing(String userId) => following[userId] ?? false;

  bool isPending(String userId) => pending.contains(userId);

  int? followersCountOf(String userId) => followersCounts[userId];

  FollowState copyWith({
    Map<String, bool>? following,
    Set<String>? pending,
    Map<String, int>? followersCounts,
    FollowFailure? failure,
    bool clearFailure = false,
  }) {
    return FollowState(
      following: following ?? this.following,
      pending: pending ?? this.pending,
      followersCounts: followersCounts ?? this.followersCounts,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }
}
