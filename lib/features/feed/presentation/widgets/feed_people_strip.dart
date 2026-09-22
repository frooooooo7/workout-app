import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../domain/models/feed_author.dart';
import '../../domain/models/feed_post.dart';
import 'post_author_row.dart';

/// Poziomy pasek osób w stylu „stories”: kafelek „Znajdź” + autorzy
/// z wczytanego feedu (bez siebie). Gradientowa obwódka = trening dziś.
class FeedPeopleStrip extends StatelessWidget {
  const FeedPeopleStrip({
    super.key,
    required this.posts,
    required this.onFindPeople,
    required this.onAuthorTap,
    this.now,
  });

  final List<FeedPost> posts;
  final VoidCallback onFindPeople;
  final ValueChanged<FeedAuthor> onAuthorTap;

  /// Test seam dla „dziś”.
  final DateTime? now;

  static const _maxPeople = 15;

  @override
  Widget build(BuildContext context) {
    final current = (now ?? DateTime.now()).toLocal();
    final people = <String, ({FeedAuthor author, bool today})>{};
    for (final post in posts) {
      if (post.isOwn) continue;
      final at = post.startedAt.toLocal();
      final today = at.year == current.year &&
          at.month == current.month &&
          at.day == current.day;
      final existing = people[post.author.id];
      if (existing == null) {
        if (people.length >= _maxPeople) continue;
        people[post.author.id] = (author: post.author, today: today);
      } else if (today && !existing.today) {
        people[post.author.id] = (author: existing.author, today: true);
      }
    }

    return SizedBox(
      height: 92,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _StripItem(
            key: const ValueKey('feed-strip-find-people'),
            label: 'Znajdź',
            onTap: onFindPeople,
            avatar: const _FindPeopleAvatar(),
          ),
          for (final entry in people.values)
            _StripItem(
              key: ValueKey('feed-strip-${entry.author.id}'),
              label: entry.author.firstName,
              onTap: () => onAuthorTap(entry.author),
              avatar: GradientAvatarRing(
                active: entry.today,
                child: UserAvatar.fromNames(
                  firstName: entry.author.firstName,
                  lastName: entry.author.lastName,
                  imageUrl: entry.author.avatarUrl,
                  size: UserAvatarSize.sm,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StripItem extends StatelessWidget {
  const _StripItem({
    super.key,
    required this.label,
    required this.avatar,
    required this.onTap,
  });

  final String label;
  final Widget avatar;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 64,
          child: Column(
            children: [
              const SizedBox(height: 2),
              avatar,
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FindPeopleAvatar extends StatelessWidget {
  const _FindPeopleAvatar();

  @override
  Widget build(BuildContext context) {
    // Wymiary jak GradientAvatarRing wokół awatara `sm` (46 + 2×4).
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: const Icon(
        Icons.person_add_alt_1_rounded,
        color: AppColors.primaryVariant,
        size: 22,
      ),
    );
  }
}
