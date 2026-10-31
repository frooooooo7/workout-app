import 'dart:typed_data';

import '../models/follow_result.dart';
import '../models/following_user.dart';
import '../models/profile_details.dart';
import '../models/user_profile.dart';

abstract class ProfileRepository {
  Future<UserProfile> getOwnProfile();

  /// Ostatni własny profil zapisany na tym urządzeniu albo `null`. Odczyt
  /// z lokalnej bazy — nigdy nie czeka na sieć, więc ekrany pokazują dane
  /// od razu, a `getOwnProfile` odświeża je w tle.
  Future<UserProfile?> cachedOwnProfile();

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

  /// Ustawia cel masy ciała; `null` usuwa cel. Pozostałe dane bez zmian.
  Future<UserProfile> updateTargetWeight(double? kg);

  /// `GET /profile/handle-availability` — czy znormalizowany [handle] jest
  /// wolny. Własny, obecny nick też liczy się jako wolny.
  Future<bool> isHandleAvailable(String handle);

  /// `POST /profile/me/onboarding/complete` (idempotentne).
  Future<UserProfile> completeOnboarding();

  Future<UserProfile> updateBio(String bio);

  /// Multipart `POST /profile/me/avatar` (jpg/png/webp, maks. 5 MB).
  Future<UserProfile> uploadAvatar(Uint8List bytes, String filename);

  Future<UserProfile> removeAvatar();
}
