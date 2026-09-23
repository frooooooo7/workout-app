import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../profile/presentation/bloc/edit_profile_state.dart';
import '../../../profile/presentation/widgets/avatar_picker_field.dart';
import '../../../profile/presentation/widgets/profile_details_fields.dart';
import '../bloc/onboarding_cubit.dart';
import '../bloc/onboarding_state.dart';
import 'onboarding_step_parts.dart';

const onboardingHandleFieldKey = Key('onboarding-handle');
const onboardingBioFieldKey = Key('onboarding-bio');

/// Krok 1: zdjęcie, nick i bio — to, co widzą inni.
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
    final profile = state.profile!;
    final enabled = !state.saving;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const OnboardingStepHeader(
          title: 'Twój profil',
          subtitle: 'Krok 1 z 3 — tak zobaczą Cię inni.',
        ),
        const SizedBox(height: 24),
        AvatarPickerField(
          firstName: profile.firstName,
          lastName: profile.lastName,
          imageUrl: profile.avatarUrl,
          imageBytes: state.avatarBytes,
          enabled: enabled,
          onPick: widget.onPickAvatar,
          onRemove: state.avatarBytes != null ? cubit.avatarCleared : null,
        ),
        const SizedBox(height: 16),
        const ProfileFieldLabel(label: 'Nick'),
        const SizedBox(height: 8),
        TextField(
          key: onboardingHandleFieldKey,
          controller: _handleController,
          enabled: enabled,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.next,
          onChanged: cubit.handleChanged,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            prefixText: '@',
            prefixStyle: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 15,
            ),
            errorText: state.handleError,
            errorMaxLines: 2,
            helperText: 'Po nicku znajomi znajdą Cię w wyszukiwarce.',
            helperStyle: const TextStyle(color: AppColors.textMuted),
          ),
        ),
        const SizedBox(height: 16),
        const ProfileFieldLabel(label: 'Bio'),
        const SizedBox(height: 8),
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
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Np. Trening 4× w tygodniu · siła i wytrzymałość',
            errorText: state.bioError,
            counterStyle: const TextStyle(color: AppColors.textMuted),
          ),
        ),
        const SizedBox(height: 16),
        OnboardingStepActions(
          nextLabel: 'Dalej',
          onNext: state.canContinue ? cubit.next : null,
          onSkip: enabled ? cubit.skip : null,
          saving: state.saving,
          error: state.error,
        ),
      ],
    );
  }
}
