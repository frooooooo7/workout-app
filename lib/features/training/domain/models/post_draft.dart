import 'dart:typed_data';

/// Najdłuższy tytuł posta (jak na serwerze — w znakach Unicode).
const postTitleMaxLength = 80;

/// Najdłuższy opis posta w arkuszu udostępniania. Opis to notatka treningu,
/// która na serwerze może mieć do 2000 znaków — post celowo jest krótszy.
const postBodyMaxLength = 500;

/// Zdjęcie wybrane do posta, jeszcze niewysłane.
class PickedPostPhoto {
  const PickedPostPhoto({required this.bytes, required this.filename});

  final Uint8List bytes;
  final String filename;
}

/// Co zrobić ze zdjęciem posta przy zapisie.
sealed class PostPhotoChange {
  const PostPhotoChange();
}

/// Zostaw obecne zdjęcie (albo jego brak).
class KeepPostPhoto extends PostPhotoChange {
  const KeepPostPhoto();
}

/// Ustaw nowe zdjęcie.
class SetPostPhoto extends PostPhotoChange {
  const SetPostPhoto(this.photo);

  final PickedPostPhoto photo;
}

/// Usuń zdjęcie.
class RemovePostPhoto extends PostPhotoChange {
  const RemovePostPhoto();
}

/// Treść posta z arkusza „Udostępnij trening”. Puste pola znaczą „brak”
/// (tytuł → nazwa treningu, opis → bez opisu).
class PostDraft {
  const PostDraft({this.title, this.body, this.photo = const KeepPostPhoto()});

  final String? title;
  final String? body;
  final PostPhotoChange photo;

  static String? _clean(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  String? get cleanTitle => _clean(title);
  String? get cleanBody => _clean(body);
}
