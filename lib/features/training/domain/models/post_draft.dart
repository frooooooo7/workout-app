import 'dart:typed_data';

/// Najdłuższy tytuł posta. Serwer liczy punkty kodowe Unicode (Postgres
/// `char_length`), więc aplikacja liczy tak samo — patrz [postTitleLength].
const postTitleMaxLength = 80;

/// Najdłuższy opis posta. Opis to notatka treningu, którą serwer przyjmuje
/// do 2000 jednostek UTF-16 (`string.length` w zod) — patrz [postBodyLength].
/// Ten sam limit co notatka, żeby arkusz nigdy nie uciął dłuższej notatki.
const postBodyMaxLength = 2000;

/// Długość tytułu tak, jak liczy ją serwer (punkty kodowe).
int postTitleLength(String text) => text.runes.length;

/// Długość opisu tak, jak liczy ją serwer (jednostki UTF-16).
int postBodyLength(String text) => text.length;

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
