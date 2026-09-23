import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../bloc/edit_profile_cubit.dart';
import '../bloc/edit_profile_state.dart';
import '../widgets/avatar_picker_field.dart';

const editProfileFirstNameFieldKey = Key('edit-profile-first-name');
const editProfileLastNameFieldKey = Key('edit-profile-last-name');
const editProfileHandleFieldKey = Key('edit-profile-handle');
const editProfileBioFieldKey = Key('edit-profile-bio');
const editProfileSaveButtonKey = Key('edit-profile-save');

/// Edycja własnego profilu. Wymaga [EditProfileCubit] w kontekście; po
/// udanym zapisie zamyka się z zaktualizowanym `UserProfile`.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _handleController = TextEditingController();
  final _bioController = TextEditingController();
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<EditProfileCubit>();
    if (cubit.state.initial != null) {
      _seedControllers(cubit.state);
    } else {
      cubit.load();
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _handleController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _seedControllers(EditProfileState state) {
    _firstNameController.text = state.firstName;
    _lastNameController.text = state.lastName;
    _handleController.text = state.handle;
    _bioController.text = state.bio;
    _seeded = true;
  }

  Future<void> _pickAvatar() async {
    final cubit = context.read<EditProfileCubit>();
    final picked = await pickAvatarImage(context);
    if (picked == null) return;
    cubit.avatarPicked(picked.bytes, picked.filename);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('EDYTUJ PROFIL')),
      body: BlocConsumer<EditProfileCubit, EditProfileState>(
        listenWhen: (previous, current) =>
            (!_seeded && current.initial != null) ||
            (previous.saved == null && current.saved != null),
        listener: (context, state) {
          if (state.saved != null) {
            Navigator.of(context).pop(state.saved);
            return;
          }
          _seedControllers(state);
        },
        builder: (context, state) {
          if (state.initial == null) {
            if (state.loadError != null) {
              return _LoadError(
                message: state.loadError!,
                onRetry: () => context.read<EditProfileCubit>().load(),
              );
            }
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          return _EditProfileForm(
            state: state,
            firstNameController: _firstNameController,
            lastNameController: _lastNameController,
            handleController: _handleController,
            bioController: _bioController,
            onPickAvatar: _pickAvatar,
          );
        },
      ),
    );
  }
}

class _EditProfileForm extends StatelessWidget {
  const _EditProfileForm({
    required this.state,
    required this.firstNameController,
    required this.lastNameController,
    required this.handleController,
    required this.bioController,
    required this.onPickAvatar,
  });

  final EditProfileState state;
  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final TextEditingController handleController;
  final TextEditingController bioController;
  final VoidCallback onPickAvatar;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EditProfileCubit>();
    final enabled = !state.saving;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AvatarPickerField(
              firstName: state.firstName,
              lastName: state.lastName,
              imageUrl: state.removeAvatar ? null : state.initial?.avatarUrl,
              imageBytes: state.avatarBytes,
              enabled: enabled,
              onPick: onPickAvatar,
              onRemove: cubit.avatarRemoved,
            ),
            const SizedBox(height: 20),
            const _FieldLabel(label: 'Imię'),
            const SizedBox(height: 8),
            _ProfileTextField(
              fieldKey: editProfileFirstNameFieldKey,
              controller: firstNameController,
              enabled: enabled,
              errorText: state.firstNameError,
              maxLength: kProfileNameMaxLength,
              showCounter: false,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              onChanged: cubit.firstNameChanged,
            ),
            const SizedBox(height: 16),
            const _FieldLabel(label: 'Nazwisko'),
            const SizedBox(height: 8),
            _ProfileTextField(
              fieldKey: editProfileLastNameFieldKey,
              controller: lastNameController,
              enabled: enabled,
              errorText: state.lastNameError,
              maxLength: kProfileNameMaxLength,
              showCounter: false,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              onChanged: cubit.lastNameChanged,
            ),
            const SizedBox(height: 16),
            const _FieldLabel(label: 'Nick'),
            const SizedBox(height: 8),
            _ProfileTextField(
              fieldKey: editProfileHandleFieldKey,
              controller: handleController,
              enabled: enabled,
              errorText: state.handleError,
              showCounter: false,
              prefixText: '@',
              textInputAction: TextInputAction.next,
              onChanged: cubit.handleChanged,
            ),
            const SizedBox(height: 16),
            const _FieldLabel(label: 'Bio'),
            const SizedBox(height: 8),
            _ProfileTextField(
              fieldKey: editProfileBioFieldKey,
              controller: bioController,
              enabled: enabled,
              errorText: state.bioError,
              maxLength: kProfileBioMaxLength,
              showCounter: true,
              minLines: 2,
              maxLines: 4,
              hintText: 'Np. Trening 4× w tygodniu · siła i wytrzymałość',
              textCapitalization: TextCapitalization.sentences,
              onChanged: cubit.bioChanged,
            ),
            if (state.error != null) ...[
              const SizedBox(height: 12),
              Text(
                state.error!,
                style: const TextStyle(
                  color: AppColors.strengthWeak,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              key: editProfileSaveButtonKey,
              onPressed: state.canSave ? cubit.save : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: state.saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.onPrimary,
                      ),
                    )
                  : const Text('Zapisz'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: AppColors.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      ),
    );
  }
}

class _ProfileTextField extends StatelessWidget {
  const _ProfileTextField({
    required this.fieldKey,
    required this.controller,
    required this.enabled,
    required this.errorText,
    required this.showCounter,
    required this.onChanged,
    this.maxLength,
    this.prefixText,
    this.minLines,
    this.maxLines = 1,
    this.hintText,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final bool enabled;
  final String? errorText;
  final int? maxLength;
  final String? prefixText;
  final bool showCounter;
  final ValueChanged<String> onChanged;
  final int? minLines;
  final int maxLines;
  final String? hintText;
  final TextCapitalization textCapitalization;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color),
        );

    return TextField(
      key: fieldKey,
      controller: controller,
      enabled: enabled,
      onChanged: onChanged,
      minLines: minLines,
      maxLines: maxLines,
      maxLength: maxLength,
      maxLengthEnforcement: MaxLengthEnforcement.enforced,
      textCapitalization: textCapitalization,
      textInputAction: textInputAction,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: AppColors.textMuted),
        prefixText: prefixText,
        prefixStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        errorMaxLines: 2,
        errorText: errorText,
        counterText: showCounter ? null : '',
        counterStyle: const TextStyle(color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.surface,
        border: border(AppColors.border),
        enabledBorder: border(AppColors.border),
        disabledBorder: border(AppColors.border),
        focusedBorder: border(AppColors.primary),
        errorBorder: border(AppColors.strengthWeak),
        focusedErrorBorder: border(AppColors.strengthWeak),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: AppColors.strengthWeak,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Spróbuj ponownie'),
            ),
          ],
        ),
      ),
    );
  }
}
