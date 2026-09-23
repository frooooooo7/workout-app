import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../feed/presentation/widgets/post_author_row.dart';
import '../../../profile/presentation/bloc/edit_profile_state.dart';
import '../../../profile/presentation/utils/profile_details_draft.dart';
import '../../../profile/presentation/widgets/profile_details_fields.dart';
import '../bloc/onboarding_cubit.dart';
import '../bloc/onboarding_state.dart';
import 'onboarding_step_parts.dart';

const onboardingHandleFieldKey = Key('onboarding-handle');
const onboardingBioFieldKey = Key('onboarding-bio');
const onboardingAvatarKey = Key('onboarding-avatar');

/// Krok 1: zdjęcie, nick i bio — z podglądem profilu, który zmienia się
/// w trakcie pisania.
class OnboardingStepProfile extends StatefulWidget {
  const OnboardingStepProfile({
    super.key,
    required this.state,
    required this.onPickAvatar,
  });

  final OnboardingState state;
  final VoidCallback onPickAvatar;

  @override
  State<OnboardingStepProfile> createState() => _OnboardingStepProfileState();
}

class _OnboardingStepProfileState extends State<OnboardingStepProfile> {
  late final _handleController = TextEditingController(
    text: widget.state.handle,
  );
  late final _bioController = TextEditingController(text: widget.state.bio);

  @override
  void dispose() {
    _handleController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OnboardingCubit>();
    final state = widget.state;
    final enabled = !state.saving;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        kOnboardingGutter,
        AppSpacing.sm,
        kOnboardingGutter,
        kOnboardingBottomSpace,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const OnboardingStepHeader(
            title: 'Twój profil',
            subtitle: 'Tak zobaczą Cię obserwujący. Wszystko zmienisz później.',
          ),
          const SizedBox(height: AppSpacing.xxl),
          _ProfilePreview(
            state: state,
            enabled: enabled,
            onPickAvatar: widget.onPickAvatar,
            onRemovePicked: cubit.avatarCleared,
          ),
          const SizedBox(height: AppSpacing.xxl),
          const ProfileFieldLabel(label: 'Nick'),
          const SizedBox(height: 10),
          TextField(
            key: onboardingHandleFieldKey,
            controller: _handleController,
            enabled: enabled,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.next,
            onChanged: cubit.handleChanged,
            style: _inputStyle,
            decoration: onboardingInputDecoration(
              prefixText: '@',
              helperText: '3–30 znaków: małe litery, cyfry, kropka i _',
              errorText: state.handleError,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const ProfileFieldLabel(label: 'O sobie'),
          const SizedBox(height: 10),
          TextField(
            key: onboardingBioFieldKey,
            controller: _bioController,
            enabled: enabled,
            minLines: 2,
            maxLines: 4,
            maxLength: kProfileBioMaxLength,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            textCapitalization: TextCapitalization.sentences,
            onChanged: cubit.bioChanged,
            style: _inputStyle,
            decoration: onboardingInputDecoration(
              hintText: 'Np. Trening 4× w tygodniu · siła i wytrzymałość',
              errorText: state.bioError,
            ),
          ),
        ],
      ),
    );
  }
}

const _inputStyle = TextStyle(color: AppColors.textPrimary, fontSize: 16);

/// Styl pól tekstowych onboardingu — jak kafelki obok (surface, r16).
InputDecoration onboardingInputDecoration({
  String? hintText,
  String? prefixText,
  String? helperText,
  String? errorText,
}) {
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: BorderSide(color: color, width: width),
      );

  return InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 15),
    prefixText: prefixText,
    prefixStyle: const TextStyle(
      color: AppColors.textSecondary,
      fontSize: 16,
      fontWeight: FontWeight.w600,
    ),
    helperText: helperText,
    helperStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
    helperMaxLines: 2,
    errorText: errorText,
    errorMaxLines: 2,
    counterStyle: const TextStyle(color: AppColors.textSecondary),
    filled: true,
    fillColor: AppColors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: border(AppColors.border),
    enabledBorder: border(AppColors.border),
    disabledBorder: border(AppColors.border),
    focusedBorder: border(AppColors.primary, 1.5),
    errorBorder: border(AppColors.strengthWeak),
    focusedErrorBorder: border(AppColors.strengthWeak, 1.5),
  );
}

class _ProfilePreview extends StatelessWidget {
  const _ProfilePreview({
    required this.state,
    required this.enabled,
    required this.onPickAvatar,
    required this.onRemovePicked,
  });

  final OnboardingState state;
  final bool enabled;
  final VoidCallback onPickAvatar;
  final VoidCallback onRemovePicked;

  @override
  Widget build(BuildContext context) {
    final profile = state.profile!;
    final handle = normalizeHandle(state.handle);
    final bio = state.bio.trim();
    final hasPhoto = state.avatarBytes != null || profile.avatarUrl != null;

    return Column(
      children: [
        Semantics(
          button: true,
          label: hasPhoto
              ? 'Zmień zdjęcie profilowe'
              : 'Dodaj zdjęcie profilowe',
          excludeSemantics: true,
          child: AppPressable(
            key: onboardingAvatarKey,
            onTap: enabled ? onPickAvatar : null,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                GradientAvatarRing(
                  radius: 46,
                  child: UserAvatar.fromNames(
                    firstName: profile.firstName,
                    lastName: profile.lastName,
                    imageUrl: profile.avatarUrl,
                    imageBytes: state.avatarBytes,
                    size: UserAvatarSize.lg,
                  ),
                ),
                Positioned(
                  right: -6,
                  bottom: -6,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.background, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.45),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      hasPhoto
                          ? Icons.photo_camera_outlined
                          : Icons.add_a_photo_outlined,
                      color: AppColors.onPrimary,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          profile.fullName,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            height: 1.2,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          handle.isEmpty ? '@' : '@$handle',
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: bio.isEmpty
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    bio,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                ),
        ),
        if (state.avatarBytes != null)
          TextButton(
            onPressed: enabled ? onRemovePicked : null,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              minimumSize: const Size(0, AppSpacing.minTapTarget),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: const Text('Usuń wybrane zdjęcie'),
          ),
      ],
    );
  }
}
