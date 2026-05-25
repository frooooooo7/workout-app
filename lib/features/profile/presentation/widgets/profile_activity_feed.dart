import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/profile_activity.dart';
import '../../domain/models/user_profile.dart';
import 'profile_activity_post_card.dart';
import 'profile_empty_state.dart';
import 'profile_section_header.dart';

void openProfileActivity(BuildContext context, ProfileActivity activity) {
  if (activity.id != null) {
    context.push('/app/training/history/${activity.id}');
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Szczegóły aktywności wkrótce')),
  );
}

class ProfileHighlightActivity extends StatelessWidget {
  const ProfileHighlightActivity({
    super.key,
    required this.activity,
    required this.profile,
  });

  final ProfileActivity activity;
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ProfileSectionHeader(title: 'Ostatnia aktywność'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ProfileActivityPostCard(
            activity: activity,
            authorFirstName: profile.firstName,
            authorLastName: profile.lastName,
            authorAvatarUrl: profile.avatarUrl,
            isHighlighted: true,
            onTap: () => openProfileActivity(context, activity),
          ),
        ),
      ],
    );
  }
}

class ProfileActivityFeed extends StatelessWidget {
  const ProfileActivityFeed({
    super.key,
    required this.activities,
    required this.profile,
    this.onSeeAllTap,
  });

  final List<ProfileActivity> activities;
  final UserProfile profile;
  final VoidCallback? onSeeAllTap;

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return ProfileEmptyState(
        icon: Icons.fitness_center_outlined,
        message:
            'Brak wcześniejszych aktywności.\nUkończ trening, aby zobaczyć go tutaj.',
        actionLabel: 'Przejdź do treningu',
        onActionTap: () => context.go('/app/training'),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          for (var i = 0; i < activities.length; i++) ...[
            ProfileActivityPostCard(
              activity: activities[i],
              authorFirstName: profile.firstName,
              authorLastName: profile.lastName,
              authorAvatarUrl: profile.avatarUrl,
              onTap: () => openProfileActivity(context, activities[i]),
            ),
            if (i < activities.length - 1) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}
