import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/auth/domain/models/auth_models.dart';
import 'package:gym/features/profile/domain/models/profile_details.dart';
import 'package:gym/features/profile/presentation/utils/profile_details_draft.dart';
import 'package:gym/features/profile/presentation/utils/profile_details_labels.dart';
import 'package:gym/features/profile/presentation/widgets/profile_details_fields.dart';

void main() {
  final today = DateTime(2026, 9, 23);

  group('birthDateInputError', () {
    test('empty is fine (optional field)', () {
      expect(birthDateInputError('', today), isNull);
    });

    test('age boundaries 16–100', () {
      expect(birthDateInputError('23.09.2010', today), isNull);
      expect(
        birthDateInputError('24.09.2010', today),
        'Musisz mieć co najmniej 16 lat.',
      );
      expect(birthDateInputError('23.09.1926', today), isNull);
      expect(
        birthDateInputError('22.09.1925', today),
        'Sprawdź rok urodzenia.',
      );
    });

    test('incomplete or impossible dates', () {
      for (final text in ['12.03', '31.02.1999', '1999-03-12', '00.01.1999']) {
        expect(
          birthDateInputError(text, today),
          'Podaj datę w formacie DD.MM.RRRR.',
          reason: text,
        );
      }
    });
  });

  group('handleInputError / normalizeHandle', () {
    test('normalizes @, spaces and case', () {
      expect(normalizeHandle('  @Jan.Silny '), 'jan.silny');
    });

    test('messages', () {
      expect(handleInputError(''), 'Podaj nick.');
      expect(handleInputError('ab'), 'Nick musi mieć co najmniej 3 znaki.');
      expect(
        handleInputError('a' * 31),
        'Nick może mieć maksymalnie 30 znaków.',
      );
      expect(
        handleInputError('.jan'),
        'Nick musi zaczynać się literą lub cyfrą.',
      );
      expect(
        handleInputError('jan-k'),
        'Dozwolone: małe litery, cyfry, kropka i podkreślenie.',
      );
      expect(handleInputError('Jan_K.99'), isNull);
    });
  });

  group('ProfileDetailsDraft', () {
    test('parses height and weight (comma or dot, rounded to 0.1)', () {
      const draft = ProfileDetailsDraft(heightText: '182', weightText: '82,46');
      expect(draft.heightCm, 182);
      expect(draft.weightKg, 82.5);
      expect(draft.isBodyValid, isTrue);
      expect(
        const ProfileDetailsDraft(weightText: '82.4').weightKg,
        82.4,
      );
    });

    test('out of range values are errors, empty ones are not', () {
      const draft = ProfileDetailsDraft(heightText: '99', weightText: '301');
      expect(draft.heightError, 'Podaj wzrost w cm (100–250).');
      expect(draft.weightError, 'Podaj wagę w kg (30–300).');
      expect(draft.isBodyValid, isFalse);
      expect(const ProfileDetailsDraft().isBodyValid, isTrue);
    });

    test('round-trips saved details', () {
      final details = ProfileDetails(
        birthDate: DateTime(1998, 3, 5),
        gender: Gender.male,
        heightCm: 180,
        weightKg: 80,
        trainingGoal: TrainingGoal.muscle,
        experienceLevel: ExperienceLevel.beginner,
        weeklyTrainingDays: 3,
      );
      final draft = ProfileDetailsDraft.fromDetails(details);

      expect(draft.birthDateText, '05.03.1998');
      expect(draft.weightText, '80');
      expect(draft.toDetails(), details);
    });

    test('bodyOnto / goalOnto only replace their own step', () {
      const saved = ProfileDetails(
        heightCm: 170,
        trainingGoal: TrainingGoal.general,
        weeklyTrainingDays: 2,
      );
      const draft = ProfileDetailsDraft(
        heightText: '175',
        trainingGoal: TrainingGoal.strength,
      );

      expect(
        draft.bodyOnto(saved),
        const ProfileDetails(
          heightCm: 175,
          trainingGoal: TrainingGoal.general,
          weeklyTrainingDays: 2,
        ),
      );
      expect(
        draft.goalOnto(saved),
        const ProfileDetails(heightCm: 170, trainingGoal: TrainingGoal.strength),
      );
    });

    test('choices can be cleared', () {
      const draft = ProfileDetailsDraft(gender: Gender.other);
      expect(draft.copyWith(clearGender: true).gender, isNull);
    });
  });

  test('BirthDateInputFormatter inserts dots and caps at 8 digits', () {
    final formatter = BirthDateInputFormatter();
    String type(String text) => formatter
        .formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: text))
        .text;

    expect(type('1'), '1');
    expect(type('150'), '15.0');
    expect(type('15031998'), '15.03.1998');
    expect(type('150319981'), '15.03.1998');
    expect(type('15/03/1998'), '15.03.1998');
  });

  test('labels and formatting', () {
    expect(formatAge(22), '22 lata');
    expect(formatAge(25), '25 lat');
    expect(formatWeightKg(82.5), '82,5 kg');
    expect(formatWeightKg(80), '80 kg');
    expect(TrainingGoal.fatLoss.label, 'Redukcja');
    expect(TrainingGoal.fromApi('fat_loss'), TrainingGoal.fatLoss);
  });

  group('AuthUser.onboardingCompleted', () {
    test('missing in cached JSON counts as completed', () {
      final user = AuthUser.fromJson(const {
        'id': 'u1',
        'email': 'a@b.pl',
        'firstName': 'Jan',
        'lastName': 'K',
      });
      expect(user.onboardingCompleted, isTrue);
    });

    test('survives a JSON round trip', () {
      const user = AuthUser(
        id: 'u1',
        email: 'a@b.pl',
        firstName: 'Jan',
        lastName: 'K',
        onboardingCompleted: false,
      );
      final restored = AuthUser.fromJson(user.toJson());
      expect(restored.onboardingCompleted, isFalse);
      expect(restored.copyWith(firstName: 'Janek').onboardingCompleted, isFalse);
    });
  });
}
