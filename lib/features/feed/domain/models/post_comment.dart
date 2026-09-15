import 'feed_author.dart';

class PostComment {
  const PostComment({
    required this.id,
    required this.author,
    required this.body,
    required this.createdAt,
    this.isOwn = false,
    this.canDelete = false,
    this.isPending = false,
  });

  final String id;
  final FeedAuthor author;
  final String body;
  final DateTime createdAt;
  final bool isOwn;

  /// Autor komentarza albo autor posta.
  final bool canDelete;

  /// Komentarz dodany optymistycznie, jeszcze niepotwierdzony przez serwer.
  final bool isPending;
}
