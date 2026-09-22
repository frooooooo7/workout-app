import '../../../feed/domain/models/feed_post.dart';
import '../../../feed/presentation/bloc/feed_messages.dart';

enum ProfilePostsStatus { loading, ready, failure }

class ProfilePostsState {
  const ProfilePostsState({
    this.status = ProfilePostsStatus.loading,
    this.items = const [],
    this.nextCursor,
    this.hasMore = false,
    this.loadingMore = false,
    this.offline = false,
    this.notice,
  });

  final ProfilePostsStatus status;
  final List<FeedPost> items;
  final String? nextCursor;
  final bool hasMore;
  final bool loadingMore;

  /// Ostatnia porażka wynikała z braku sieci.
  final bool offline;

  /// Jednorazowy komunikat (SnackBar) — błąd kudosa, doładowania itp.
  final FeedNotice? notice;

  ProfilePostsState copyWith({
    ProfilePostsStatus? status,
    List<FeedPost>? items,
    String? nextCursor,
    bool clearNextCursor = false,
    bool? hasMore,
    bool? loadingMore,
    bool? offline,
    FeedNotice? notice,
  }) {
    return ProfilePostsState(
      status: status ?? this.status,
      items: items ?? this.items,
      nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
      offline: offline ?? this.offline,
      notice: notice ?? this.notice,
    );
  }
}
