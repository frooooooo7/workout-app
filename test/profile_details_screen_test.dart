import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/profile/domain/models/profile_details.dart';
import 'package:gym/features/profile/domain/models/profile_stats.dart';
import 'package:gym/features/profile/domain/models/user_profile.dart';
import 'package:gym/features/profile/domain/repositories/profile_repository.dart';
import 'package:gym/features/profile/presentation/bloc/profile_details_cubit.dart';
import 'package:gym/features/profile/presentation/screens/profile_details_screen.dart';
import 'package:gym/features/profile/presentation/widgets/profile_details_fields.dart';

const _profile = UserProfile(
  id: 'me',
  firstName: 'Jan',
  lastName: 'Kowalski',
  handle: 'jan',
  stats: ProfileStats(followingCount: 0, followersCount: 0, workoutsCount: 0),
  isOwnProfile: true,
  details: ProfileDetails(
    heightCm: 180,
    weightKg: 80,
    trainingGoal: TrainingGoal.strength,
    weeklyTrainingDays: 3,
  ),
);

class _FakeRepository extends Fake implements ProfileRepository {
  final sentDetails = <ProfileDetails?>[];

  @override
  Future<UserProfile> getOwnProfile() async => _profile;

  @override
  Future<UserProfile> updateProfile({
    String? firstName,
    String? lastName,
    String? bio,
    String? handle,
    ProfileDetails? details,
  }) async {
    sentDetails.add(details);
    return _profile.copyWith(details: details);
  }
}

void main() {
  testWidgets('edits saved details and closes with the updated profile', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = _FakeRepository();
    Object? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await Navigator.of(context).push<Object?>(
                  MaterialPageRoute(
                    builder: (_) => BlocProvider(
                      create: (_) => ProfileDetailsCubit(repo),
                      child: const ProfileDetailsScreen(),
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    Finder save() => find.byKey(profileDetailsSaveButtonKey);
    bool saveEnabled() => tester.widget<FilledButton>(save()).onPressed != null;

    expect(find.text('180'), findsOneWidget);
    expect(saveEnabled(), isFalse);

    await tester.enterText(find.byKey(profileWeightFieldKey), '78,5');
    await tester.tap(find.text('Siła')); // odznaczenie celu
    await tester.pump();
    expect(saveEnabled(), isTrue);

    await tester.ensureVisible(save());
    await tester.tap(save());
    await tester.pumpAndSettle();

    expect(repo.sentDetails.single, const ProfileDetails(
      heightCm: 180,
      weightKg: 78.5,
      weeklyTrainingDays: 3,
    ));
    expect(find.byType(ProfileDetailsScreen), findsNothing);
    expect((result! as UserProfile).details?.weightKg, 78.5);
  });
}
