import 'feed_post.dart';
import 'post_comment.dart';

/// Strona wyników stronicowanych kursorem (`{ items, nextCursor, hasMore }`).
class CursorPage<T> {
  const CursorPage({
    required this.items,
    this.nextCursor,
    this.hasMore = false,
  });

  final List<T> items;
  final String? nextCursor;
  final bool hasMore;
}

typedef FeedPage = CursorPage<FeedPost>;
typedef CommentsPage = CursorPage<PostComment>;
