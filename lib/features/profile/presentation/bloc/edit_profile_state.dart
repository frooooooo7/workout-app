import 'dart:typed_data';

import '../../domain/models/user_profile.dart';
import '../utils/profile_details_draft.dart';

const kProfileNameMaxLength = 50;
const kProfileBioMaxLength = 120;
const kProfileAvatarMaxBytes = 5 * 1024 * 1024;

class EditProfileState {
  const EditProfileState({
    this.initial,
    this.loading = false,
    this.loadError,
    this.firstName = '',
    this.lastName = '',
    this.handle = '',
    this.bio = '',
    this.avatarBytes,
    this.avatarFilename,
    this.removeAvatar = false,
    this.saving = false,
    this.error,
    this.saved,
  });

  factory EditProfileState.fromProfile(UserProfile profile) {
    return EditProfileState(
      initial: profile,
      firstName: profile.firstName,
      lastName: profile.lastName,
      handle: profile.handle,
      bio: profile.bio ?? '',
    );
  }

  /// Profil zapisany na serwerze — punkt odniesienia dla „czy są zmiany”.
  final UserProfile? initial;
  final bool loading;
  final String? loadError;

  final String firstName;
  final String lastName;
  final String handle;
  final String bio;

  /// Nowo wybrane zdjęcie (jeszcze niewysłane).
  final Uint8List? avatarBytes;
  final String? avatarFilename;

  /// Użytkownik chce usunąć obecne zdjęcie.
  final bool removeAvatar;

  final bool saving;
  final String? error;

  /// Ustawiane po udanym zapisie — ekran się zamyka.
  final UserProfile? saved;

  String? get firstNameError =>
      _nameError(firstName, empty: 'Podaj imię.', tooLong: 'Imię');

  String? get lastNameError =>
      _nameError(lastName, empty: 'Podaj nazwisko.', tooLong: 'Nazwisko');

  /// Tylko zmieniony nick — stare, generowane nicki bywają dłuższe niż
  /// obecny limit i nie mogą blokować zapisu innych pól.
  String? get handleError => handleChanged ? handleInputError(handle) : null;

  String? get bioError => bio.trim().length > kProfileBioMaxLength
      ? 'Opis może mieć maksymalnie $kProfileBioMaxLength znaków.'
      : null;

  bool get isValid =>
      firstNameError == null &&
      lastNameError == null &&
      handleError == null &&
      bioError == null;

  bool get firstNameChanged =>
      initial != null && firstName.trim() != initial!.firstName;

  bool get lastNameChanged =>
      initial != null && lastName.trim() != initial!.lastName;

  bool get handleChanged =>
      initial != null && normalizeHandle(handle) != initial!.handle;

  bool get bioChanged => initial != null && bio.trim() != (initial!.bio ?? '');

  bool get hasFieldChanges =>
      firstNameChanged || lastNameChanged || handleChanged || bioChanged;

  bool get hasAvatarChange =>
      initial != null &&
      (avatarBytes != null || (removeAvatar && initial!.avatarUrl != null));

  bool get hasChanges => hasFieldChanges || hasAvatarChange;

  bool get canSave => initial != null && !saving && hasChanges && isValid;

  /// Czy podgląd pokazuje jakieś zdjęcie (nowe albo obecne).
  bool get hasAvatar =>
      avatarBytes != null || (!removeAvatar && initial?.avatarUrl != null);

  static String? _nameError(
    String value, {
    required String empty,
    required String tooLong,
  }) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return empty;
    if (trimmed.length > kProfileNameMaxLength) {
      return '$tooLong może mieć maksymalnie $kProfileNameMaxLength znaków.';
    }
    return null;
  }

  EditProfileState copyWith({
    UserProfile? initial,
    bool? loading,
    String? loadError,
    bool clearLoadError = false,
    String? firstName,
    String? lastName,
    String? handle,
    String? bio,
    Uint8List? avatarBytes,
    String? avatarFilename,
    bool clearAvatarBytes = false,
    bool? removeAvatar,
    bool? saving,
    String? error,
    bool clearError = false,
    UserProfile? saved,
  }) {
    return EditProfileState(
      initial: initial ?? this.initial,
      loading: loading ?? this.loading,
      loadError: clearLoadError ? null : (loadError ?? this.loadError),
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      handle: handle ?? this.handle,
      bio: bio ?? this.bio,
      avatarBytes: clearAvatarBytes ? null : (avatarBytes ?? this.avatarBytes),
      avatarFilename:
          clearAvatarBytes ? null : (avatarFilename ?? this.avatarFilename),
      removeAvatar: removeAvatar ?? this.removeAvatar,
      saving: saving ?? this.saving,
      error: clearError ? null : (error ?? this.error),
      saved: saved ?? this.saved,
    );
  }
}
