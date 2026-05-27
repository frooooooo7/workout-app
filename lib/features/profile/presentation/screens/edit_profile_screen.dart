import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../auth/domain/models/auth_models.dart';
import '../../../../core/services/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../domain/models/profile_update_input.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../utils/profile_form_utils.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    required this.repository,
    required this.user,
    this.initialProfile,
  });

  final ProfileRepository repository;
  final AuthUser user;
  final UserProfile? initialProfile;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _handleController = TextEditingController();
  final _bioController = TextEditingController();

  UserProfile? _profile;
  Uint8List? _pickedAvatarBytes;
  String? _pickedAvatarFilename;
  bool _loading = true;
  bool _saving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final profile =
          widget.initialProfile ?? await widget.repository.getOwnProfile();
      if (!mounted) return;
      _applyProfile(profile);
      setState(() {
        _profile = profile;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorText = profileErrorMessage(error);
      });
    }
  }

  void _applyProfile(UserProfile profile) {
    _firstNameController.text = profile.firstName;
    _lastNameController.text = profile.lastName;
    _handleController.text = profile.handle;
    _bioController.text = profile.bio ?? '';
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _handleController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _handlePickAvatar() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (file == null || !mounted) return;

    final bytes = await file.readAsBytes();
    if (bytes.lengthInBytes > 5 * 1024 * 1024) {
      setState(() {
        _errorText = 'Wybrany plik jest za duży. Maksymalny rozmiar to 5 MB.';
      });
      return;
    }

    setState(() {
      _pickedAvatarBytes = bytes;
      _pickedAvatarFilename = file.name;
      _errorText = null;
    });
  }

  String? _validateForm() {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final handle = normalizeProfileHandle(_handleController.text);
    final bio = _bioController.text.trim();

    if (firstName.isEmpty) return 'Imię jest wymagane.';
    if (firstName.length > 50) return 'Imię może mieć maksymalnie 50 znaków.';
    if (lastName.isEmpty) return 'Nazwisko jest wymagane.';
    if (lastName.length > 50) {
      return 'Nazwisko może mieć maksymalnie 50 znaków.';
    }
    if (!isValidProfileHandle(handle)) {
      return 'Nazwa użytkownika: min. 3 znaki, tylko małe litery, cyfry, kropka i podkreślnik.';
    }
    if (bio.length > 120) return 'Opis może mieć maksymalnie 120 znaków.';
    return null;
  }

  void _syncAuthUser(UserProfile profile) {
    final current = ServiceLocator.currentUser.value;
    if (current == null || current.id != profile.id) return;
    ServiceLocator.currentUser.value = AuthUser(
      id: current.id,
      email: current.email,
      firstName: profile.firstName,
      lastName: profile.lastName,
    );
  }

  Future<void> _handleSave() async {
    final validationError = _validateForm();
    if (validationError != null) {
      setState(() => _errorText = validationError);
      return;
    }

    final profile = _profile;
    if (profile == null) return;

    setState(() {
      _saving = true;
      _errorText = null;
    });

    // TODO: Zwróć uwagę na potencjalny race condition: aktualizacja profilu i upload avatara
    // to 2 oddzielne żądania HTTP. Jeśli jedno się powiedzie, a drugie nie, profil będzie w stanie
    // częściowo zaktualizowanym. Na tym etapie jest to akceptowalny kompromis.
    try {
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      final handle = normalizeProfileHandle(_handleController.text);
      final bio = _bioController.text.trim();

      final input = ProfileUpdateInput(
        firstName: firstName != profile.firstName ? firstName : null,
        lastName: lastName != profile.lastName ? lastName : null,
        handle: handle != profile.handle ? handle : null,
        bio: bio != (profile.bio ?? '') ? bio : null,
      );

      var updated = profile;
      if (input.toJson().isNotEmpty) {
        updated = await widget.repository.updateProfile(input);
      }

      if (_pickedAvatarBytes != null) {
        updated = await widget.repository.uploadAvatar(
          _pickedAvatarBytes!,
          _pickedAvatarFilename ?? 'avatar.jpg',
        );
      }

      _syncAuthUser(updated);
      ServiceLocator.requestProfileRefresh();

      if (!mounted) return;
      context.pop(updated);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorText = profileErrorMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('EDYTUJ PROFIL'),
        actions: [
          TextButton(
            onPressed: _saving || _loading ? null : _handleSave,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Zapisz',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Stack(
                        children: [
                          _pickedAvatarBytes != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(UserAvatarSize.lg.radius),
                                  child: Image.memory(
                                    _pickedAvatarBytes!,
                                    width: UserAvatarSize.lg.dimension,
                                    height: UserAvatarSize.lg.dimension,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : UserAvatar.fromNames(
                                  firstName: _firstNameController.text,
                                  lastName: _lastNameController.text,
                                  imageUrl: _profile?.avatarUrl,
                                  size: UserAvatarSize.lg,
                                ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Material(
                              color: AppColors.primary,
                              shape: const CircleBorder(),
                              child: InkWell(
                                onTap: _saving ? null : _handlePickAvatar,
                                customBorder: const CircleBorder(),
                                child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(
                                    Icons.camera_alt_outlined,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: TextButton(
                        onPressed: _saving ? null : _handlePickAvatar,
                        child: const Text('Zmień zdjęcie'),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _FieldLabel(label: 'Imię'),
                    const SizedBox(height: 8),
                    _ProfileTextField(
                      controller: _firstNameController,
                      textCapitalization: TextCapitalization.words,
                      enabled: !_saving,
                    ),
                    const SizedBox(height: 16),
                    _FieldLabel(label: 'Nazwisko'),
                    const SizedBox(height: 8),
                    _ProfileTextField(
                      controller: _lastNameController,
                      textCapitalization: TextCapitalization.words,
                      enabled: !_saving,
                    ),
                    const SizedBox(height: 16),
                    _FieldLabel(label: 'Nazwa użytkownika'),
                    const SizedBox(height: 8),
                    _ProfileTextField(
                      controller: _handleController,
                      prefixText: '@',
                      enabled: !_saving,
                    ),
                    const SizedBox(height: 16),
                    _FieldLabel(label: 'Opis profilu'),
                    const SizedBox(height: 8),
                    _ProfileTextField(
                      controller: _bioController,
                      maxLines: 3,
                      minLines: 2,
                      maxLength: 120,
                      textCapitalization: TextCapitalization.sentences,
                      enabled: !_saving,
                    ),
                    const SizedBox(height: 16),
                    _FieldLabel(label: 'Adres e-mail'),
                    const SizedBox(height: 8),
                    _ProfileTextField(
                      initialValue: widget.user.email,
                      readOnly: true,
                    ),
                    if (_errorText != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _errorText!,
                        style: const TextStyle(
                          color: AppColors.strengthWeak,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
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
        letterSpacing: 1.2,
      ),
    );
  }
}

class _ProfileTextField extends StatelessWidget {
  const _ProfileTextField({
    this.controller,
    this.initialValue,
    this.prefixText,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.textCapitalization = TextCapitalization.none,
    this.readOnly = false,
    this.enabled = true,
  }) : assert(
          controller != null || initialValue != null,
          'Provide controller or initialValue',
        );

  final TextEditingController? controller;
  final String? initialValue;
  final String? prefixText;
  final int maxLines;
  final int? minLines;
  final int? maxLength;
  final TextCapitalization textCapitalization;
  final bool readOnly;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      initialValue: controller == null ? initialValue : null,
      readOnly: readOnly,
      enabled: enabled,
      maxLines: maxLines,
      minLines: minLines,
      maxLength: maxLength,
      textCapitalization: textCapitalization,
      style: TextStyle(
        color: readOnly ? AppColors.textSecondary : AppColors.textPrimary,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        prefixText: prefixText,
        filled: true,
        fillColor: AppColors.surface,
        counterStyle: const TextStyle(color: AppColors.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }
}
