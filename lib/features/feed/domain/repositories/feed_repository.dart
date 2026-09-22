import '../../../profile/domain/models/following_user.dart';
import '../models/cursor_page.dart';
import '../models/post_comment.dart';
import '../models/post_detail.dart';

/// Feed społecznościowy: posty (udostępnione treningi), kudosy, komentarze.
/// Wszystkie operacje wymagają sieci; błędy jako `ApiException`.
abstract interface class FeedRepository {
  /// Posty moje i obserwowanych osób, najnowsze najpierw.
  Future<FeedPage> getFeed({String? cursor, int limit = 20});

  /// Udostępnione treningi jednej osoby (oś czasu na profilu), najnowsze
  /// najpierw.
  Future<FeedPage> getUserPosts(
    String userId, {
    String? cursor,
    int limit = 10,
  });

  Future<PostDetail> getPost(String postId);

  Future<KudosResult> giveKudos(String postId);

  Future<KudosResult> removeKudos(String postId);

  Future<List<FollowingUser>> getKudos(
    String postId, {
    int limit = 50,
    int offset = 0,
  });

  /// Najstarsze najpierw; kursor doładowuje nowsze.
  Future<CommentsPage> getComments(
    String postId, {
    String? cursor,
    int limit = 30,
  });

  Future<PostComment> addComment(String postId, String body);

  Future<void> deleteComment(String postId, String commentId);

  Future<List<FollowingUser>> getSuggestedUsers({int limit = 10});
}

/// Zapis pierwszej strony feedu (per użytkownik) do pokazania od razu po
/// otwarciu i bez sieci.
abstract interface class FeedCache {
  Future<FeedPage?> read(String userId);

  Future<void> write(String userId, FeedPage page);
}
