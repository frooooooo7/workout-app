import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_tab_header.dart';
import '../../../feed/domain/repositories/feed_repository.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/services/profile_week_calculator.dart';
import '../bloc/profile_cubit.dart';
import '../bloc/profile_posts_cubit.dart';
import '../bloc/profile_posts_state.dart';
import '../bloc/profile_state.dart';
import '../bloc/profile_week_cubit.dart';
import '../widgets/following_avatar_strip.dart';
import '../widgets/profile_hero_header.dart';
import '../widgets/profile_posts_sliver.dart';
import '../widgets/profile_section_header.dart';
import '../widgets/profile_skeleton.dart';
import '../widgets/profile_week_card.dart';

/// Zakładka Profil. Wymaga w kontekście [ProfileCubit], [ProfilePostsCubit]
/// i [ProfileWeekCubit].
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.feedRepository});

  /// Do listy kudosów pod postem.
  final FeedRepository feedRepository;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _path = '/app/profile';

  GoRouter? _router;
  String? _lastPath;

  @override
  void initState() {
    super.initState();
    ServiceLocator.profileRefreshTick.addListener(_onProfileRefreshRequested);
    context.read<ProfileCubit>().load();
    context.read<ProfilePostsCubit>().load();
    context.read<ProfileWeekCubit>().load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.maybeOf(context);
    if (router == null) return;
    if (!identical(_router, router)) {
      _router?.routerDelegate.removeListener(_onRouteStackChanged);
      _router = router;
      _lastPath = router.state.uri.path;
      _router!.routerDelegate.addListener(_onRouteStackChanged);
    }
  }

  void _onRouteStackChanged() {
    if (!mounted) return;
    final path = _router?.state.uri.path;
    if (path == null) return;
    final previous = _lastPath;
    _lastPath = path;
    if (previous != _path && path == _path) {
      _refreshIfLoaded();
    }
  }

  void _onProfileRefreshRequested() {
    if (!mounted) return;
    if (_router?.state.uri.path == _path) {
      _refreshIfLoaded();
    }
  }

  void _refreshIfLoaded() {
    final cubit = context.read<ProfileCubit>();
    if (cubit.state.profile != null && !cubit.state.refreshing) {
      unawaited(_refreshAll());
    }
  }

  Future<void> _refreshAll() => Future.wait([
    context.read<ProfileCubit>().refresh(),
    context.read<ProfilePostsCubit>().refresh(),
    context.read<ProfileWeekCubit>().load(),
  ]);

  @override
  void dispose() {
    ServiceLocator.profileRefreshTick.removeListener(
      _onProfileRefreshRequested,
    );
    _router?.routerDelegate.removeListener(_onRouteStackChanged);
    super.dispose();
  }

  Future<void> _openEditProfile(
    BuildContext context,
    UserProfile profile,
  ) async {
    final cubit = context.read<ProfileCubit>();
    final updated = await context.push<UserProfile>(
      '/app/profile/edit',
      extra: profile,
    );
    if (!mounted || updated == null) return;
    // Po powrocie na /app/profile i tak ruszy odświeżenie (liczniki itd.);
    // nowe dane z edycji pokazujemy od razu.
    cubit.applyProfile(updated);
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AppTabBackground(
        child: MultiBlocListener(
          listeners: [
            BlocListener<ProfileCubit, ProfileState>(
              listenWhen: (previous, current) =>
                  current.errorSeq != previous.errorSeq &&
                  current.profile != null &&
                  current.error != null,
              listener: (context, state) => _showSnack(context, state.error!),
            ),
            BlocListener<ProfilePostsCubit, ProfilePostsState>(
              listenWhen: (previous, current) =>
                  current.notice != null && current.notice != previous.notice,
              listener: (context, state) =>
                  _showSnack(context, state.notice!.message),
            ),
          ],
          child: BlocBuilder<ProfileCubit, ProfileState>(
            builder: (context, state) {
              final profile = state.profile;
              if (profile == null) {
                if (state.error != null && !state.loading) {
                  return _ErrorView(
                    message: state.error!,
                    offline: state.offline,
                    onRetry: () {
                      context.read<ProfileCubit>().load();
                      context.read<ProfilePostsCubit>().load();
                    },
                  );
                }
                return const ProfileSkeleton();
              }
              return _ProfileContent(
                profile: profile,
                state: state,
                feedRepository: widget.feedRepository,
                onRefresh: _refreshAll,
                onEditProfile: () => _openEditProfile(context, profile),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({
    required this.profile,
    required this.state,
    required this.feedRepository,
    required this.onRefresh,
    required this.onEditProfile,
  });

  final UserProfile profile;
  final ProfileState state;
  final FeedRepository feedRepository;
  final Future<void> Function() onRefresh;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: ProfileHeroHeader(
              profile: profile,
              title: 'Profil',
              actions: [
                AppTabHeaderButton(
                  icon: Icons.settings_outlined,
                  tooltip: 'Ustawienia profilu',
                  onPressed: () => context.push('/app/profile/settings'),
                ),
              ],
              onAddBioTap: onEditProfile,
              primaryAction: ProfileEditButton(onPressed: onEditProfile),
              stats: ProfileStatsRow(
                followingCount: profile.stats.followingCount,
                followersCount: profile.stats.followersCount,
                workoutsCount: profile.stats.workoutsCount,
                onWorkoutsTap: () => context.go('/app/history'),
                onFollowersTap: () => context.push('/app/profile/followers'),
                onFollowingTap: () => context.push('/app/profile/following'),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: BlocBuilder<ProfileWeekCubit, ProfileWeekSummary?>(
              builder: (context, summary) {
                if (summary == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: ProfileWeekCard(
                    summary: summary,
                    onTap: () => context.push('/app/training/stats'),
                  ),
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: ProfileSectionHeader(
              title: 'Obserwowani',
              actionLabel: state.following.isEmpty ? null : 'Zobacz wszystkich',
              onActionTap: () => context.push('/app/profile/following'),
            ),
          ),
          SliverToBoxAdapter(
            child: FollowingAvatarStrip(following: state.following),
          ),
          const SliverToBoxAdapter(
            child: ProfileSectionHeader(title: 'Aktywność'),
          ),
          ProfilePostsSliver(
            feedRepository: feedRepository,
            currentUserId: profile.id,
            emptyMessage:
                'Ukończ trening i udostępnij go na profilu — pojawi się tutaj.',
            emptyActionLabel: 'Rozpocznij trening',
            onEmptyActionTap: () => context.go('/app/training'),
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
  const _ErrorView({
    required this.message,
    required this.offline,
    required this.onRetry,
  });

  final String message;
  final bool offline;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
                child: Icon(
                  offline
                      ? Icons.cloud_off_rounded
                      : Icons.error_outline_rounded,
                  color: AppColors.textSecondary,
                  size: 30,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                offline ? 'Jesteś offline' : 'Coś poszło nie tak',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, AppSpacing.minTapTarget),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                  ),
                ),
                child: const Text('Spróbuj ponownie'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
