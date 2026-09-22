import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_tab_header.dart';
import '../../../feed/domain/models/feed_author.dart';
import '../../../feed/domain/repositories/feed_repository.dart';
import '../../../feed/domain/services/feed_post_events.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../bloc/follow_cubit.dart';
import '../bloc/follow_state.dart';
import '../bloc/profile_posts_cubit.dart';
import '../bloc/profile_posts_state.dart';
import '../widgets/follow_button.dart';
import '../widgets/profile_hero_header.dart';
import '../widgets/profile_posts_sliver.dart';
import '../widgets/profile_section_header.dart';
import '../widgets/profile_skeleton.dart';

/// Profil innego użytkownika. Wymaga [FollowCubit] w kontekście.
class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({
    super.key,
    required this.userId,
    required this.repository,
    required this.feedRepository,
    this.currentUserId,
    this.currentUser,
    this.postEvents,
  });

  final String userId;
  final ProfileRepository repository;
  final FeedRepository feedRepository;
  final String? currentUserId;

  /// Zalogowany użytkownik — jego awatar trafia do stosu kudosów.
  final FeedAuthor? currentUser;
  final FeedPostEvents? postEvents;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  late final FollowCubit _followCubit;
  late ProfilePostsCubit _postsCubit;
  late Future<UserProfile> _future;

  @override
  void initState() {
    super.initState();
    _followCubit = context.read<FollowCubit>();
    _postsCubit = _createPostsCubit();
    _load();
  }

  @override
  void didUpdateWidget(covariant UserProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _postsCubit.close();
      _postsCubit = _createPostsCubit();
      _load();
    }
  }

  @override
  void dispose() {
    _postsCubit.close();
    super.dispose();
  }

  ProfilePostsCubit _createPostsCubit() => ProfilePostsCubit(
    repository: widget.feedRepository,
    userId: widget.userId,
    events: widget.postEvents,
    currentUser: widget.currentUser,
  );

  void _load() {
    _future = _fetch();
    _postsCubit.load();
  }

  Future<UserProfile> _fetch() async {
    final profile = await widget.repository.getUserProfile(widget.userId);
    _followCubit.seedProfile(profile);
    return profile;
  }

  bool _isMe(UserProfile profile) =>
      profile.isOwnProfile ||
      (widget.currentUserId != null && profile.id == widget.currentUserId);

  Widget _backButton(BuildContext context) =>
      AppTabHeaderButton.back(onPressed: () => context.pop());

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _postsCubit,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: AppTabBackground(
          child: FollowFailureListener(
            child: BlocListener<ProfilePostsCubit, ProfilePostsState>(
              listenWhen: (previous, current) =>
                  current.notice != null && current.notice != previous.notice,
              listener: (context, state) => ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(state.notice!.message))),
              child: FutureBuilder<UserProfile>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return ProfileSkeleton(leading: _backButton(context));
                  }
                  final profile = snapshot.data;
                  if (snapshot.hasError || profile == null) {
                    return _ErrorView(
                      back: _backButton(context),
                      onRetry: () => setState(_load),
                    );
                  }
                  return _content(context, profile);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, UserProfile profile) {
    final isMe = _isMe(profile);
    return RefreshIndicator(
      onRefresh: () async {
        setState(_load);
        try {
          await Future.wait([_future, _postsCubit.refresh()]);
        } catch (_) {}
      },
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: ProfileHeroHeader(
              profile: profile,
              leading: _backButton(context),
              showSync: false,
              followsYou: !isMe && profile.isFollowedBy,
              primaryAction: isMe
                  ? null
                  : FollowToggleButton(userId: profile.id, expanded: true),
              stats: BlocBuilder<FollowCubit, FollowState>(
                buildWhen: (previous, current) =>
                    previous.followersCountOf(profile.id) !=
                    current.followersCountOf(profile.id),
                builder: (context, followState) => ProfileStatsRow(
                  followingCount: profile.stats.followingCount,
                  followersCount:
                      followState.followersCountOf(profile.id) ??
                      profile.stats.followersCount,
                  workoutsCount: profile.stats.workoutsCount,
                  onFollowingTap: () => context.push(
                    isMe
                        ? '/app/profile/following'
                        : '/app/users/${profile.id}/following',
                  ),
                  onFollowersTap: () => context.push(
                    isMe
                        ? '/app/profile/followers'
                        : '/app/users/${profile.id}/followers',
                  ),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: ProfileSectionHeader(title: 'Aktywność'),
          ),
          ProfilePostsSliver(
            feedRepository: widget.feedRepository,
            currentUserId: widget.currentUserId,
            emptyMessage:
                '${profile.firstName} nie udostępnia jeszcze treningów.',
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: AppSpacing.xxl + MediaQuery.paddingOf(context).bottom,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.back, required this.onRetry});

  final Widget back;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.xs),
            child: back,
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.person_off_outlined,
                      color: AppColors.textSecondary,
                      size: 36,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'Nie udało się wczytać profilu.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(
                      onPressed: onRetry,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, AppSpacing.minTapTarget),
                      ),
                      child: const Text('Spróbuj ponownie'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
