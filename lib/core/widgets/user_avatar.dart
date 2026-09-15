import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../features/auth/domain/models/auth_models.dart';
import '../images/offline_network_image.dart';
import '../network/api_asset_uri.dart';
import '../theme/app_colors.dart';

enum UserAvatarSize { sm, md, lg }

/// Awatar użytkownika: zdjęcie z API (ścieżka względna `/uploads/avatars/…`
/// albo pełny adres, cache na dysku) lub inicjały, gdy zdjęcia brak albo nie
/// da się go wczytać. [imageBytes] (np. świeżo wybrane zdjęcie) ma
/// pierwszeństwo przed [imageUrl].
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required AuthUser user,
    this.size = UserAvatarSize.md,
    this.imageUrl,
    this.imageBytes,
  })  : _user = user,
        _firstName = null,
        _lastName = null;

  const UserAvatar.fromNames({
    super.key,
    required String firstName,
    required String lastName,
    this.size = UserAvatarSize.md,
    this.imageUrl,
    this.imageBytes,
  })  : _user = null,
        _firstName = firstName,
        _lastName = lastName;

  final AuthUser? _user;
  final String? _firstName;
  final String? _lastName;
  final UserAvatarSize size;
  final String? imageUrl;
  final Uint8List? imageBytes;

  double get _dimension => switch (size) {
        UserAvatarSize.sm => 46,
        UserAvatarSize.md => 52,
        UserAvatarSize.lg => 88,
      };

  double get _fontSize => switch (size) {
        UserAvatarSize.sm => 16,
        UserAvatarSize.md => 18,
        UserAvatarSize.lg => 32,
      };

  double get _radius => switch (size) {
        UserAvatarSize.sm => 14,
        UserAvatarSize.md => 16,
        UserAvatarSize.lg => 44,
      };

  String get _initials {
    final first = _user?.firstName ?? _firstName ?? '';
    final last = _user?.lastName ?? _lastName ?? '';
    final f = first.isNotEmpty ? first[0] : '';
    final l = last.isNotEmpty ? last[0] : '';
    final combined = '$f$l'.toUpperCase();
    return combined.isEmpty ? '?' : combined;
  }

  ImageProvider? _imageProvider() {
    final bytes = imageBytes;
    if (bytes != null && bytes.isNotEmpty) return MemoryImage(bytes);
    final uri = apiAssetUri(imageUrl);
    if (uri == null) return null;
    return offlineNetworkImage(uri.toString());
  }

  @override
  Widget build(BuildContext context) {
    final dimension = _dimension;
    final provider = _imageProvider();

    if (provider != null) {
      final px = (dimension * MediaQuery.devicePixelRatioOf(context))
          .round()
          .clamp(32, 512);
      return ClipRRect(
        borderRadius: BorderRadius.circular(_radius),
        child: Image(
          image: ResizeImage.resizeIfNeeded(px, null, provider),
          width: dimension,
          height: dimension,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          frameBuilder: (_, child, frame, wasSynchronouslyLoaded) {
            // Inicjały do czasu wczytania zdjęcia (np. pierwszy raz z sieci).
            if (wasSynchronouslyLoaded || frame != null) return child;
            return _buildFallback(dimension);
          },
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
