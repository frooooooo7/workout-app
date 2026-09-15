import 'dart:async';

/// Zmiana posta wprowadzona na jednym ekranie (np. kudos w szczegółach),
/// którą inne ekrany (feed) nanoszą u siebie bez przeładowania.
sealed class FeedPostEvent {
  const FeedPostEvent(this.postId);

  final String postId;
}

class PostKudosChanged extends FeedPostEvent {
  const PostKudosChanged(
    super.postId, {
    required this.hasKudoed,
    required this.kudosCount,
  });

  final bool hasKudoed;
  final int kudosCount;
}

/// Dodany (+1) albo usunięty (−1) komentarz.
class PostCommentCountChanged extends FeedPostEvent {
  const PostCommentCountChanged(super.postId, {required this.delta});

  final int delta;
}

class FeedPostEvents {
  final _controller = StreamController<FeedPostEvent>.broadcast();

  Stream<FeedPostEvent> get stream => _controller.stream;

  void emit(FeedPostEvent event) {
    if (_controller.isClosed) return;
    _controller.add(event);
  }
}
