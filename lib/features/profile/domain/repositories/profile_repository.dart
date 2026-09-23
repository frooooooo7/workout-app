import 'dart:typed_data';

import '../models/follow_result.dart';
import '../models/following_user.dart';
import '../models/profile_details.dart';
import '../models/user_profile.dart';

abstract class ProfileRepository {
  Future<UserProfile> getOwnProfile();

  Future<UserProfile> getUserProfile(String userId);

  Future<List<FollowingUser>> getFollowing({int limit = 20, int offset = 0});

  Future<List<FollowingUser>> getFollowers({int limit = 20, int offset = 0});

  /// Osoby obserwowane przez [userId].
  Future<List<FollowingUser>> getUserFollowing(
    String userId, {
    int limit = 20,
    int offset = 0,
  });

  /// Osoby obserwujące [userId].
  Future<List<FollowingUser>> getUserFollowers(
    String userId, {
    int limit = 20,
    int offset = 0,
  });

  Future<List<FollowingUser>> searchUsers(String query);

  Future<FollowResult> follow(String userId);

  Future<FollowResult> unfollow(String userId);

  /// `PATCH /profile/me` — wysyła tylko przekazane (nie-null) pola.
  /// Pusty [bio] czyści opis. [details] idą w całości — puste pola
  /// czyszczą wartości na serwerze.
  Future<UserProfile> updateProfile({
    String? firstName,
    String? lastName,
    String? bio,
    String? handle,
    ProfileDetails? details,
  });

  /// `POST /profile/me/onboarding/complete` (idempotentne).
  Future<UserProfile> completeOnboarding();

  Future<UserProfile> updateBio(String bio);

  /// Multipart `POST /profile/me/avatar` (jpg/png/webp, maks. 5 MB).
  Future<UserProfile> uploadAvatar(Uint8List bytes, String filename);

  Future<UserProfile> removeAvatar();
}
