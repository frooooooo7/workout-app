import '../../../../core/network/api_client.dart' show ApiException;

String profileErrorMessage(Object error) {
  if (error is ApiException) {
    return switch (error.message) {
      'bio_too_long' => 'Opis może mieć maksymalnie 120 znaków.',
      'first_name_required' => 'Imię jest wymagane.',
      'first_name_too_long' => 'Imię może mieć maksymalnie 50 znaków.',
      'last_name_required' => 'Nazwisko jest wymagane.',
      'last_name_too_long' => 'Nazwisko może mieć maksymalnie 50 znaków.',
      'handle_too_long' => 'Nazwa użytkownika może mieć maksymalnie 50 znaków.',
      'handle_invalid' =>
        'Nazwa użytkownika: min. 3 znaki, tylko małe litery, cyfry, kropka i podkreślnik.',
      'handle_taken' => 'Ta nazwa użytkownika jest już zajęta.',
      'invalid_file' => 'Nieprawidłowy format zdjęcia. Dozwolone: JPG, PNG, WEBP.',
      'missing_avatar' => 'Wybierz zdjęcie profilowe.',
      'network_error' => 'Brak połączenia z serwerem.',
      _ => 'Nie udało się zapisać profilu.',
    };
  }
  return 'Nie udało się zapisać profilu.';
}

String normalizeProfileHandle(String raw) {
  const polishMap = {
    'ą': 'a',
    'ć': 'c',
    'ę': 'e',
    'ł': 'l',
    'ń': 'n',
    'ó': 'o',
    'ś': 's',
    'ź': 'z',
    'ż': 'z',
  };

  var normalized = raw.trim().toLowerCase();
  for (final entry in polishMap.entries) {
    normalized = normalized.replaceAll(entry.key, entry.value);
  }
  return normalized.replaceAll(RegExp(r'[^a-z0-9._]'), '');
}

bool isValidProfileHandle(String handle) {
  if (handle.length < 3 || handle.length > 50) return false;
  return RegExp(r'^[a-z0-9._]+$').hasMatch(handle);
}
