import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../profile/domain/models/following_user.dart';
import '../../../profile/presentation/widgets/follow_button.dart';
import '../../../profile/presentation/widgets/user_list_tile.dart';

/// Pusty feed: wyjaśnienie, przycisk wyszukiwarki i proponowane osoby
/// z przyciskiem obserwowania. Wymaga `FollowCubit` w kontekście, gdy
/// lista propozycji nie jest pusta.
class FeedEmptyState extends StatelessWidget {
  const FeedEmptyState({
    super.key,
    required this.suggestions,
    required this.suggestionsLoading,
    required this.onFindFriends,
    this.currentUserId,
    this.onUserTap,
  });

  final List<FollowingUser> suggestions;
  final bool suggestionsLoading;
  final VoidCallback onFindFriends;
  final String? currentUserId;
  final ValueChanged<FollowingUser>? onUserTap;

  @override
  Widget build(BuildContext context) {
    final visible = suggestions
        .where((user) => user.id != currentUserId)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 28, 32, 0),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.35),
                  ),
                ),
                child: const Icon(
                  Icons.dynamic_feed_rounded,
                  color: AppColors.primaryVariant,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Twój feed jest pusty',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Obserwuj znajomych, aby widzieć tu ich treningi. '
                'Twoje udostępnione treningi też pojawią się w tym miejscu.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onFindFriends,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                icon: const Icon(Icons.person_search_rounded, size: 19),
                label: const Text('Znajdź znajomych'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        if (suggestionsLoading && visible.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
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
          ),
        if (visible.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 4),
            child: Text(
              'PROPONOWANE OSOBY',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.7,
              ),
            ),
          ),
          for (final user in visible)
            UserListTile(
              key: ValueKey('feed-suggestion-${user.id}'),
              user: user,
              onTap: onUserTap == null ? null : () => onUserTap!(user),
              trailing: FollowToggleButton(userId: user.id),
            ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}
