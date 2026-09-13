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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: _isShared ? 0.16 : 0.14),
            AppColors.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accent.withValues(alpha: _isShared ? 0.5 : 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: _isShared ? 0.16 : 0.10),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(user: user, accent: accent, shared: _isShared),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: Text(
                        _isShared
                            ? 'Udostępniono na profilu'
                            : 'Udostępnij na profilu',
                        key: ValueKey(_isShared),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isShared
                          ? 'Trening jest widoczny w Twojej aktywności. '
                                'Obserwujący zobaczą go na Twoim profilu.'
                          : 'Pokaż ten trening w aktywności na swoim profilu. '
                                'Zobaczą go osoby, które Cię obserwują.',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: _isShared
                ? _SharedActions(
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
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: FilledButton.icon(
          onPressed: saving ? null : onTap,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.ios_share_rounded, size: 19),
          label: Text(
            saving ? 'Udostępnianie…' : 'Udostępnij na profilu',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _SharedActions extends StatelessWidget {
  const _SharedActions({super.key, required this.onUnshare});

  final VoidCallback onUnshare;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.35),
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 18,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Widoczny na profilu',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.success,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Semantics(
          button: true,
          label: 'Cofnij udostępnienie treningu',
          child: TextButton(
            onPressed: onUnshare,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Cofnij',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}
