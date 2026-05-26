import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/profile_activity.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../widgets/profile_activity_feed.dart';
import '../widgets/profile_hero_header.dart';
import '../widgets/profile_section_header.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({
    super.key,
    required this.userId,
    required this.repository,
  });

  final String userId;
  final ProfileRepository repository;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  late Future<_UserProfileData> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant UserProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _load();
    }
  }

  void _load() {
    _future = _fetch();
  }

  Future<_UserProfileData> _fetch() async {
    final results = await Future.wait([
      widget.repository.getUserProfile(widget.userId),
      widget.repository.getRecentActivities(userId: widget.userId, limit: 4),
    ]);
    return _UserProfileData(
      profile: results[0] as UserProfile,
      activities: results[1] as List<ProfileActivity>,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FutureBuilder<_UserProfileData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          if (snapshot.hasError || snapshot.data == null) {
            return _ErrorView(onBack: () => context.pop());
          }

          final data = snapshot.data!;
          final profile = data.profile;
          final highlight = data.activities.isNotEmpty
              ? data.activities.first
              : null;
          final rest = data.activities.length > 1
              ? data.activities.sublist(1)
              : <ProfileActivity>[];

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _load();
              });
              try {
                await _future;
              } catch (_) {}
            },
            color: AppColors.primary,
            backgroundColor: AppColors.surface,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Stack(
                    children: [
                      ProfileHeroHeader(
                        profile: profile,
                        onSettingsTap: () {},
                        showSettings: false,
                      ),
                      if (!profile.isOwnProfile)
                        Positioned(
                          left: 24,
                          top: MediaQuery.paddingOf(context).top + 8,
                          child: IconButton(
                            onPressed: () => context.pop(),
                            icon: const Icon(Icons.arrow_back_rounded),
                            color: AppColors.textSecondary,
                            style: IconButton.styleFrom(
                              minimumSize: const Size(44, 44),
                              backgroundColor:
                                  AppColors.surface.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (!profile.isOwnProfile)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                      child: FilledButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Obserwowanie ${profile.firstName} — wkrótce',
                              ),
                            ),
                          );
                        },
                        child: const Text('Obserwuj'),
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: ProfileStatsRow(
                    followingCount: profile.stats.followingCount,
                    followersCount: profile.stats.followersCount,
                    workoutsCount: profile.stats.workoutsCount,
                    onFollowingTap: () {},
                    onFollowersTap: () {},
                    onWorkoutsTap: () {},
                  ),
                ),
                if (highlight != null) ...[
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                  SliverToBoxAdapter(
                    child: ProfileHighlightActivity(
                      activity: highlight,
                      profile: profile,
                    ),
                  ),
                ],
                SliverToBoxAdapter(
                  child: ProfileSectionHeader(title: 'Aktywność'),
                ),
                SliverToBoxAdapter(
                  child: ProfileActivityFeed(
                    activities: rest,
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

class _UserProfileData {
  const _UserProfileData({
    required this.profile,
    required this.activities,
  });

  final UserProfile profile;
  final List<ProfileActivity> activities;
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Nie udało się wczytać profilu.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
