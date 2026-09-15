/// Autor posta, komentarza albo kudosa.
class FeedAuthor {
  const FeedAuthor({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.handle = '',
    this.avatarUrl,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String handle;

  /// Ścieżka względna (`/uploads/avatars/…`) albo pełny adres.
  final String? avatarUrl;

  String get fullName => '$firstName $lastName'.trim();
}
