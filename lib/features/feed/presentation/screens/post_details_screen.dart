import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../profile/presentation/widgets/follow_button.dart';
import '../../../training/domain/models/training_history_models.dart';
import '../../../training/presentation/widgets/session_details/session_exercise_card.dart';
import '../../../training/presentation/widgets/session_details/session_muscle_map.dart';
import '../../../training/presentation/widgets/session_details/session_summary_header.dart';
import '../../domain/models/feed_post.dart';
import '../../domain/models/post_comment.dart';
import '../../domain/repositories/feed_repository.dart';
import '../bloc/post_comments_cubit.dart';
import '../bloc/post_details_cubit.dart';
import '../utils/feed_formatters.dart';
import '../utils/feed_navigation.dart';
import '../widgets/comment_input_bar.dart';
import '../widgets/feed_status_views.dart';
import '../widgets/kudos_sheet.dart';
import '../widgets/post_author_row.dart';
import '../widgets/post_comment_tile.dart';
import '../widgets/post_social_bar.dart';

/// Szczegóły posta: autor, metryki, mapa mięśni, ćwiczenia z seriami,
/// kudosy i komentarze. Wymaga [PostDetailsCubit], [PostCommentsCubit]
/// i `FollowCubit` w kontekście (dostarcza je router).
class PostDetailsScreen extends StatefulWidget {
  const PostDetailsScreen({
    super.key,
    required this.postId,
    required this.repository,
    this.currentUserId,
    this.focusComment = false,
  });

  final String postId;
  final FeedRepository repository;
  final String? currentUserId;

  /// Otwarte przyciskiem „Komentarz” — fokus na polu i przewinięcie do
  /// komentarzy.
  final bool focusComment;

  @override
  State<PostDetailsScreen> createState() => _PostDetailsScreenState();
}

class _PostDetailsScreenState extends State<PostDetailsScreen> {
  final _commentFocus = FocusNode();
  final _commentsKey = GlobalKey();
  bool _didAutoFocus = false;

  @override
  void initState() {
    super.initState();
    context.read<PostDetailsCubit>().load();
    context.read<PostCommentsCubit>().load();
  }

  @override
  void dispose() {
    _commentFocus.dispose();
    super.dispose();
  }

  void _maybeAutoFocus() {
    if (!widget.focusComment || _didAutoFocus) return;
    _didAutoFocus = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _commentFocus.requestFocus();
      final commentsContext = _commentsKey.currentContext;
      if (commentsContext != null) {
        Scrollable.ensureVisible(
          commentsContext,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  Future<void> _confirmDelete(PostComment comment) async {
    final cubit = context.read<PostCommentsCubit>();
    final action = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ListTile(
            leading: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.strengthWeak,
            ),
            title: const Text(
              'Usuń komentarz',
              style: TextStyle(
                color: AppColors.strengthWeak,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () => Navigator.of(sheetContext).pop(true),
          ),
        ),
      ),
    );
    if (action != true || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Usunąć komentarz?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Tej operacji nie można cofnąć.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Anuluj'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Usuń',
              style: TextStyle(color: AppColors.strengthWeak),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) await cubit.deleteComment(comment.id);
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<PostDetailsCubit, PostDetailsState>(
          listenWhen: (previous, current) =>
              current.notice != null &&
              previous.notice?.id != current.notice!.id,
          listener: (_, state) => _showSnackBar(state.notice!.message),
        ),
        BlocListener<PostDetailsCubit, PostDetailsState>(
          listenWhen: (previous, current) =>
              previous.status != current.status &&
              current.status == PostDetailsStatus.ready,
          listener: (_, _) => _maybeAutoFocus(),
        ),
        BlocListener<PostCommentsCubit, PostCommentsState>(
          listenWhen: (previous, current) =>
              current.notice != null &&
              previous.notice?.id != current.notice!.id,
          listener: (_, state) => _showSnackBar(state.notice!.message),
        ),
      ],
      child: FollowFailureListener(
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                AppHeader(
                  title: 'Trening',
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                Expanded(
                  child: BlocBuilder<PostDetailsCubit, PostDetailsState>(
                    builder: (context, state) => _buildContent(context, state),
                  ),
                ),
                BlocBuilder<PostDetailsCubit, PostDetailsState>(
                  buildWhen: (previous, current) =>
                      previous.status != current.status,
                  builder: (context, detailsState) {
                    if (detailsState.status != PostDetailsStatus.ready) {
                      return const SizedBox.shrink();
                    }
                    return BlocSelector<PostCommentsCubit, PostCommentsState,
                        bool>(
                      selector: (state) => state.isSending,
                      builder: (context, sending) => CommentInputBar(
                        focusNode: _commentFocus,
                        sending: sending,
                        onSend: context.read<PostCommentsCubit>().addComment,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, PostDetailsState state) {
    switch (state.status) {
      case PostDetailsStatus.loading:
        return const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        );
      case PostDetailsStatus.notFound:
        return FeedMessageView(
          icon: Icons.visibility_off_outlined,
          title: 'Ten trening nie jest już dostępny',
          message: 'Autor mógł go usunąć albo przestać go udostępniać.',
          actionLabel: 'Wróć',
          onAction: () => Navigator.of(context).maybePop(),
        );
      case PostDetailsStatus.failure:
        return FeedMessageView(
          icon: Icons.wifi_off_rounded,
          title: 'Nie udało się wczytać treningu',
          message: state.errorMessage,
          actionLabel: 'Spróbuj ponownie',
          onAction: context.read<PostDetailsCubit>().load,
        );
      case PostDetailsStatus.ready:
        return _PostDetailsBody(
          post: state.post!,
          sessionDetail: state.sessionDetail!,
          commentsKey: _commentsKey,
          repository: widget.repository,
          currentUserId: widget.currentUserId,
          onDeleteComment: _confirmDelete,
        );
    }
  }
}

class _PostDetailsBody extends StatelessWidget {
  const _PostDetailsBody({
    required this.post,
    required this.sessionDetail,
    required this.commentsKey,
    required this.repository,
    required this.currentUserId,
    required this.onDeleteComment,
  });

  final FeedPost post;
  final TrainingSessionDetail sessionDetail;
  final GlobalKey commentsKey;
  final FeedRepository repository;
  final String? currentUserId;
  final ValueChanged<PostComment> onDeleteComment;

  @override
  Widget build(BuildContext context) {
    final exercises = sessionDetail.exercises;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: PostAuthorRow(
            author: post.author,
            timestamp: formatFeedTimestamp(post.startedAt),
            onTap: () =>
                openAuthorProfile(context, post.author.id, isOwn: post.isOwn),
          ),
        ),
        const SizedBox(height: 12),
        SessionSummaryHeader(detail: sessionDetail),
        const SizedBox(height: 12),
        _KudosPanel(
          post: post,
          onKudosTap: context.read<PostDetailsCubit>().toggleKudos,
          onKudosListTap: () => showKudosSheet(
            context: context,
            postId: post.id,
            repository: repository,
            currentUserId: currentUserId,
          ),
        ),
        const SizedBox(height: 12),
        SessionMuscleMap(detail: sessionDetail),
        if (exercises.isNotEmpty) ...[
          const SizedBox(height: 22),
          const _SectionTitle('Ćwiczenia'),
          for (var i = 0; i < exercises.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SessionExerciseCard(exercise: exercises[i], index: i),
            ),
        ],
        const SizedBox(height: 18),
        _CommentsSection(
          key: commentsKey,
          commentCount: post.commentCount,
          onDeleteComment: onDeleteComment,
        ),
      ],
    );
  }
}

class _KudosPanel extends StatelessWidget {
  const _KudosPanel({
    required this.post,
    required this.onKudosTap,
    required this.onKudosListTap,
  });

  final FeedPost post;
  final VoidCallback onKudosTap;
  final VoidCallback onKudosListTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
      ),
      child: Row(
        children: [
          Expanded(
            child: post.kudosCount > 0
                ? PostSocialSummary(post: post, onKudosListTap: onKudosListTap)
                : Text(
                    post.isOwn
                        ? 'Nikt jeszcze nie dał kudosa'
                        : 'Bądź pierwszą osobą z kudosem',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12.5,
                    ),
                  ),
          ),
          if (!post.isOwn)
            SizedBox(
              width: 140,
              child: PostKudosButton(
                key: ValueKey('post-details-kudos-${post.id}'),
                hasKudoed: post.hasKudoed,
                onTap: onKudosTap,
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

class _CommentsSection extends StatelessWidget {
  const _CommentsSection({
    super.key,
    required this.commentCount,
    required this.onDeleteComment,
  });

  final int commentCount;
  final ValueChanged<PostComment> onDeleteComment;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PostCommentsCubit, PostCommentsState>(
      builder: (context, state) {
        final cubit = context.read<PostCommentsCubit>();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionTitle(
              commentCount > 0 ? 'Komentarze ($commentCount)' : 'Komentarze',
            ),
            if (state.status == PostCommentsStatus.loading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (state.status == PostCommentsStatus.failure)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        state.errorMessage ??
                            'Nie udało się wczytać komentarzy.',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: cubit.load,
                      child: const Text('Ponów'),
                    ),
                  ],
                ),
              )
            else if (state.items.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Text(
                  'Brak komentarzy. Napisz pierwszy!',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              )
            else ...[
              for (final comment in state.items)
                PostCommentTile(
                  key: ValueKey('post-comment-${comment.id}'),
                  comment: comment,
                  onAuthorTap: comment.isPending
                      ? null
                      : () => openAuthorProfile(
                          context,
                          comment.author.id,
                          isOwn: comment.isOwn,
                        ),
                  onDelete: comment.canDelete && !comment.isPending
                      ? () => onDeleteComment(comment)
                      : null,
                ),
              if (state.hasMore)
                Align(
                  alignment: Alignment.centerLeft,
                  child: state.isLoadingMore
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: AppColors.primary,
                            ),
                          ),
                        )
                      : TextButton(
                          onPressed: cubit.loadMore,
                          child: const Text('Pokaż kolejne komentarze'),
                        ),
                ),
            ],
          ],
        );
      },
    );
  }
}
