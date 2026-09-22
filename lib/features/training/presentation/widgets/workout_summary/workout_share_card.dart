import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/user_avatar.dart';
import '../../../../auth/domain/models/auth_models.dart';

/// Stan udostępnienia treningu na profil — steruje wyglądem [WorkoutShareCard].
enum WorkoutShareStatus { notShared, saving, shared }

/// Karta „Udostępnij na profilu": jedna decyzja, jeden przycisk.
///
/// Po udostępnieniu zmienia się w potwierdzenie z możliwością cofnięcia —
/// użytkownik nigdy nie traci kontroli nad tym, co widać na jego profilu.
class WorkoutShareCard extends StatelessWidget {
  const WorkoutShareCard({
    super.key,
    required this.status,
    required this.onShare,
    required this.onUnshare,
    this.user,
  });

  final WorkoutShareStatus status;
  final VoidCallback onShare;
  final VoidCallback onUnshare;
  final AuthUser? user;

  bool get _isShared => status == WorkoutShareStatus.shared;
  bool get _isSaving => status == WorkoutShareStatus.saving;

  @override
  Widget build(BuildContext context) {
    final accent = _isShared ? AppColors.success : AppColors.primaryVariant;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.withValues(alpha: 0.12), AppColors.surface],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accent.withValues(alpha: _isShared ? 0.45 : 0.3),
        ),
      ),
      child: Row(
        children: [
          _Avatar(user: user, accent: accent, shared: _isShared),
          const SizedBox(width: 12),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Column(
                key: ValueKey(_isShared),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isShared
                        ? 'Udostępniono na profilu'
                        : 'Udostępnij na profilu',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _isShared
                        ? 'Widoczny na profilu'
                        : 'Zobaczą go Twoi obserwujący',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _isShared
                          ? AppColors.success
                          : AppColors.textSecondary,
                      fontSize: 12.5,
                      fontWeight: _isShared ? FontWeight.w600 : FontWeight.w400,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: _isShared
                ? _UnshareButton(
                    key: const ValueKey('workout-share-shared-actions'),
                    onUnshare: onUnshare,
                  )
                : _ShareButton(
                    key: const ValueKey('workout-share-button'),
                    saving: _isSaving,
                    onTap: onShare,
                  ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.user,
    required this.accent,
    required this.shared,
  });

  final AuthUser? user;
  final Color accent;
  final bool shared;

  @override
  Widget build(BuildContext context) {
    final avatar = user == null
        ? Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: AppColors.textSecondary,
              size: 22,
            ),
          )
        : UserAvatar(user: user!, size: UserAvatarSize.sm);

    return SizedBox(
      width: 54,
      height: 54,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(left: 0, top: 0, child: avatar),
          Positioned(
            right: 0,
            bottom: 0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 2),
              ),
              child: Icon(
                shared ? Icons.check_rounded : Icons.ios_share_rounded,
                color: Colors.white,
                size: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  const _ShareButton({super.key, required this.saving, required this.onTap});

  final bool saving;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: !saving,
      label: 'Udostępnij trening na profilu',
      excludeSemantics: true,
      child: SizedBox(
        height: 40,
        child: FilledButton.icon(
          onPressed: saving ? null : onTap,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white,
            padding: const EdgeInsets.only(left: 12, right: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.ios_share_rounded, size: 17),
          label: const Text(
            'Udostępnij',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _UnshareButton extends StatelessWidget {
  const _UnshareButton({super.key, required this.onUnshare});

  final VoidCallback onUnshare;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Cofnij udostępnienie treningu',
      excludeSemantics: true,
      child: OutlinedButton(
        onPressed: onUnshare,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          side: BorderSide(color: AppColors.border.withValues(alpha: 0.9)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Cofnij',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
