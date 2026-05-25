import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/user_profile.dart';

class ProfileBioSection extends StatelessWidget {
  const ProfileBioSection({
    super.key,
    required this.profile,
    this.onEditTap,
  });

  final UserProfile profile;
  final VoidCallback? onEditTap;

  bool get _hasBio => profile.bio != null && profile.bio!.trim().isNotEmpty;
  bool get _isEditable => profile.isOwnProfile && onEditTap != null;

  @override
  Widget build(BuildContext context) {
    if (!_hasBio && !_isEditable) {
      return const SizedBox.shrink();
    }

    final content = _isEditable
        ? Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onEditTap,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _BioText(hasBio: _hasBio, bio: profile.bio),
                      const SizedBox(width: 6),
                      Icon(
                        _hasBio ? Icons.edit_outlined : Icons.add_rounded,
                        size: 16,
                        color:
                            _hasBio ? AppColors.textMuted : AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _BioText(hasBio: _hasBio, bio: profile.bio),
          );

    return content;
  }
}

class _BioText extends StatelessWidget {
  const _BioText({required this.hasBio, required this.bio});

  final bool hasBio;
  final String? bio;

  @override
  Widget build(BuildContext context) {
    return Text(
      hasBio ? bio! : 'Dodaj opis profilu…',
      textAlign: TextAlign.center,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: hasBio ? AppColors.textSecondary : AppColors.textMuted,
        fontSize: 13,
        fontStyle: hasBio ? FontStyle.normal : FontStyle.italic,
        height: 1.4,
      ),
    );
  }
}
