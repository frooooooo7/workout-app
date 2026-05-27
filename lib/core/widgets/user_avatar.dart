import 'package:flutter/material.dart';

import '../network/api_asset_uri.dart';
import '../../features/auth/domain/models/auth_models.dart';
import '../theme/app_colors.dart';

enum UserAvatarSize { sm, md, lg }

extension UserAvatarSizeExtension on UserAvatarSize {
  double get dimension => switch (this) {
        UserAvatarSize.sm => 46,
        UserAvatarSize.md => 52,
        UserAvatarSize.lg => 88,
      };

  double get fontSize => switch (this) {
        UserAvatarSize.sm => 16,
        UserAvatarSize.md => 18,
        UserAvatarSize.lg => 32,
      };

  double get radius => switch (this) {
        UserAvatarSize.sm => 14,
        UserAvatarSize.md => 16,
        UserAvatarSize.lg => 44,
      };
}

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required AuthUser user,
    this.size = UserAvatarSize.md,
    this.imageUrl,
  })  : _user = user,
        _firstName = null,
        _lastName = null;

  const UserAvatar.fromNames({
    super.key,
    required String firstName,
    required String lastName,
    this.size = UserAvatarSize.md,
    this.imageUrl,
  })  : _user = null,
        _firstName = firstName,
        _lastName = lastName;

  final AuthUser? _user;
  final String? _firstName;
  final String? _lastName;
  final UserAvatarSize size;
  final String? imageUrl;

  double get _dimension => size.dimension;

  double get _fontSize => size.fontSize;

  double get _radius => size.radius;

  String get _initials {
    final first = _user?.firstName ?? _firstName ?? '';
    final last = _user?.lastName ?? _lastName ?? '';
    final f = first.isNotEmpty ? first[0] : '';
    final l = last.isNotEmpty ? last[0] : '';
    final combined = '$f$l'.toUpperCase();
    return combined.isEmpty ? '?' : combined;
  }

  @override
  Widget build(BuildContext context) {
    final dimension = _dimension;
    final url = resolveApiAssetUrl(imageUrl);

    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(_radius),
        child: Image.network(
          url,
          width: dimension,
          height: dimension,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _buildFallback(dimension),
        ),
      );
    }

    return _buildFallback(dimension);
  }

  Widget _buildFallback(double dimension) {
    return Container(
      width: dimension,
      height: dimension,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryVariant],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(
          color: AppColors.primary.withValues(
            alpha: size == UserAvatarSize.lg ? 0.4 : 0.35,
          ),
          width: size == UserAvatarSize.lg ? 2 : 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: _fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
