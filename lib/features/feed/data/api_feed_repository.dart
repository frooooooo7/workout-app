import '../../../core/network/api_client.dart';
import '../../profile/data/api_profile_repository.dart';
import '../../profile/domain/models/following_user.dart';
import '../domain/models/cursor_page.dart';
import '../domain/models/post_comment.dart';
import '../domain/models/post_detail.dart';
import '../domain/repositories/feed_repository.dart';
import 'feed_json.dart';

class ApiFeedRepository implements FeedRepository {
  const ApiFeedRepository(this._api);

  final ApiClient _api;

  @override
  Future<FeedPage> getFeed({String? cursor, int limit = 20}) async {
    final path = Uri(
      path: '/feed',
      queryParameters: {
        'limit': '$limit',
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      },
    ).toString();
    return FeedJson.feedPageFromJson(await _api.get(path, auth: true));
  }

  @override
  Future<FeedPage> getUserPosts(
    String userId, {
    String? cursor,
    int limit = 10,
  }) async {
    final path = Uri(
      path: '/users/${_segment(userId)}/posts',
      queryParameters: {
        'limit': '$limit',
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      },
    ).toString();
    return FeedJson.feedPageFromJson(await _api.get(path, auth: true));
  }

  @override
  Future<PostDetail> getPost(String postId) async {
    final data = await _api.get('/posts/${_segment(postId)}', auth: true);
    return FeedJson.postDetailFromJson(data);
  }

  @override
  Future<KudosResult> giveKudos(String postId) async {
    final data = await _api.post(
      '/posts/${_segment(postId)}/kudos',
      const <String, dynamic>{},
      auth: true,
    );
    return FeedJson.kudosResultFromJson(data);
  }

  @override
  Future<KudosResult> removeKudos(String postId) async {
    final data = await _api.delete(
      '/posts/${_segment(postId)}/kudos',
      auth: true,
    );
    return FeedJson.kudosResultFromJson(data);
  }

  @override
  Future<List<FollowingUser>> getKudos(
    String postId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final path = Uri(
      path: '/posts/${_segment(postId)}/kudos',
      queryParameters: {'limit': '$limit', 'offset': '$offset'},
    ).toString();
    return ApiProfileRepository.followingUsersFromJson(
      await _api.get(path, auth: true),
    );
  }

  @override
  Future<CommentsPage> getComments(
    String postId, {
    String? cursor,
    int limit = 30,
  }) async {
    final path = Uri(
      path: '/posts/${_segment(postId)}/comments',
      queryParameters: {
        'limit': '$limit',
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      },
    ).toString();
    return FeedJson.commentsPageFromJson(await _api.get(path, auth: true));
  }

  @override
  Future<PostComment> addComment(String postId, String body) async {
    final data = await _api.post(
      '/posts/${_segment(postId)}/comments',
      {'body': body},
      auth: true,
    );
    if (data is! Map<String, dynamic>) {
      throw const ApiException('invalid_response', statusCode: 200);
    }
    return FeedJson.commentFromJson(data);
  }

  @override
  Future<void> deleteComment(String postId, String commentId) async {
    await _api.delete(
      '/posts/${_segment(postId)}/comments/${_segment(commentId)}',
      auth: true,
    );
  }

  @override
  Future<List<FollowingUser>> getSuggestedUsers({int limit = 10}) async {
    final path = Uri(
      path: '/users/suggested',
      queryParameters: {'limit': '$limit'},
    ).toString();
    return ApiProfileRepository.followingUsersFromJson(
      await _api.get(path, auth: true),
    );
  }

  static String _segment(String value) => Uri.encodeComponent(value);
}
