import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/models/feed_author.dart';
import '../../domain/models/post_comment.dart';
import '../../domain/repositories/feed_repository.dart';
import '../../domain/services/feed_post_events.dart';
import 'feed_messages.dart';

enum PostCommentsStatus { loading, ready, failure }

class PostCommentsState {
  const PostCommentsState({
    this.status = PostCommentsStatus.loading,
    this.items = const [],
    this.nextCursor,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.isSending = false,
    this.errorMessage,
    this.notice,
  });

  final PostCommentsStatus status;

  /// Najstarsze najpierw.
  final List<PostComment> items;
  final String? nextCursor;
  final bool hasMore;
  final bool isLoadingMore;
  final bool isSending;
  final String? errorMessage;
  final FeedNotice? notice;

  PostCommentsState copyWith({
    PostCommentsStatus? status,
    List<PostComment>? items,
    String? nextCursor,
    bool clearNextCursor = false,
    bool? hasMore,
    bool? isLoadingMore,
    bool? isSending,
    String? errorMessage,
    bool clearErrorMessage = false,
    FeedNotice? notice,
  }) {
    return PostCommentsState(
      status: status ?? this.status,
      items: items ?? this.items,
      nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isSending: isSending ?? this.isSending,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      notice: notice ?? this.notice,
    );
  }
}

/// Komentarze posta: stronicowanie kursorem, dodawanie z optymistycznym
/// dopisaniem (cofane przy błędzie) i usuwanie.
class PostCommentsCubit extends Cubit<PostCommentsState> {
  PostCommentsCubit({
    required FeedRepository repository,
    required this.postId,
    FeedPostEvents? events,
    FeedAuthor? currentUser,
    this.pageSize = 30,
  }) : _repository = repository,
       _events = events,
       _currentUser = currentUser,
       super(const PostCommentsState());

  final FeedRepository _repository;
  final String postId;
  final FeedPostEvents? _events;
  final FeedAuthor? _currentUser;
  final int pageSize;
  final _deleting = <String>{};
  int _pendingSeq = 0;
  int _noticeSeq = 0;

  Future<void> load() async {
    if (isClosed) return;
    emit(
      state.copyWith(
        status: PostCommentsStatus.loading,
        clearErrorMessage: true,
      ),
    );
    try {
      final page = await _repository.getComments(postId, limit: pageSize);
      if (isClosed) return;
      final pending = state.items.where((c) => c.isPending);
      emit(
        state.copyWith(
          status: PostCommentsStatus.ready,
          items: List.unmodifiable([...page.items, ...pending]),
          nextCursor: page.nextCursor,
          clearNextCursor: page.nextCursor == null,
          hasMore: page.hasMore,
        ),
      );
    } catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: PostCommentsStatus.failure,
          errorMessage: commentsLoadErrorMessage(error),
        ),
      );
    }
  }

  Future<void> loadMore() async {
    final cursor = state.nextCursor;
    if (isClosed ||
        state.status != PostCommentsStatus.ready ||
        !state.hasMore ||
        cursor == null ||
        state.isLoadingMore) {
      return;
    }
    emit(state.copyWith(isLoadingMore: true));
    try {
      final page = await _repository.getComments(
        postId,
        cursor: cursor,
        limit: pageSize,
      );
      if (isClosed) return;
      final confirmed = state.items.where((c) => !c.isPending).toList();
      final pending = state.items.where((c) => c.isPending);
      final known = {for (final c in confirmed) c.id};
      emit(
        state.copyWith(
          items: List.unmodifiable([
            ...confirmed,
            ...page.items.where((c) => known.add(c.id)),
            ...pending,
          ]),
          nextCursor: page.nextCursor,
          clearNextCursor: page.nextCursor == null,
          hasMore: page.hasMore,
          isLoadingMore: false,
        ),
      );
    } catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isLoadingMore: false,
          notice: FeedNotice(
            id: ++_noticeSeq,
            message: commentsLoadErrorMessage(error),
          ),
        ),
      );
    }
  }

  /// Zwraca `true`, gdy komentarz zapisano. Przy `false` ekran przywraca
  /// wpisany tekst.
  Future<bool> addComment(String body) async {
    final trimmed = body.trim();
    if (isClosed ||
        state.isSending ||
        trimmed.isEmpty ||
        commentLength(trimmed) > kMaxCommentLength) {
      return false;
    }

    final temp = PostComment(
      id: 'pending-${++_pendingSeq}',
      author:
          _currentUser ?? const FeedAuthor(id: '', firstName: 'Ty', lastName: ''),
      body: trimmed,
      createdAt: DateTime.now().toUtc(),
      isOwn: true,
      isPending: true,
    );
    emit(
      state.copyWith(
        items: List.unmodifiable([...state.items, temp]),
        isSending: true,
      ),
    );

    try {
      final saved = await _repository.addComment(postId, trimmed);
      if (isClosed) return true;
      final alreadyListed = state.items.any((c) => c.id == saved.id);
      emit(
        state.copyWith(
          items: List.unmodifiable([
            for (final comment in state.items)
              if (comment.id == temp.id)
                ...(alreadyListed ? const <PostComment>[] : [saved])
              else
                comment,
          ]),
          isSending: false,
        ),
      );
      _events?.emit(PostCommentCountChanged(postId, delta: 1));
      return true;
    } catch (error) {
      if (isClosed) return false;
      emit(
        state.copyWith(
          items: List.unmodifiable(state.items.where((c) => c.id != temp.id)),
          isSending: false,
          notice: FeedNotice(
            id: ++_noticeSeq,
            message: addCommentErrorMessage(error),
          ),
        ),
      );
      return false;
    }
  }

  Future<void> deleteComment(String commentId) async {
    if (isClosed || !_deleting.add(commentId)) return;
    final index = state.items.indexWhere((c) => c.id == commentId);
    if (index < 0 || state.items[index].isPending) {
      _deleting.remove(commentId);
      return;
    }
    final removed = state.items[index];
    emit(
      state.copyWith(
        items: List.unmodifiable(state.items.where((c) => c.id != commentId)),
      ),
    );

    try {
      await _repository.deleteComment(postId, commentId);
      if (isClosed) return;
      _events?.emit(PostCommentCountChanged(postId, delta: -1));
    } catch (error) {
      if (isClosed) return;
      // Ktoś (np. autor posta) usunął go wcześniej — cel osiągnięty.
      if (error is ApiException &&
          (error.statusCode == 404 || error.message == 'comment_not_found')) {
        _events?.emit(PostCommentCountChanged(postId, delta: -1));
        return;
      }
      final items = [...state.items];
      items.insert(index.clamp(0, items.length), removed);
      emit(
        state.copyWith(
          items: List.unmodifiable(items),
          notice: FeedNotice(
            id: ++_noticeSeq,
            message: deleteCommentErrorMessage(error),
          ),
        ),
      );
    } finally {
      _deleting.remove(commentId);
    }
  }
}
