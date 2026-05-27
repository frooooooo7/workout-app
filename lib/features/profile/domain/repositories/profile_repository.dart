import 'dart:typed_data';

import '../models/following_user.dart';
import '../models/profile_activity.dart';
import '../models/profile_update_input.dart';
import '../models/user_profile.dart';

abstract class ProfileRepository {
  Future<UserProfile> getOwnProfile();

  Future<UserProfile> getUserProfile(String userId);

  Future<List<FollowingUser>> getFollowing({int limit = 20, int offset = 0});

  Future<List<FollowingUser>> getFollowers({int limit = 20, int offset = 0});

  Future<List<ProfileActivity>> getRecentActivities({
    int limit = 5,
    String? userId,
  });

  Future<List<FollowingUser>> searchUsers(String query);

  Future<UserProfile> updateBio(String bio);

  Future<UserProfile> updateProfile(ProfileUpdateInput input);

  Future<UserProfile> uploadAvatar(Uint8List bytes, String filename);
}
