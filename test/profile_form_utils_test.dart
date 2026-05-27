import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/network/api_client.dart';
import 'package:gym/features/profile/presentation/utils/profile_form_utils.dart';

void main() {
  group('normalizeProfileHandle', () {
    test('normalizes polish characters and invalid symbols', () {
      expect(normalizeProfileHandle('Jan.Kowalski'), 'jan.kowalski');
      expect(normalizeProfileHandle('Łukasz_12'), 'lukasz_12');
      expect(normalizeProfileHandle('  User@Name! '), 'username');
    });

    test('handles empty handle string gracefully', () {
      expect(normalizeProfileHandle(''), '');
      expect(normalizeProfileHandle('   '), '');
    });
  });

  group('isValidProfileHandle', () {
    test('accepts valid handles', () {
      expect(isValidProfileHandle('jan.kowalski'), isTrue);
      expect(isValidProfileHandle('user_123'), isTrue);
    });

    test('rejects too short or invalid handles', () {
      expect(isValidProfileHandle('ab'), isFalse);
      expect(isValidProfileHandle('bad handle'), isFalse);
    });

    test('validates boundary length conditions', () {
      final fiftyChars = 'a'.padRight(50, 'a');
      final fiftyOneChars = 'a'.padRight(51, 'a');

      // exactly 3 chars (valid)
      expect(isValidProfileHandle('abc'), isTrue);
      // exactly 50 chars (valid)
      expect(isValidProfileHandle(fiftyChars), isTrue);
      // 51 chars (invalid)
      expect(isValidProfileHandle(fiftyOneChars), isFalse);
    });
  });

  group('profileErrorMessage', () {
    test('maps api error codes to polish user-friendly messages', () {
      expect(profileErrorMessage(const ApiException('bio_too_long')), 'Opis może mieć maksymalnie 120 znaków.');
      expect(profileErrorMessage(const ApiException('first_name_required')), 'Imię jest wymagane.');
      expect(profileErrorMessage(const ApiException('first_name_too_long')), 'Imię może mieć maksymalnie 50 znaków.');
      expect(profileErrorMessage(const ApiException('last_name_required')), 'Nazwisko jest wymagane.');
      expect(profileErrorMessage(const ApiException('last_name_too_long')), 'Nazwisko może mieć maksymalnie 50 znaków.');
      expect(profileErrorMessage(const ApiException('handle_too_long')), 'Nazwa użytkownika może mieć maksymalnie 50 znaków.');
      expect(profileErrorMessage(const ApiException('handle_invalid')), 'Nazwa użytkownika: min. 3 znaki, tylko małe litery, cyfry, kropka i podkreślnik.');
      expect(profileErrorMessage(const ApiException('handle_taken')), 'Ta nazwa użytkownika jest już zajęta.');
      expect(profileErrorMessage(const ApiException('invalid_file')), 'Nieprawidłowy format zdjęcia. Dozwolone: JPG, PNG, WEBP.');
      expect(profileErrorMessage(const ApiException('missing_avatar')), 'Wybierz zdjęcie profilowe.');
      expect(profileErrorMessage(const ApiException('network_error')), 'Brak połączenia z serwerem.');
    });

    test('returns default error message for unknown error codes', () {
      expect(profileErrorMessage(const ApiException('unknown_api_error_code')), 'Nie udało się zapisać profilu.');
      expect(profileErrorMessage(Exception('generic exception')), 'Nie udało się zapisać profilu.');
      expect(profileErrorMessage('some string error'), 'Nie udało się zapisać profilu.');
    });
  });
}
