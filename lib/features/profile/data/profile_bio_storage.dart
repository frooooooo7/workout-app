import 'package:shared_preferences/shared_preferences.dart';

class ProfileBioStorage {
  const ProfileBioStorage();

  String _key(String userId) => 'profile_bio_$userId';

  Future<String?> read(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key(userId));
  }

  Future<void> write(String userId, String? bio) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _key(userId);
    if (bio == null || bio.trim().isEmpty) {
      await prefs.remove(key);
      return;
    }
    await prefs.setString(key, bio.trim());
  }
}
