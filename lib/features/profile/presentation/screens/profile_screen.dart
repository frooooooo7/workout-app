import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../bloc/profile_cubit.dart';
import '../bloc/profile_state.dart';
import '../widgets/edit_profile_bio_sheet.dart';
import '../widgets/profile_activity_feed.dart';
import '../widgets/profile_hero_header.dart';
import '../widgets/profile_section_header.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  GoRouter? _router;

  @override
  void initState() {
    super.initState();
    ServiceLocator.profileRefreshTick.addListener(_onProfileRefreshRequested);
    context.read<ProfileCubit>().load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.maybeOf(context);
    if (router == null) return;
    if (!identical(_router, router)) {
      _router?.routerDelegate.removeListener(_onRouteStackChanged);
      _router = router;
      _router!.routerDelegate.addListener(_onRouteStackChanged);
    }
  }

  void _onRouteStackChanged() {
    if (!mounted) return;
    if (_router?.state.uri.path == '/app/profile') {
      _refreshIfLoaded();
    }
  }

  void _onProfileRefreshRequested() {
    if (!mounted) return;
    if (_router?.state.uri.path == '/app/profile') {
      _refreshIfLoaded();
    }
  }

  void _refreshIfLoaded() {
    final cubit = context.read<ProfileCubit>();
    if (cubit.state.profile != null && !cubit.state.refreshing) {
      unawaited(cubit.refresh());
    }
  }

  @override
  void dispose() {
    ServiceLocator.profileRefreshTick.removeListener(_onProfileRefreshRequested);
    _router?.routerDelegate.removeListener(_onRouteStackChanged);
    super.dispose();
  }

  Future<void> _handleBioEdit(BuildContext context, ProfileState state) async {
    final bio = state.profile?.bio ?? '';
    final result = await showEditProfileBioSheet(context, initialBio: bio);
    if (!context.mounted || result == null) return;
    await context.read<ProfileCubit>().updateBio(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: BlocBuilder<ProfileCubit, ProfileState>(
        builder: (context, state) {
          if (state.loading && state.profile == null) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (state.error != null && state.profile == null) {
            return _ErrorView(
              message: state.error!,
              onRetry: () => context.read<ProfileCubit>().load(),
            );
          }

          final profile = state.profile;
          if (profile == null) {
            return const SizedBox.shrink();
          }

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => context.read<ProfileCubit>().refresh(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: ProfileHeroHeader(
                    profile: profile,
                    onSettingsTap: () => context.push('/app/profile/settings'),
                    onBioEditTap: () => _handleBioEdit(context, state),
                  ),
                ),
                SliverToBoxAdapter(
                  child: ProfileStatsRow(
                    followingCount: profile.stats.followingCount,
                    followersCount: profile.stats.followersCount,
                    workoutsCount: profile.stats.workoutsCount,
                    onFollowingTap: () => context.push('/app/profile/following'),
                    onFollowersTap: () => context.push('/app/profile/followers'),
                    onWorkoutsTap: () => context.go('/app/activity'),
                  ),
                ),
                if (state.highlightActivity != null) ...[
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                  SliverToBoxAdapter(
                    child: ProfileHighlightActivity(
                      activity: state.highlightActivity!,
                      profile: profile,
                    ),
                  ),
                ],
                SliverToBoxAdapter(
                  child: ProfileSectionHeader(
                    title: 'Twoja aktywność',
                    actionLabel: 'Zobacz wszystkie',
                    onActionTap: () => context.go('/app/activity'),
                  ),
                ),
                SliverToBoxAdapter(
                  child: ProfileActivityFeed(
                    activities: state.recentActivities,
                    profile: profile,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.strengthWeak, size: 40),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Spróbuj ponownie')),
          ],
        ),
      ),
    );
  }
}
