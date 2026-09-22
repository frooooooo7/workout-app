import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../feed/domain/models/feed_author.dart';
import '../../../feed/domain/models/feed_post.dart';
import '../../../feed/domain/repositories/feed_repository.dart';
import '../../../feed/domain/services/feed_post_events.dart';
import '../../../feed/presentation/bloc/feed_messages.dart';
import 'profile_posts_state.dart';

/// Oś czasu profilu: udostępnione treningi jednej osoby w formacie postów
/// feedu, doładowanie kursorem i optymistyczne kudosy (tylko cudze posty).
class ProfilePostsCubit extends Cubit<ProfilePostsState> {
  ProfilePostsCubit({
    required FeedRepository repository,
    required this.userId,
    FeedPostEvents? events,
    FeedAuthor? currentUser,
    this.hiddenPostIds,
    this.pageSize = 10,
  }) : _repository = repository,
       _events = events,
       _currentUser = currentUser,
       super(const ProfilePostsState()) {
    _eventsSubscription = _events?.stream.listen(_onPostEvent);
  }

  final FeedRepository _repository;
  final FeedPostEvents? _events;
  final FeedAuthor? _currentUser;
  final String userId;
  final int pageSize;

  /// Id postów (= id sesji) ukrywanych na profilu — treningi usunięte na
  /// tym urządzeniu, zanim usunięcie dotarło na serwer.
  final Future<Set<String>> Function()? hiddenPostIds;

  StreamSubscription<FeedPostEvent>? _eventsSubscription;
  Future<void>? _firstPageFuture;
  final _kudosPending = <String>{};
  int _generation = 0;
  int _noticeSeq = 0;

  Future<void> load() => _fetchFirstPage();

  Future<void> refresh() => _fetchFirstPage();

  Future<void> _fetchFirstPage() {
    final inFlight = _firstPageFuture;
    if (inFlight != null) return inFlight;
    final future = _doFetchFirstPage();
    _firstPageFuture = future;
    return future.whenComplete(() {
      if (identical(_firstPageFuture, future)) _firstPageFuture = null;
    });
  }

  Future<void> _doFetchFirstPage() async {
    final generation = ++_generation;
    // Bez sieci odświeżenie się nie uda — usunięty trening i tak ma zniknąć.
    await _hideRemovedPosts();
    if (isClosed) return;
    if (state.items.isEmpty) {
      emit(state.copyWith(status: ProfilePostsStatus.loading));
    }
    try {
      final page = await _repository.getUserPosts(userId, limit: pageSize);
      final items = await _visible(page.items);
      if (isClosed || generation != _generation) return;
      emit(
        state.copyWith(
          status: ProfilePostsStatus.ready,
          items: items,
          nextCursor: page.nextCursor,
          clearNextCursor: page.nextCursor == null,
          hasMore: page.hasMore,
          loadingMore: false,
        ),
      );
    } catch (error) {
      if (isClosed || generation != _generation) return;
      if (state.items.isEmpty) {
        emit(
          state.copyWith(
            status: ProfilePostsStatus.failure,
            offline: isNetworkError(error),
          ),
        );
      } else {
        _notice('Nie udało się odświeżyć aktywności.');
      }
    }
  }

  Future<void> loadMore() async {
    final cursor = state.nextCursor;
    if (isClosed || state.loadingMore || !state.hasMore || cursor == null) {
      return;
    }
    final generation = _generation;
    emit(state.copyWith(loadingMore: true));
    try {
      final page = await _repository.getUserPosts(
        userId,
        cursor: cursor,
        limit: pageSize,
      );
      final more = await _visible(page.items);
      if (isClosed || generation != _generation) return;
      final seen = {for (final post in state.items) post.id};
      emit(
        state.copyWith(
          items: List.unmodifiable([
            ...state.items,
            ...more.where((post) => seen.add(post.id)),
          ]),
          nextCursor: page.nextCursor,
          clearNextCursor: page.nextCursor == null,
          hasMore: page.hasMore,
          loadingMore: false,
        ),
      );
    } catch (error) {
      if (isClosed || generation != _generation) return;
      emit(state.copyWith(loadingMore: false));
      _notice(
        isNetworkError(error)
            ? 'Brak połączenia — nie udało się wczytać starszych treningów.'
            : 'Nie udało się wczytać starszych treningów.',
      );
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
      _notice(kudosErrorMessage(error, removing: wasKudoed));
    } finally {
      _kudosPending.remove(postId);
    }
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
  }

  void _notice(String message) {
    emit(
      state.copyWith(notice: FeedNotice(id: ++_noticeSeq, message: message)),
    );
  }

  Future<List<FeedPost>> _visible(List<FeedPost> posts) async {
    final hidden = hiddenPostIds;
    if (hidden == null || posts.isEmpty) return List.unmodifiable(posts);
    final Set<String> ids;
    try {
      ids = await hidden();
    } catch (_) {
      return List.unmodifiable(posts);
    }
    if (ids.isEmpty) return List.unmodifiable(posts);
    return List.unmodifiable(posts.where((post) => !ids.contains(post.id)));
  }

  Future<void> _hideRemovedPosts() async {
    final before = state.items;
    if (before.isEmpty) return;
    final visible = await _visible(before);
    if (isClosed || visible.length == before.length) return;
    emit(state.copyWith(items: visible));
  }

  FeedPost? _postById(String postId) {
    for (final post in state.items) {
      if (post.id == postId) return post;
    }
    return null;
  }

  void _updatePost(String postId, FeedPost Function(FeedPost post) update) {
    emit(
      state.copyWith(
        items: List.unmodifiable([
          for (final post in state.items)
            if (post.id == postId) update(post) else post,
        ]),
      ),
    );
  }

  @override
  Future<void> close() async {
    await _eventsSubscription?.cancel();
    return super.close();
  }
}
