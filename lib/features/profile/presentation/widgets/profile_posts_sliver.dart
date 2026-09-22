import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../feed/domain/repositories/feed_repository.dart';
import '../../../feed/presentation/utils/feed_navigation.dart';
import '../../../feed/presentation/widgets/feed_post_card.dart';
import '../../../feed/presentation/widgets/kudos_sheet.dart';
import '../bloc/profile_posts_cubit.dart';
import '../bloc/profile_posts_state.dart';
import 'profile_empty_state.dart';

/// Udostępnione treningi na profilu — te same karty co w feedzie, bez
/// powtarzania autora. Wymaga [ProfilePostsCubit] w kontekście.
class ProfilePostsSliver extends StatelessWidget {
  const ProfilePostsSliver({
    super.key,
    required this.feedRepository,
    this.currentUserId,
    this.emptyTitle = 'Brak udostępnionych treningów',
    this.emptyMessage =
        'Ukończone treningi udostępnione na profilu pojawią się tutaj.',
    this.emptyActionLabel,
    this.onEmptyActionTap,
  });

  final FeedRepository feedRepository;
  final String? currentUserId;
  final String emptyTitle;
  final String emptyMessage;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyActionTap;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfilePostsCubit, ProfilePostsState>(
      buildWhen: (previous, current) =>
          previous.status != current.status ||
          previous.items != current.items ||
          previous.hasMore != current.hasMore ||
          previous.loadingMore != current.loadingMore ||
          previous.offline != current.offline,
      builder: (context, state) {
        if (state.items.isEmpty) {
          return SliverToBoxAdapter(
            child: switch (state.status) {
              ProfilePostsStatus.loading => const ProfilePostsSkeleton(),
              ProfilePostsStatus.failure => ProfileEmptyState(
                icon: state.offline
                    ? Icons.cloud_off_rounded
                    : Icons.refresh_rounded,
                title: state.offline
                    ? 'Brak połączenia'
                    : 'Nie udało się wczytać aktywności',
                message: state.offline
                    ? 'Aktywność wczyta się, gdy wrócisz online.'
                    : 'Spróbuj ponownie za chwilę.',
                actionLabel: 'Spróbuj ponownie',
                onActionTap: () => context.read<ProfilePostsCubit>().load(),
              ),
              ProfilePostsStatus.ready => ProfileEmptyState(
                icon: Icons.fitness_center_outlined,
                title: emptyTitle,
                message: emptyMessage,
                actionLabel: emptyActionLabel,
                onActionTap: onEmptyActionTap,
              ),
            },
          );
        }

        final posts = state.items;
        return SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pageGutter,
          ),
          sliver: SliverList.builder(
            itemCount: posts.length + (state.hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == posts.length) {
                return _LoadMoreButton(loading: state.loadingMore);
              }
              final post = posts[index];
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == posts.length - 1 && !state.hasMore
                      ? 0
                      : AppSpacing.md,
                ),
                child: FeedPostCard(
                  key: ValueKey('profile-post-${post.id}'),
                  post: post,
                  showAuthor: false,
                  onTap: () => openPostDetails(context, post.id),
                  onKudosTap: () =>
                      context.read<ProfilePostsCubit>().toggleKudos(post.id),
                  onKudosListTap: () => showKudosSheet(
                    context: context,
                    postId: post.id,
                    repository: feedRepository,
                    currentUserId: currentUserId,
                  ),
                  onCommentTap: () =>
                      openPostDetails(context, post.id, focusComment: true),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _LoadMoreButton extends StatelessWidget {
  const _LoadMoreButton({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: loading
          ? const Padding(
              padding: EdgeInsets.all(AppSpacing.sm),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.primary,
                ),
              ),
            )
          : TextButton(
              onPressed: () => context.read<ProfilePostsCubit>().loadMore(),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryVariant,
                minimumSize: const Size(0, AppSpacing.minTapTarget),
              ),
              child: const Text('Pokaż starsze treningi'),
            ),
    );
  }
}

/// Szkielet dwóch kart osi czasu.
class ProfilePostsSkeleton extends StatelessWidget {
  const ProfilePostsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      label: 'Wczytywanie aktywności',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageGutter),
        child: Column(
          children: [
            for (var i = 0; i < 2; i++)
              Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(
                    color: AppColors.border.withValues(alpha: 0.55),
                  ),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBlock(width: 90, height: 10),
                    SizedBox(height: 12),
                    SkeletonBlock(width: 180, height: 18),
                    SizedBox(height: 16),
                    SkeletonBlock(height: 64, radius: 16),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: SkeletonBlock(height: 40, radius: 20)),
                        SizedBox(width: 8),
                        Expanded(child: SkeletonBlock(height: 40, radius: 20)),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
