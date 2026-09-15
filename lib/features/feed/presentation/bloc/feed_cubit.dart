import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/models/cursor_page.dart';
import '../../domain/models/feed_author.dart';
import '../../domain/models/feed_post.dart';
import '../../domain/repositories/feed_repository.dart';
import '../../domain/services/feed_post_events.dart';
import 'feed_messages.dart';
import 'feed_state.dart';

/// Feed aktywności: cache pierwszej strony od razu (stale-while-revalidate),
/// odświeżanie, doładowanie kursorem i optymistyczne kudosy.
class FeedCubit extends Cubit<FeedState> {
  FeedCubit({
    required FeedRepository repository,
    FeedCache? cache,
    String? userId,
    Listenable? refreshSignal,
    FeedPostEvents? events,
    FeedAuthor? currentUser,
    this.pageSize = 20,
  }) : _repository = repository,
       _cache = cache,
       _userId = userId,
       _refreshSignal = refreshSignal,
       _events = events,
       _currentUser = currentUser,
       super(const FeedState()) {
    _refreshSignal?.addListener(_onRefreshSignal);
    _eventsSubscription = _events?.stream.listen(_onPostEvent);
  }

  final FeedRepository _repository;
  final FeedCache? _cache;
  final String? _userId;
  final Listenable? _refreshSignal;
  final FeedPostEvents? _events;
  final FeedAuthor? _currentUser;
  final int pageSize;

  StreamSubscription<FeedPostEvent>? _eventsSubscription;
  Future<void>? _firstPageFuture;
  bool _refreshQueued = false;

  /// Rośnie z każdym pobraniem pierwszej strony — spóźniona odpowiedź
  /// doładowania ze starym kursorem jest wtedy odrzucana.
  int _generation = 0;
  int _noticeSeq = 0;
  final _kudosPending = <String>{};

  /// Kursor i `hasMore` pierwszej strony — do zapisu cache po zmianach.
  String? _firstPageCursor;
  bool _firstPageHasMore = false;

  Future<void> load() async {
    if (isClosed) return;
    if (state.status != FeedStatus.initial) return refresh();

    emit(state.copyWith(status: FeedStatus.loading, clearErrorMessage: true));
    final cache = _cache;
    final userId = _userId;
    if (cache != null && userId != null) {
      final cached = await cache.read(userId);
      if (isClosed) return;
      if (cached != null && cached.items.isNotEmpty && _firstPageFuture == null) {
        _firstPageCursor = cached.nextCursor;
        _firstPageHasMore = cached.hasMore;
        emit(
          state.copyWith(
            status: FeedStatus.ready,
            items: cached.items,
            nextCursor: cached.nextCursor,
            clearNextCursor: cached.nextCursor == null,
            hasMore: cached.hasMore,
            isRefreshing: true,
          ),
        );
      }
    }
    await _fetchFirstPage();
  }

  /// Pobiera pierwszą stronę od nowa. Równoległe wywołania dzielą jedno
  /// żądanie (np. pull-to-refresh w trakcie odświeżania w tle).
  Future<void> refresh() => _fetchFirstPage();

  Future<void> _fetchFirstPage() {
    final inFlight = _firstPageFuture;
    if (inFlight != null) return inFlight;
    final future = _doFetchFirstPage();
    _firstPageFuture = future;
    return future.whenComplete(() {
      if (identical(_firstPageFuture, future)) _firstPageFuture = null;
      if (_refreshQueued && !isClosed) {
        _refreshQueued = false;
        unawaited(_fetchFirstPage());
      }
    });
  }

  Future<void> _doFetchFirstPage() async {
    final generation = ++_generation;
    if (state.items.isEmpty) {
      emit(
        state.copyWith(
          status: FeedStatus.loading,
          isLoadingMore: false,
          clearErrorMessage: true,
        ),
      );
    } else {
      emit(state.copyWith(isRefreshing: true, isLoadingMore: false));
    }

    try {
      final page = await _repository.getFeed(limit: pageSize);
      if (isClosed || generation != _generation) return;
      final items = _dedupe(page.items);
      _firstPageCursor = page.nextCursor;
      _firstPageHasMore = page.hasMore;
      emit(
        state.copyWith(
          status: FeedStatus.ready,
          items: items,
          nextCursor: page.nextCursor,
          clearNextCursor: page.nextCursor == null,
          hasMore: page.hasMore,
          isRefreshing: false,
          isLoadingMore: false,
          loadMoreFailed: false,
          clearStaleMessage: true,
          clearErrorMessage: true,
        ),
      );
      unawaited(_persistFirstPage());
      if (items.isEmpty && !state.suggestionsLoaded) {
        unawaited(loadSuggestions());
      }
    } catch (error) {
      if (isClosed || generation != _generation) return;
      if (state.items.isNotEmpty) {
        emit(
          state.copyWith(
            status: FeedStatus.ready,
            isRefreshing: false,
            isLoadingMore: false,
            staleMessage: feedStaleMessage(error),
          ),
        );
      } else {
        emit(
          state.copyWith(
            status: FeedStatus.failure,
            isRefreshing: false,
            isLoadingMore: false,
            errorMessage: feedLoadErrorMessage(error),
          ),
        );
      }
    }
  }

  Future<void> loadMore() async {
    final cursor = state.nextCursor;
    if (isClosed ||
        state.status != FeedStatus.ready ||
        !state.hasMore ||
        cursor == null ||
        state.isLoadingMore ||
        _firstPageFuture != null) {
      return;
    }

    final generation = _generation;
    emit(state.copyWith(isLoadingMore: true, loadMoreFailed: false));
    try {
      final page = await _repository.getFeed(cursor: cursor, limit: pageSize);
      if (isClosed || generation != _generation) return;
      final known = {for (final post in state.items) post.id};
      final merged = [
        ...state.items,
        ...page.items.where((post) => known.add(post.id)),
      ];
      emit(
        state.copyWith(
          items: List.unmodifiable(merged),
          nextCursor: page.nextCursor,
          clearNextCursor: page.nextCursor == null,
          hasMore: page.hasMore,
          isLoadingMore: false,
        ),
      );
    } catch (error) {
      if (isClosed || generation != _generation) return;
      if (error is ApiException && error.message == 'invalid_cursor') {
        emit(state.copyWith(isLoadingMore: false));
        await refresh();
        return;
      }
      emit(state.copyWith(isLoadingMore: false, loadMoreFailed: true));
    }
  }

  Future<void> loadSuggestions() async {
    if (isClosed || state.suggestionsLoading) return;
    emit(state.copyWith(suggestionsLoading: true));
    try {
      final users = await _repository.getSuggestedUsers(limit: 10);
      if (isClosed) return;
      emit(
        state.copyWith(
          suggestions: users,
          suggestionsLoading: false,
          suggestionsLoaded: true,
        ),
      );
    } catch (_) {
      if (isClosed) return;
      emit(state.copyWith(suggestionsLoading: false));
    }
  }

  /// Optymistyczny kudos z cofnięciem przy błędzie. Własne posty i posty
  /// z żądaniem w toku są ignorowane.
  Future<void> toggleKudos(String postId) async {
    if (isClosed) return;
    final original = _postById(postId);
    if (original == null || original.isOwn || !_kudosPending.add(postId)) {
      return;
    }

    final wasKudoed = original.hasKudoed;
    _updatePost(
      postId,
      (post) => post.withKudos(
        hasKudoed: !wasKudoed,
        kudosCount: post.kudosCount + (wasKudoed ? -1 : 1),
        me: _currentUser,
      ),
    );

    try {
      final result = wasKudoed
          ? await _repository.removeKudos(postId)
          : await _repository.giveKudos(postId);
      if (isClosed) return;
      _updatePost(
        postId,
        (post) => post.withKudos(
          hasKudoed: result.hasKudoed,
          kudosCount: result.kudosCount,
          me: _currentUser,
        ),
      );
      unawaited(_persistFirstPage());
      _events?.emit(
        PostKudosChanged(
          postId,
          hasKudoed: result.hasKudoed,
          kudosCount: result.kudosCount,
        ),
      );
    } catch (error) {
      if (isClosed) return;
      _updatePost(
        postId,
        (post) => post.copyWith(
          hasKudoed: original.hasKudoed,
          kudosCount: original.kudosCount,
          recentKudos: original.recentKudos,
        ),
      );
      emit(
        state.copyWith(
          notice: FeedNotice(
            id: ++_noticeSeq,
            message: kudosErrorMessage(error, removing: wasKudoed),
          ),
        ),
      );
    } finally {
      _kudosPending.remove(postId);
    }
  }

  bool isKudosPending(String postId) => _kudosPending.contains(postId);

  void _onRefreshSignal() {
    if (isClosed || state.status == FeedStatus.initial) return;
    if (_firstPageFuture != null) {
      _refreshQueued = true;
      return;
    }
    unawaited(refresh());
  }

  void _onPostEvent(FeedPostEvent event) {
    if (isClosed || _postById(event.postId) == null) return;
    switch (event) {
      case PostKudosChanged():
        if (_kudosPending.contains(event.postId)) return;
        _updatePost(
          event.postId,
          (post) => post.withKudos(
            hasKudoed: event.hasKudoed,
            kudosCount: event.kudosCount,
            me: _currentUser,
          ),
        );
      case PostCommentCountChanged():
        _updatePost(event.postId, (post) => post.withCommentDelta(event.delta));
    }
    unawaited(_persistFirstPage());
  }

  FeedPost? _postById(String postId) {
    for (final post in state.items) {
      if (post.id == postId) return post;
    }
    return null;
  }

  void _updatePost(String postId, FeedPost Function(FeedPost post) update) {
    final items = [
      for (final post in state.items)
        if (post.id == postId) update(post) else post,
    ];
    emit(state.copyWith(items: List.unmodifiable(items)));
  }

  static List<FeedPost> _dedupe(List<FeedPost> posts) {
    final seen = <String>{};
    return List.unmodifiable(posts.where((post) => seen.add(post.id)));
  }

  Future<void> _persistFirstPage() async {
    final cache = _cache;
    final userId = _userId;
    if (cache == null || userId == null || state.status != FeedStatus.ready) {
      return;
    }
    final firstPage = state.items.take(pageSize).toList(growable: false);
    await cache.write(
      userId,
      FeedPage(
        items: firstPage,
        nextCursor: _firstPageCursor,
        hasMore: _firstPageHasMore,
      ),
    );
  }

  @override
  Future<void> close() async {
    _refreshSignal?.removeListener(_onRefreshSignal);
    await _eventsSubscription?.cancel();
    return super.close();
  }
}
