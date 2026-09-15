import '../../../../core/network/api_client.dart';

/// Jednorazowy komunikat dla SnackBara. [id] rośnie z każdym komunikatem,
/// więc dwa identyczne błędy z rzędu pokażą się dwa razy.
class FeedNotice {
  const FeedNotice({required this.id, required this.message});

  final int id;
  final String message;
}

/// Maksymalna długość komentarza — w punktach kodowych, jak na serwerze.
const int kMaxCommentLength = 500;

int commentLength(String body) => body.runes.length;

bool isNetworkError(Object error) =>
    error is ApiException && error.statusCode == null;

bool isNotFoundError(Object error) =>
    error is ApiException &&
    (error.statusCode == 404 ||
        error.message == 'post_not_found' ||
        error.message == 'invalid_uuid');

String feedLoadErrorMessage(Object error) {
  if (isNetworkError(error)) {
    return 'Brak połączenia z internetem. Sprawdź sieć i spróbuj ponownie.';
  }
  return 'Nie udało się wczytać feedu.';
}

String feedStaleMessage(Object error) {
  if (isNetworkError(error)) {
    return 'Brak połączenia — pokazuję zapisany feed';
  }
  return 'Nie udało się odświeżyć — pokazuję zapisany feed';
}

String postLoadErrorMessage(Object error) {
  if (isNetworkError(error)) {
    return 'Brak połączenia z internetem. Szczegóły treningu wymagają sieci.';
  }
  return 'Nie udało się wczytać treningu.';
}

String kudosErrorMessage(Object error, {required bool removing}) {
  final action = removing ? 'cofnąć kudosa' : 'dać kudosa';
  if (error is ApiException) {
    if (error.statusCode == null) {
      return 'Nie udało się $action — brak połączenia z internetem.';
    }
    if (error.statusCode == 429) {
      return 'Nie udało się $action — zbyt wiele prób. Spróbuj za chwilę.';
    }
    switch (error.message) {
      case 'cannot_kudo_own_post':
        return 'Nie możesz dać kudosa własnemu treningowi.';
      case 'post_not_found':
        return 'Ten trening nie jest już dostępny.';
    }
  }
  return 'Nie udało się $action. Spróbuj ponownie.';
}

String commentsLoadErrorMessage(Object error) {
  if (isNetworkError(error)) {
    return 'Brak połączenia — nie można wczytać komentarzy.';
  }
  return 'Nie udało się wczytać komentarzy.';
}

String addCommentErrorMessage(Object error) {
  if (error is ApiException) {
    if (error.statusCode == null) {
      return 'Nie udało się dodać komentarza — brak połączenia z internetem.';
    }
    if (error.statusCode == 429 || error.message == 'too_many_requests') {
      return 'Dodajesz komentarze zbyt szybko. Spróbuj za chwilę.';
    }
    switch (error.message) {
      case 'invalid_comment_body':
        return 'Komentarz musi mieć od 1 do $kMaxCommentLength znaków.';
      case 'post_not_found':
        return 'Ten trening nie jest już dostępny.';
    }
  }
  return 'Nie udało się dodać komentarza. Spróbuj ponownie.';
}

String deleteCommentErrorMessage(Object error) {
  if (error is ApiException) {
    if (error.statusCode == null) {
      return 'Nie udało się usunąć komentarza — brak połączenia z internetem.';
    }
    if (error.statusCode == 403 || error.message == 'forbidden') {
      return 'Nie możesz usunąć tego komentarza.';
    }
  }
  return 'Nie udało się usunąć komentarza. Spróbuj ponownie.';
}
