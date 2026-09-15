import '../../../profile/domain/models/following_user.dart';
import '../../domain/models/feed_post.dart';
import 'feed_messages.dart';

enum FeedStatus { initial, loading, ready, failure }

class FeedState {
  const FeedState({
    this.status = FeedStatus.initial,
    this.items = const [],
    this.nextCursor,
    this.hasMore = false,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.loadMoreFailed = false,
    this.staleMessage,
    this.errorMessage,
    this.notice,
    this.suggestions = const [],
    this.suggestionsLoading = false,
    this.suggestionsLoaded = false,
  });

  final FeedStatus status;
  final List<FeedPost> items;
  final String? nextCursor;
  final bool hasMore;

  /// Odświeżanie pierwszej strony, gdy lista jest już widoczna (cache albo
  /// poprzednie dane).
  final bool isRefreshing;
  final bool isLoadingMore;
  final bool loadMoreFailed;

  /// Baner nad listą: odświeżenie się nie udało, widać zapisane dane.
  final String? staleMessage;

  /// Pełnoekranowy błąd — tylko gdy nie ma czego pokazać.
  final String? errorMessage;
  final FeedNotice? notice;

  /// Proponowane osoby do pustego feedu.
  final List<FollowingUser> suggestions;
  final bool suggestionsLoading;
  final bool suggestionsLoaded;

  bool get isEmptyFeed => status == FeedStatus.ready && items.isEmpty;

  FeedState copyWith({
    FeedStatus? status,
    List<FeedPost>? items,
    String? nextCursor,
    bool clearNextCursor = false,
    bool? hasMore,
    bool? isRefreshing,
    bool? isLoadingMore,
    bool? loadMoreFailed,
    String? staleMessage,
    bool clearStaleMessage = false,
    String? errorMessage,
    bool clearErrorMessage = false,
    FeedNotice? notice,
    List<FollowingUser>? suggestions,
    bool? suggestionsLoading,
    bool? suggestionsLoaded,
  }) {
    return FeedState(
      status: status ?? this.status,
      items: items ?? this.items,
      nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
      hasMore: hasMore ?? this.hasMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
      staleMessage: clearStaleMessage
          ? null
          : (staleMessage ?? this.staleMessage),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      notice: notice ?? this.notice,
      suggestions: suggestions ?? this.suggestions,
      suggestionsLoading: suggestionsLoading ?? this.suggestionsLoading,
      suggestionsLoaded: suggestionsLoaded ?? this.suggestionsLoaded,
    );
  }
}
