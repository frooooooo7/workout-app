import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/network/api_client.dart';
import 'package:gym/features/profile/domain/models/profile_details.dart';
import 'package:gym/features/profile/domain/models/profile_stats.dart';
import 'package:gym/features/profile/domain/models/user_profile.dart';
import 'package:gym/features/profile/domain/repositories/profile_repository.dart';
import 'package:gym/features/profile/presentation/bloc/edit_profile_cubit.dart';
import 'package:gym/features/profile/presentation/screens/edit_profile_screen.dart';

const _profile = UserProfile(
  id: 'me',
  firstName: 'Jan',
  lastName: 'Kowalski',
  handle: 'jan.kowalski',
  stats: ProfileStats(followingCount: 1, followersCount: 2, workoutsCount: 3),
  isOwnProfile: true,
);

class _FakeEditRepository extends Fake implements ProfileRepository {
  final updateCalls = <Map<String, String?>>[];
  var uploadCalls = 0;
  var removeCalls = 0;
  Object? uploadError;
  Object? updateError;

  @override
  Future<UserProfile> updateProfile({
    String? firstName,
    String? lastName,
    String? bio,
    String? handle,
    ProfileDetails? details,
  }) async {
    if (updateError != null) throw updateError!;
    updateCalls.add({
      'firstName': firstName,
      'lastName': lastName,
      'bio': bio,
      'handle': ?handle,
    });
    return _profile.copyWith(
      firstName: firstName,
      lastName: lastName,
      handle: handle,
      bio: bio,
      clearBio: bio != null && bio.isEmpty,
    );
  }

  @override
  Future<UserProfile> uploadAvatar(Uint8List bytes, String filename) async {
    uploadCalls++;
    if (uploadError != null) throw uploadError!;
    return _profile.copyWith(avatarUrl: '/uploads/avatars/x.jpg');
  }

  @override
  Future<UserProfile> removeAvatar() async {
    removeCalls++;
    return _profile.copyWith(clearAvatarUrl: true);
  }
}

FilledButton _saveButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byKey(editProfileSaveButtonKey));

void main() {
  Future<void> pumpScreen(
    WidgetTester tester,
    EditProfileCubit cubit, {
    ValueChanged<Object?>? onResult,
  }) async {
    await tester.binding.setSurfaceSize(const Size(430, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  final result = await Navigator.of(context).push<Object?>(
                    MaterialPageRoute(
                      builder: (_) => BlocProvider.value(
                        value: cubit,
                        child: const EditProfileScreen(),
                      ),
                    ),
                  );
                  onResult?.call(result);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('save is enabled only for valid changes', (tester) async {
    final cubit = EditProfileCubit(
      _FakeEditRepository(),
      initialProfile: _profile,
    );
    addTearDown(cubit.close);
    await pumpScreen(tester, cubit);

    expect(find.text('Jan'), findsOneWidget);
    expect(find.text('0/120'), findsOneWidget);
    expect(_saveButton(tester).onPressed, isNull);

    await tester.enterText(find.byKey(editProfileFirstNameFieldKey), 'Janek');
    await tester.pump();
    expect(_saveButton(tester).onPressed, isNotNull);

    await tester.enterText(find.byKey(editProfileFirstNameFieldKey), '   ');
    await tester.pump();
    expect(find.text('Podaj imię.'), findsOneWidget);
    expect(_saveButton(tester).onPressed, isNull);

    // Powrót do wartości początkowej (po przycięciu) = brak zmian.
    await tester.enterText(find.byKey(editProfileFirstNameFieldKey), ' Jan ');
    await tester.pump();
    expect(find.text('Podaj imię.'), findsNothing);
    expect(_saveButton(tester).onPressed, isNull);

    await tester.enterText(find.byKey(editProfileBioFieldKey), 'Siłownia 4×');
    await tester.pump();
    expect(find.text('11/120'), findsOneWidget);
    expect(_saveButton(tester).onPressed, isNotNull);
  });

  testWidgets('saving sends changed fields and closes with the profile', (
    tester,
  ) async {
    final repo = _FakeEditRepository();
    UserProfile? namesChangedWith;
    final cubit = EditProfileCubit(
      repo,
      initialProfile: _profile,
      onNamesChanged: (profile) async => namesChangedWith = profile,
    );
    addTearDown(cubit.close);
    Object? result;
    await pumpScreen(tester, cubit, onResult: (value) => result = value);

    await tester.enterText(find.byKey(editProfileLastNameFieldKey), 'Nowak ');
    await tester.pump();
    await tester.tap(find.byKey(editProfileSaveButtonKey));
    await tester.pumpAndSettle();

    expect(repo.updateCalls, [
      {'firstName': null, 'lastName': 'Nowak', 'bio': null},
    ]);
    expect(repo.uploadCalls, 0);
    expect(namesChangedWith?.lastName, 'Nowak');
    expect(find.byType(EditProfileScreen), findsNothing);
    expect(result, isA<UserProfile>());
    expect((result! as UserProfile).lastName, 'Nowak');
  });

  test('avatar upload failure keeps saved fields and shows Polish error',
      () async {
    final repo = _FakeEditRepository()
      ..uploadError = const ApiException('invalid_file', statusCode: 400);
    final cubit = EditProfileCubit(repo, initialProfile: _profile);

    cubit.bioChanged('Nowe bio');
    cubit.avatarPicked(Uint8List.fromList([1, 2, 3]), 'a.png');
    await cubit.save();

    expect(repo.updateCalls.single['bio'], 'Nowe bio');
    expect(repo.uploadCalls, 1);
    expect(cubit.state.saved, isNull);
    expect(cubit.state.error, 'Nieprawidłowy plik (JPG/PNG/WEBP, maks. 5 MB).');
    // Bio jest już zapisane — zostaje tylko zmiana zdjęcia.
    expect(cubit.state.hasFieldChanges, isFalse);
    expect(cubit.state.hasAvatarChange, isTrue);
    expect(cubit.state.canSave, isTrue);
    await cubit.close();
  });

  test('too large avatar is rejected before upload', () async {
    final repo = _FakeEditRepository();
    final cubit = EditProfileCubit(repo, initialProfile: _profile);

    cubit.avatarPicked(Uint8List(5 * 1024 * 1024 + 1), 'big.jpg');

    expect(cubit.state.avatarBytes, isNull);
    expect(cubit.state.error, contains('5 MB'));
    expect(cubit.state.canSave, isFalse);
    await cubit.close();
  });

  test('removing an existing avatar calls removeAvatar', () async {
    final repo = _FakeEditRepository();
    final cubit = EditProfileCubit(
      repo,
      initialProfile: _profile.copyWith(avatarUrl: '/uploads/avatars/a.jpg'),
    );

    expect(cubit.state.hasAvatar, isTrue);
    cubit.avatarRemoved();
    expect(cubit.state.canSave, isTrue);
    await cubit.save();

    expect(repo.removeCalls, 1);
    expect(repo.updateCalls, isEmpty);
    expect(cubit.state.saved?.avatarUrl, isNull);
    await cubit.close();
  });

  testWidgets('changed handle is validated and sent normalized', (
    tester,
  ) async {
    final repo = _FakeEditRepository();
    final cubit = EditProfileCubit(repo, initialProfile: _profile);
    addTearDown(cubit.close);
    await pumpScreen(tester, cubit);

    expect(find.text('jan.kowalski'), findsOneWidget);

    await tester.enterText(find.byKey(editProfileHandleFieldKey), '_jan');
    await tester.pump();
    expect(find.text('Nick musi zaczynać się literą lub cyfrą.'), findsOneWidget);
    expect(_saveButton(tester).onPressed, isNull);

    await tester.enterText(find.byKey(editProfileHandleFieldKey), ' @Jan.Silny');
    await tester.pump();
    expect(_saveButton(tester).onPressed, isNotNull);

    await tester.tap(find.byKey(editProfileSaveButtonKey));
    await tester.pumpAndSettle();

    expect(repo.updateCalls.single['handle'], 'jan.silny');
  });

  test('an old generated handle over the limit does not block saving',
      () async {
    final repo = _FakeEditRepository();
    final cubit = EditProfileCubit(
      repo,
      initialProfile: _profile.copyWith(
        handle: 'aleksandra.wisniewska.kowalska_a1b2c3',
      ),
    );

    cubit.bioChanged('Nowe bio');

    expect(cubit.state.handleError, isNull);
    expect(cubit.state.canSave, isTrue);
    await cubit.save();
    expect(repo.updateCalls.single.containsKey('handle'), isFalse);
    await cubit.close();
  });

  test('taken handle shows a Polish error', () async {
    final repo = _FakeEditRepository()
      ..updateError = const ApiException('handle_taken', statusCode: 409);
    final cubit = EditProfileCubit(repo, initialProfile: _profile);

    cubit.handleChanged('anna.nowak');
    await cubit.save();

    expect(cubit.state.error, 'Ten nick jest już zajęty. Wybierz inny.');
    expect(cubit.state.saved, isNull);
    await cubit.close();
  });
}
