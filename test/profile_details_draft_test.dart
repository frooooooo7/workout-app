import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/auth/domain/models/auth_models.dart';
import 'package:gym/features/profile/domain/models/profile_details.dart';
import 'package:gym/features/profile/presentation/utils/profile_details_draft.dart';
import 'package:gym/features/profile/presentation/utils/profile_details_labels.dart';
import 'package:gym/features/profile/presentation/widgets/birth_date_sheet.dart';
import 'package:gym/features/profile/presentation/widgets/ruler_picker.dart';

void main() {
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
      expect(ProfileDetailsDraft.fromDetails(details).toDetails(), details);
    });

    test('bodyOnto / goalOnto only replace their own step', () {
      const saved = ProfileDetails(
        heightCm: 170,
        trainingGoal: TrainingGoal.general,
        weeklyTrainingDays: 2,
      );
      const draft = ProfileDetailsDraft(
        heightCm: 175,
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

    test('every field can be cleared', () {
      final draft = ProfileDetailsDraft(
        gender: Gender.other,
        birthDate: DateTime(2000),
        heightCm: 170,
        weightKg: 70,
      );
      final cleared = draft.copyWith(
        clearGender: true,
        clearBirthDate: true,
        clearHeight: true,
        clearWeight: true,
      );
      expect(cleared.toDetails().isEmpty, isTrue);
    });

    test('age on a given day', () {
      final draft = ProfileDetailsDraft(birthDate: DateTime(2010, 9, 24));
      expect(draft.ageOn(DateTime(2026, 9, 23)), 15);
      expect(draft.ageOn(DateTime(2026, 9, 24)), 16);
    });
  });

  test('labels and formatting', () {
    expect(formatBirthDate(DateTime(1998, 3, 15)), '15 marca 1998');
    expect(formatAge(22), '22 lata');
    expect(formatAge(25), '25 lat');
    expect(formatWeightKg(82.5), '82,5 kg');
    expect(formatWeightKg(80), '80 kg');
    expect(formatWeeklyTrainingsLong(1), '1 trening w tygodniu');
    expect(formatWeeklyTrainingsLong(4), '4 treningi w tygodniu');
    expect(formatWeeklyTrainingsLong(5), '5 treningów w tygodniu');
    expect(TrainingGoal.fatLoss.label, 'Redukcja');
    expect(TrainingGoal.fromApi('fat_loss'), TrainingGoal.fatLoss);
    expect(ExperienceLevel.advanced.rank, 3);
  });

  group('RulerPicker', () {
    Future<List<double>> pumpRuler(
      WidgetTester tester, {
      double? value,
    }) async {
      final changes = <double>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: RulerPicker(
                  min: 100,
                  max: 250,
                  step: 1,
                  initial: 172,
                  value: value,
                  semanticsLabel: 'Wzrost',
                  formatValue: (v) => '${v.round()} cm',
                  onChanged: changes.add,
                ),
              ),
            ),
          ),
        ),
      );
      return changes;
    }

    testWidgets('dragging snaps to a whole tick and reports it', (
      tester,
    ) async {
      final changes = await pumpRuler(tester);

      // 10 px na kreskę: 5 kresek w prawo = +5 cm.
      await tester.timedDrag(
        find.byType(RulerPicker),
        const Offset(-50, 0),
        const Duration(milliseconds: 600),
      );
      await tester.pumpAndSettle();

      expect(changes, isNotEmpty);
      expect(changes.last, 177);
      expect(changes.every((v) => v == v.roundToDouble()), isTrue);
    });

    testWidgets('tapping an unset ruler takes the centre value', (
      tester,
    ) async {
      final changes = await pumpRuler(tester);

      await tester.tap(find.byType(RulerPicker));
      await tester.pump();

      expect(changes, [172]);
    });

    testWidgets('screen readers can step the value', (tester) async {
      final handle = tester.ensureSemantics();
      final changes = await pumpRuler(tester, value: 180);

      expect(tester.getSemantics(find.byType(RulerPicker)).value, '180 cm');
      tester.semantics.performAction(
        find.semantics.byLabel('Wzrost'),
        SemanticsAction.increase,
      );
      await tester.pumpAndSettle();

      expect(changes, [181]);
      handle.dispose();
    });
  });

  group('birth date sheet', () {
    /// Otwiera arkusz; zwraca funkcję odczytu wyniku po jego zamknięciu.
    Future<BirthDateResult? Function()> openSheet(
      WidgetTester tester, {
      DateTime? initial,
    }) async {
      BirthDateResult? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showBirthDateSheet(
                  context,
                  initial: initial,
                  today: DateTime(2026, 9, 23),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return () => result;
    }

    testWidgets('confirms the chosen date', (tester) async {
      final result = await openSheet(tester, initial: DateTime(1998, 3, 15));

      expect(find.text('15 marca 1998 · 28 lat'), findsOneWidget);
      await tester.tap(find.byKey(birthDateSheetConfirmKey));
      await tester.pumpAndSettle();

      expect(result()?.date, DateTime(1998, 3, 15));
    });

    testWidgets('under 16 cannot be confirmed', (tester) async {
      await openSheet(tester, initial: DateTime(2010, 12, 1));

      expect(find.text('Musisz mieć co najmniej 16 lat.'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(birthDateSheetConfirmKey))
            .onPressed,
        isNull,
      );
    });

    testWidgets('an existing date can be removed', (tester) async {
      final result = await openSheet(tester, initial: DateTime(1998, 3, 15));

      await tester.tap(find.byKey(birthDateSheetClearKey));
      await tester.pumpAndSettle();

      expect(result(), isNotNull);
      expect(result()!.date, isNull);
    });
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
