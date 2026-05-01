/// Maps API error codes returned by gym-backend to Polish user-facing messages.
String authErrorMessage(String error) => switch (error) {
      'missing_fields' => 'Uzupełnij wszystkie pola.',
      'invalid_email' => 'Podaj prawidłowy adres e-mail.',
      'email_taken' => 'Ten adres e-mail jest już zajęty.',
      'invalid_credentials' => 'Nieprawidłowy e-mail lub hasło.',
      'password_too_short' => 'Hasło musi mieć co najmniej 8 znaków.',
      'password_too_weak' =>
        'Hasło musi zawierać wielką literę i cyfrę.',
      'database_unavailable' =>
        'Serwer chwilowo niedostępny. Spróbuj później.',
      'network_error' => 'Brak połączenia z serwerem. Sprawdź sieć.',
      'too_many_requests' => 'Zbyt wiele prób. Spróbuj za chwilę.',
      _ => 'Wystąpił nieoczekiwany błąd. Spróbuj ponownie.',
    };
