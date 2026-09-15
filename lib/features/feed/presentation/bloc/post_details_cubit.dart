import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../training/domain/models/training_history_models.dart';
import '../../domain/models/feed_author.dart';
import '../../domain/models/feed_post.dart';
import '../../domain/repositories/feed_repository.dart';
import '../../domain/services/feed_post_events.dart';
import 'feed_messages.dart';

enum PostDetailsStatus { loading, ready, notFound, failure }

class PostDetailsState {
  const PostDetailsState({
    this.status = PostDetailsStatus.loading,
    this.post,
    this.sessionDetail,
    this.errorMessage,
    this.notice,
  });

  final PostDetailsStatus status;
  final FeedPost? post;

  /// Budowany raz przy wczytaniu — zmiana kudosów nie tworzy nowego obiektu,
  /// więc mapa mięśni nie restartuje animacji.
  final TrainingSessionDetail? sessionDetail;
  final String? errorMessage;
  final FeedNotice? notice;

  PostDetailsState copyWith({
    PostDetailsStatus? status,
    FeedPost? post,
    TrainingSessionDetail? sessionDetail,
    String? errorMessage,
    bool clearErrorMessage = false,
    FeedNotice? notice,
  }) {
    return PostDetailsState(
      status: status ?? this.status,
      post: post ?? this.post,
      sessionDetail: sessionDetail ?? this.sessionDetail,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      notice: notice ?? this.notice,
    );
  }
}

class PostDetailsCubit extends Cubit<PostDetailsState> {
  PostDetailsCubit({
    required FeedRepository repository,
    required this.postId,
    FeedPostEvents? events,
    FeedAuthor? currentUser,
  }) : _repository = repository,
       _events = events,
       _currentUser = currentUser,
       super(const PostDetailsState()) {
    _subscription = _events?.stream.listen(_onPostEvent);
  }

  final FeedRepository _repository;
  final String postId;
  final FeedPostEvents? _events;
  final FeedAuthor? _currentUser;
  StreamSubscription<FeedPostEvent>? _subscription;
  bool _kudosPending = false;
  int _noticeSeq = 0;

  Future<void> load() async {
    if (isClosed) return;
    if (state.post == null) {
      emit(
        state.copyWith(
          status: PostDetailsStatus.loading,
          clearErrorMessage: true,
        ),
      );
    }
    try {
      final detail = await _repository.getPost(postId);
      if (isClosed) return;
      emit(
        PostDetailsState(
          status: PostDetailsStatus.ready,
          post: detail.post,
          sessionDetail: detail.toSessionDetail(),
          notice: state.notice,
        ),
      );
    } catch (error) {
      if (isClosed) return;
      if (isNotFoundError(error)) {
        emit(PostDetailsState(status: PostDetailsStatus.notFound, notice: state.notice));
        return;
      }
      if (state.post != null) {
        emit(
          state.copyWith(
            notice: FeedNotice(
              id: ++_noticeSeq,
              message: postLoadErrorMessage(error),
            ),
          ),
        );
        return;
      }
      emit(
        state.copyWith(
          status: PostDetailsStatus.failure,
          errorMessage: postLoadErrorMessage(error),
        ),
      );
    }
  }

  Future<void> toggleKudos() async {
    final original = state.post;
    if (isClosed || original == null || original.isOwn || _kudosPending) {
      return;
    }
    _kudosPending = true;
    final wasKudoed = original.hasKudoed;
    emit(
      state.copyWith(
        post: original.withKudos(
          hasKudoed: !wasKudoed,
          kudosCount: original.kudosCount + (wasKudoed ? -1 : 1),
          me: _currentUser,
        ),
      ),
    );

    try {
      final result = wasKudoed
          ? await _repository.removeKudos(postId)
          : await _repository.giveKudos(postId);
      if (isClosed) return;
      emit(
        state.copyWith(
          post: state.post!.withKudos(
            hasKudoed: result.hasKudoed,
            kudosCount: result.kudosCount,
            me: _currentUser,
          ),
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
      emit(
        state.copyWith(
          post: state.post!.copyWith(
            hasKudoed: original.hasKudoed,
            kudosCount: original.kudosCount,
            recentKudos: original.recentKudos,
          ),
          notice: FeedNotice(
            id: ++_noticeSeq,
            message: kudosErrorMessage(error, removing: wasKudoed),
          ),
        ),
      );
    } finally {
      _kudosPending = false;
    }
  }

  void _onPostEvent(FeedPostEvent event) {
    final post = state.post;
    if (isClosed || post == null || event.postId != postId) return;
    switch (event) {
      case PostKudosChanged():
        if (_kudosPending) return;
        emit(
          state.copyWith(
            post: post.withKudos(
              hasKudoed: event.hasKudoed,
              kudosCount: event.kudosCount,
              me: _currentUser,
            ),
          ),
        );
      case PostCommentCountChanged():
        emit(state.copyWith(post: post.withCommentDelta(event.delta)));
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
