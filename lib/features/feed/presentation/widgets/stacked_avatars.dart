import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../domain/models/feed_author.dart';

/// Nachodzące na siebie mini-awatary (np. ostatnie kudosy).
class StackedAvatars extends StatelessWidget {
  const StackedAvatars({super.key, required this.authors, this.maxCount = 3});

  final List<FeedAuthor> authors;
  final int maxCount;

  static const double _size = 24;
  static const double _ring = 2;
  static const double _offset = 16;

  @override
  Widget build(BuildContext context) {
    final visible = authors.take(maxCount).toList(growable: false);
    if (visible.isEmpty) return const SizedBox.shrink();
    final outer = _size + _ring * 2;

    return SizedBox(
      width: outer + (visible.length - 1) * _offset,
      height: outer,
      child: Stack(
        children: [
          // Pierwszy awatar na wierzchu — rysowany ostatni.
          for (var i = visible.length - 1; i >= 0; i--)
            Positioned(
              left: i * _offset,
              child: Container(
                padding: const EdgeInsets.all(_ring),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: UserAvatar.fromNames(
                  firstName: visible[i].firstName,
                  lastName: visible[i].lastName,
                  imageUrl: visible[i].avatarUrl,
                  size: UserAvatarSize.xxs,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
