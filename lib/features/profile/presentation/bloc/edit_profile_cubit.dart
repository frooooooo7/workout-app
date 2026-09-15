import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import 'edit_profile_state.dart';

class EditProfileCubit extends Cubit<EditProfileState> {
  EditProfileCubit(
    this._repository, {
    UserProfile? initialProfile,
    this.onNamesChanged,
  }) : super(
         initialProfile == null
             ? const EditProfileState(loading: true)
             : EditProfileState.fromProfile(initialProfile),
       );

  final ProfileRepository _repository;

  /// Po zmianie imienia/nazwiska — np. aktualizacja zapamiętanego
  /// użytkownika sesji. Błąd tutaj nie psuje zapisu profilu.
  final Future<void> Function(UserProfile profile)? onNamesChanged;

  /// Wczytuje profil, gdy ekran otwarto bez gotowych danych.
  Future<void> load() async {
    if (state.initial != null) return;
    emit(state.copyWith(loading: true, clearLoadError: true));
    try {
      final profile = await _repository.getOwnProfile();
      if (isClosed) return;
      emit(EditProfileState.fromProfile(profile));
    } catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          loading: false,
          loadError: error is ApiException && error.statusCode == null
              ? 'Brak połączenia z internetem. Spróbuj ponownie.'
              : 'Nie udało się wczytać profilu. Spróbuj ponownie.',
        ),
      );
    }
  }

  void firstNameChanged(String value) =>
      emit(state.copyWith(firstName: value, clearError: true));

  void lastNameChanged(String value) =>
      emit(state.copyWith(lastName: value, clearError: true));

  void bioChanged(String value) =>
      emit(state.copyWith(bio: value, clearError: true));

  void avatarPicked(Uint8List bytes, String filename) {
    if (bytes.lengthInBytes > kProfileAvatarMaxBytes) {
      emit(
        state.copyWith(
          error: 'Zdjęcie jest za duże — maksymalnie 5 MB.',
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        avatarBytes: bytes,
        avatarFilename: filename,
        removeAvatar: false,
        clearError: true,
      ),
    );
  }

  void avatarRemoved() {
    emit(
      state.copyWith(
        clearAvatarBytes: true,
        removeAvatar: true,
        clearError: true,
      ),
    );
  }

  Future<void> save() async {
    final snapshot = state;
    final initial = snapshot.initial;
    if (!snapshot.canSave || initial == null) return;

    emit(snapshot.copyWith(saving: true, clearError: true));

    var latest = initial;
    try {
      if (snapshot.hasFieldChanges) {
        latest = await _repository.updateProfile(
          firstName: snapshot.firstNameChanged
              ? snapshot.firstName.trim()
              : null,
          lastName: snapshot.lastNameChanged ? snapshot.lastName.trim() : null,
          bio: snapshot.bioChanged ? snapshot.bio.trim() : null,
        );
        if (snapshot.firstNameChanged || snapshot.lastNameChanged) {
          await _notifyNamesChanged(latest);
        }
        if (isClosed) return;
        // Dane są już na serwerze — ewentualna ponowna próba wyśle tylko
        // zdjęcie.
        emit(state.copyWith(initial: latest));
      }

      if (snapshot.avatarBytes != null) {
        latest = await _repository.uploadAvatar(
          snapshot.avatarBytes!,
          snapshot.avatarFilename ?? 'avatar.jpg',
        );
      } else if (snapshot.removeAvatar && initial.avatarUrl != null) {
        latest = await _repository.removeAvatar();
      }

      if (isClosed) return;
      emit(
        state.copyWith(
          initial: latest,
          saving: false,
          clearAvatarBytes: true,
          removeAvatar: false,
          saved: latest,
        ),
      );
    } catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          initial: latest,
          saving: false,
          error: editProfileErrorMessage(error),
        ),
      );
    }
  }

  Future<void> _notifyNamesChanged(UserProfile profile) async {
    final callback = onNamesChanged;
    if (callback == null) return;
    try {
      await callback(profile);
    } catch (_) {
      /* lokalny cache sesji jest pomocniczy */
    }
  }

  static String editProfileErrorMessage(Object error) {
    if (error is ApiException) {
      if (error.statusCode == null) {
        return 'Nie udało się zapisać — brak połączenia z internetem.';
      }
      switch (error.message) {
        case 'invalid_first_name':
          return 'Imię musi mieć od 1 do $kProfileNameMaxLength znaków.';
        case 'invalid_last_name':
          return 'Nazwisko musi mieć od 1 do $kProfileNameMaxLength znaków.';
        case 'bio_too_long':
          return 'Opis może mieć maksymalnie $kProfileBioMaxLength znaków.';
        case 'no_fields_to_update':
          return 'Brak zmian do zapisania.';
        case 'invalid_file':
          return 'Nieprawidłowy plik (JPG/PNG/WEBP, maks. 5 MB).';
        case 'missing_image':
          return 'Nie wybrano zdjęcia.';
      }
      if (error.statusCode == 413) {
        return 'Zdjęcie jest za duże — maksymalnie 5 MB.';
      }
      if (error.statusCode == 429) {
        return 'Zbyt wiele prób. Spróbuj za chwilę.';
      }
    }
    return 'Nie udało się zapisać profilu. Spróbuj ponownie.';
  }
}
