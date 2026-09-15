import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sync_status_indicator.dart';
import '../../../profile/presentation/bloc/follow_cubit.dart';
import '../../../profile/presentation/widgets/follow_button.dart';
import '../../../training/presentation/widgets/training_header.dart';
import '../../domain/models/feed_post.dart';
import '../../domain/repositories/feed_repository.dart';
import '../bloc/feed_cubit.dart';
import '../bloc/feed_state.dart';
import '../utils/feed_navigation.dart';
import '../widgets/feed_empty_state.dart';
import '../widgets/feed_post_card.dart';
import '../widgets/feed_skeleton.dart';
import '../widgets/feed_status_views.dart';
import '../widgets/kudos_sheet.dart';

/// Zakładka „Aktywność”: feed treningów moich i obserwowanych osób.
/// Wymaga [FeedCubit] i [FollowCubit] w kontekście (dostarcza je router).
class ActivityFeedScreen extends StatefulWidget {
  const ActivityFeedScreen({
    super.key,
    required this.repository,
    this.currentUserId,
  });

  /// Do arkusza kudosów (lista osób).
  final FeedRepository repository;
  final String? currentUserId;

  static const findPeoplePath = '/app/profile/find-people';

  @override
  State<ActivityFeedScreen> createState() => _ActivityFeedScreenState();
}

class _ActivityFeedScreenState extends State<ActivityFeedScreen> {
  final _scrollController = ScrollController();

  /// Doładowanie zaczyna się, zanim użytkownik dojedzie do końca listy.
  static const _loadMoreExtent = 800.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    context.read<FeedCubit>().load();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < _loadMoreExtent) {
      context.read<FeedCubit>().loadMore();
    }
  }

  Future<void> _onRefresh() async {
    HapticFeedback.lightImpact();
    await context.read<FeedCubit>().refresh();
  }

  void _openFindPeople() => context.push(ActivityFeedScreen.findPeoplePath);

  void _showSnackBar(String message) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FollowFailureListener(
          child: MultiBlocListener(
            listeners: [
              BlocListener<FeedCubit, FeedState>(
                listenWhen: (previous, current) =>
                    current.notice != null &&
                    previous.notice?.id != current.notice!.id,
                listener: (_, state) => _showSnackBar(state.notice!.message),
              ),
              BlocListener<FeedCubit, FeedState>(
                listenWhen: (previous, current) =>
                    !identical(previous.suggestions, current.suggestions),
                listener: (context, state) =>
                    context.read<FollowCubit>().seedUsers(state.suggestions),
              ),
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _FeedHeader(onFindPeople: _openFindPeople),
                const SizedBox(height: 12),
                Expanded(
                  child: BlocBuilder<FeedCubit, FeedState>(
                    builder: (context, state) => _buildBody(context, state),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, FeedState state) {
    final cubit = context.read<FeedCubit>();

    if (state.items.isEmpty &&
        (state.status == FeedStatus.initial ||
            state.status == FeedStatus.loading)) {
      return const FeedSkeleton();
    }

    if (state.items.isEmpty && state.status == FeedStatus.failure) {
      return RefreshIndicator(
        onRefresh: _onRefresh,
        color: AppColors.primary,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: constraints.maxHeight,
              child: FeedMessageView(
                icon: Icons.wifi_off_rounded,
                title: 'Nie udało się wczytać feedu',
                message: state.errorMessage,
                actionLabel: 'Spróbuj ponownie',
                onAction: cubit.refresh,
              ),
            ),
          ),
        ),
      );
    }

    if (state.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _onRefresh,
        color: AppColors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (state.staleMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: FeedStaleBanner(message: state.staleMessage!),
              ),
            FeedEmptyState(
              suggestions: state.suggestions,
              suggestionsLoading: state.suggestionsLoading,
              currentUserId: widget.currentUserId,
              onFindFriends: _openFindPeople,
              onUserTap: (user) =>
                  openAuthorProfile(context, user.id, isOwn: false),
            ),
          ],
        ),
      );
    }

    final hasBanner = state.staleMessage != null;
    final bannerOffset = hasBanner ? 1 : 0;

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: AppColors.primary,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        itemCount: state.items.length + bannerOffset + 1,
        itemBuilder: (context, index) {
          if (hasBanner && index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FeedStaleBanner(message: state.staleMessage!),
            );
          }
          final postIndex = index - bannerOffset;
          if (postIndex == state.items.length) {
            return _FeedFooter(
              state: state,
              onRetry: cubit.loadMore,
            );
          }
          final post = state.items[postIndex];
          return Padding(
            key: ValueKey('feed-post-${post.id}'),
            padding: const EdgeInsets.only(bottom: 14),
            child: _FeedPostItem(
              post: post,
              repository: widget.repository,
              currentUserId: widget.currentUserId,
            ),
          );
        },
      ),
    );
  }
}

class _FeedPostItem extends StatelessWidget {
  const _FeedPostItem({
    required this.post,
    required this.repository,
    required this.currentUserId,
  });

  final FeedPost post;
  final FeedRepository repository;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: FeedPostCard(
        post: post,
        onTap: () => openPostDetails(context, post.id),
        onAuthorTap: () =>
            openAuthorProfile(context, post.author.id, isOwn: post.isOwn),
        onKudosTap: () => context.read<FeedCubit>().toggleKudos(post.id),
        onKudosListTap: () => showKudosSheet(
          context: context,
          postId: post.id,
          repository: repository,
          currentUserId: currentUserId,
        ),
        onCommentTap: () =>
            openPostDetails(context, post.id, focusComment: true),
      ),
    );
  }
}

class _FeedHeader extends StatelessWidget {
  const _FeedHeader({required this.onFindPeople});

  final VoidCallback onFindPeople;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aktywność',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Treningi Twoje i obserwowanych osób',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          HeaderIconButton(
            key: const ValueKey('feed-find-people-button'),
            tooltip: 'Znajdź osoby',
            icon: Icons.person_add_alt_1_rounded,
            onTap: onFindPeople,
          ),
          const SizedBox(width: 10),
          const SyncStatusIndicator(),
        ],
      ),
    );
  }
}

class _FeedFooter extends StatelessWidget {
  const _FeedFooter({required this.state, required this.onRetry});

  final FeedState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (state.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: AppColors.primary,
            ),
          ),
        ),
      );
    }
    if (state.loadMoreFailed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Nie udało się wczytać starszych. Ponów'),
          ),
        ),
      );
    }
    if (!state.hasMore && state.items.length > 3) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text(
            'To już wszystkie treningi',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
          ),
        ),
      );
    }
    return const SizedBox(height: 8);
  }
}
