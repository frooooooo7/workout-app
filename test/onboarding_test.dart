import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/network/api_client.dart';
import 'package:gym/features/onboarding/presentation/bloc/onboarding_cubit.dart';
import 'package:gym/features/onboarding/presentation/bloc/onboarding_state.dart';
import 'package:gym/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:gym/features/onboarding/presentation/widgets/onboarding_step_done.dart';
import 'package:gym/features/onboarding/presentation/widgets/onboarding_step_parts.dart';
import 'package:gym/features/onboarding/presentation/widgets/onboarding_step_profile.dart';
import 'package:gym/features/profile/domain/models/profile_details.dart';
import 'package:gym/features/profile/domain/models/profile_stats.dart';
import 'package:gym/features/profile/domain/models/user_profile.dart';
import 'package:gym/features/profile/domain/repositories/profile_repository.dart';
import 'package:gym/features/profile/presentation/widgets/profile_details_fields.dart';

const _newAccount = UserProfile(
  id: 'me',
  firstName: 'Jan',
  lastName: 'Kowalski',
  handle: 'jan.kowalski_ab12cd',
  stats: ProfileStats(followingCount: 0, followersCount: 0, workoutsCount: 0),
  isOwnProfile: true,
  details: ProfileDetails.empty,
  onboardingCompleted: false,
);

class _FakeRepository extends Fake implements ProfileRepository {
  _FakeRepository([this.profile = _newAccount]);

  UserProfile profile;
  final updates = <Map<String, Object?>>[];
  var uploads = 0;
  var completes = 0;
  Object? loadError;
  Object? updateError;
  Object? completeError;

  @override
  Future<UserProfile> getOwnProfile() async {
    if (loadError != null) throw loadError!;
    return profile;
  }

  @override
  Future<UserProfile> updateProfile({
    String? firstName,
    String? lastName,
    String? bio,
    String? handle,
    ProfileDetails? details,
  }) async {
    if (updateError != null) throw updateError!;
    updates.add({'handle': ?handle, 'bio': ?bio, 'details': ?details});
    profile = profile.copyWith(handle: handle, bio: bio, details: details);
    return profile;
  }

  @override
  Future<UserProfile> uploadAvatar(Uint8List bytes, String filename) async {
    uploads++;
    profile = profile.copyWith(avatarUrl: '/uploads/avatars/new.jpg');
    return profile;
  }

  @override
  Future<UserProfile> completeOnboarding() async {
    if (completeError != null) throw completeError!;
    completes++;
    profile = profile.copyWith(onboardingCompleted: true);
    return profile;
  }
}

Future<OnboardingCubit> _loadedCubit(
  _FakeRepository repo, {
  Future<void> Function(UserProfile)? onCompleted,
}) async {
  final cubit = OnboardingCubit(repo, onCompleted: onCompleted);
  await cubit.load();
  return cubit;
}

void main() {
  group('OnboardingCubit', () {
    test('load prefills the handle and details draft', () async {
      final repo = _FakeRepository(
        _newAccount.copyWith(
          bio: 'Siłka',
          details: const ProfileDetails(heightCm: 180),
        ),
      );
      final cubit = await _loadedCubit(repo);

      expect(cubit.state.step, OnboardingStep.profile);
      expect(cubit.state.handle, 'jan.kowalski_ab12cd');
      expect(cubit.state.bio, 'Siłka');
      expect(cubit.state.draft.heightText, '180');
      await cubit.close();
    });

    test('unchanged profile step saves nothing and moves on', () async {
      final repo = _FakeRepository();
      final cubit = await _loadedCubit(repo);

      await cubit.next();

      expect(repo.updates, isEmpty);
      expect(repo.uploads, 0);
      expect(cubit.state.step, OnboardingStep.body);
      await cubit.close();
    });

    test('profile step saves normalized handle, bio and photo', () async {
      final repo = _FakeRepository();
      final cubit = await _loadedCubit(repo);

      cubit.handleChanged(' @Jan.Silny ');
      cubit.bioChanged('  Siła 4× w tygodniu ');
      cubit.avatarPicked(Uint8List.fromList([1, 2, 3]), 'me.png');
      await cubit.next();

      expect(repo.updates, [
        {'handle': 'jan.silny', 'bio': 'Siła 4× w tygodniu'},
      ]);
      expect(repo.uploads, 1);
      expect(cubit.state.step, OnboardingStep.body);
      expect(cubit.state.avatarBytes, isNull);
      expect(cubit.state.profile!.avatarUrl, '/uploads/avatars/new.jpg');
      await cubit.close();
    });

    test('invalid handle blocks Dalej; taken handle shows the API error',
        () async {
      final repo = _FakeRepository();
      final cubit = await _loadedCubit(repo);

      cubit.handleChanged('ab');
      expect(cubit.state.canContinue, isFalse);

      repo.updateError = const ApiException('handle_taken', statusCode: 409);
      cubit.handleChanged('anna.nowak');
      await cubit.next();

      expect(cubit.state.step, OnboardingStep.profile);
      expect(cubit.state.error, 'Ten nick jest już zajęty. Wybierz inny.');
      expect(cubit.state.saving, isFalse);
      await cubit.close();
    });

    test('body step merges into saved details and keeps the goal', () async {
      final repo = _FakeRepository(
        _newAccount.copyWith(
          details: const ProfileDetails(trainingGoal: TrainingGoal.strength),
        ),
      );
      final cubit = await _loadedCubit(repo);
      await cubit.skip();

      cubit.heightChanged('99');
      expect(cubit.state.canContinue, isFalse);

      cubit.heightChanged('182');
      cubit.weightChanged('82,5');
      cubit.genderChanged(Gender.male);
      await cubit.next();

      expect(repo.updates.single['details'], const ProfileDetails(
        gender: Gender.male,
        heightCm: 182,
        weightKg: 82.5,
        trainingGoal: TrainingGoal.strength,
      ));
      expect(cubit.state.step, OnboardingStep.goal);
      await cubit.close();
    });

    test('goal step saves, completes and notifies', () async {
      final repo = _FakeRepository();
      UserProfile? completedWith;
      final cubit = await _loadedCubit(
        repo,
        onCompleted: (profile) async => completedWith = profile,
      );
      await cubit.skip();
      await cubit.skip();

      cubit.trainingGoalChanged(TrainingGoal.muscle);
      cubit.weeklyTrainingDaysChanged(4);
      await cubit.next();

      expect(repo.updates.single['details'], const ProfileDetails(
        trainingGoal: TrainingGoal.muscle,
        weeklyTrainingDays: 4,
      ));
      expect(repo.completes, 1);
      expect(completedWith?.onboardingCompleted, isTrue);
      expect(cubit.state.step, OnboardingStep.done);
      await cubit.close();
    });

    test('skipping everything saves nothing but completes', () async {
      final repo = _FakeRepository();
      final cubit = await _loadedCubit(repo);

      cubit.heightChanged('180'); // wpisane, ale krok pominięty
      await cubit.skip();
      await cubit.skip();
      await cubit.skip();

      expect(repo.updates, isEmpty);
      expect(repo.completes, 1);
      expect(cubit.state.step, OnboardingStep.done);
      await cubit.close();
    });

    test('failed completion stays on the goal step and can be retried',
        () async {
      final repo = _FakeRepository()
        ..completeError = const ApiException('network_error');
      final cubit = await _loadedCubit(repo);
      await cubit.skip();
      await cubit.skip();

      await cubit.skip();
      expect(cubit.state.step, OnboardingStep.goal);
      expect(cubit.state.error, isNotNull);

      repo.completeError = null;
      await cubit.skip();
      expect(cubit.state.step, OnboardingStep.done);
      await cubit.close();
    });

    test('back moves between steps 2–3 only', () async {
      final cubit = await _loadedCubit(_FakeRepository());

      expect(cubit.state.canGoBack, isFalse);
      await cubit.skip();
      cubit.back();
      expect(cubit.state.step, OnboardingStep.profile);
      await cubit.close();
    });
  });

  group('OnboardingScreen', () {
    Future<void> pumpScreen(
      WidgetTester tester,
      OnboardingCubit cubit, {
      VoidCallback? onFinish,
      VoidCallback? onDefer,
    }) async {
      await tester.binding.setSurfaceSize(const Size(430, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: cubit,
            child: OnboardingScreen(
              onFinish: onFinish ?? () {},
              onDefer: onDefer ?? () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> tapKey(WidgetTester tester, Key key) async {
      await tester.ensureVisible(find.byKey(key));
      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();
    }

    testWidgets('walks through all steps to the summary', (tester) async {
      final repo = _FakeRepository();
      final cubit = await _loadedCubit(repo);
      addTearDown(cubit.close);
      var finished = false;
      await pumpScreen(tester, cubit, onFinish: () => finished = true);

      expect(find.text('Twój profil'), findsOneWidget);
      expect(find.text('jan.kowalski_ab12cd'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsNothing);

      await tester.enterText(find.byKey(onboardingHandleFieldKey), 'jan.silny');
      await tapKey(tester, onboardingNextButtonKey);

      expect(find.text('O Tobie'), findsOneWidget);
      await tester.enterText(find.byKey(profileBirthDateFieldKey), '01012020');
      await tester.pump();
      expect(find.text('Musisz mieć co najmniej 16 lat.'), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(find.byKey(onboardingNextButtonKey))
            .onPressed,
        isNull,
      );

      await tester.enterText(find.byKey(profileBirthDateFieldKey), '15031998');
      await tester.enterText(find.byKey(profileHeightFieldKey), '182');
      await tester.pump();
      expect(find.text('15.03.1998'), findsOneWidget);
      await tapKey(tester, onboardingNextButtonKey);

      expect(find.text('Twój cel'), findsOneWidget);
      await tester.tap(find.text('Siła'));
      await tester.tap(find.text('4'));
      await tester.pump();
      await tapKey(tester, onboardingNextButtonKey);

      expect(find.text('Gotowe, Jan!'), findsOneWidget);
      expect(find.text('@jan.silny'), findsOneWidget);
      expect(find.text('182 cm'), findsOneWidget);
      expect(find.text('Siła'), findsOneWidget);
      expect(find.text('4× w tygodniu'), findsOneWidget);
      expect(repo.completes, 1);

      await tapKey(tester, onboardingStartButtonKey);
      expect(finished, isTrue);
    });

    testWidgets('back arrow returns from step 2 to step 1', (tester) async {
      final cubit = await _loadedCubit(_FakeRepository());
      addTearDown(cubit.close);
      await pumpScreen(tester, cubit);

      await tapKey(tester, onboardingSkipButtonKey);
      expect(find.text('O Tobie'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Twój profil'), findsOneWidget);
    });

    testWidgets('load failure offers retry and "Dokończ później"', (
      tester,
    ) async {
      final repo = _FakeRepository()
        ..loadError = const ApiException('network_error');
      final cubit = await _loadedCubit(repo);
      addTearDown(cubit.close);
      var deferred = false;
      await pumpScreen(tester, cubit, onDefer: () => deferred = true);

      expect(
        find.text('Brak połączenia z internetem. Spróbuj ponownie.'),
        findsOneWidget,
      );
      await tapKey(tester, onboardingDeferButtonKey);
      expect(deferred, isTrue);

      repo.loadError = null;
      await tester.tap(find.text('Spróbuj ponownie'));
      await tester.pumpAndSettle();
      expect(find.text('Twój profil'), findsOneWidget);
    });
  });
}
