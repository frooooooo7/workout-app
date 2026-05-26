import 'package:shared_preferences/shared_preferences.dart';

class ProfileBioStorage {
  const ProfileBioStorage(this._prefs);

  final SharedPreferences _prefs;

  String _key(String userId) => 'profile_bio_$userId';

  Future<String?> read(String userId) async {
    return _prefs.getString(_key(userId));
  }

  Future<void> write(String userId, String? bio) async {
    final key = _key(userId);
    if (bio == null || bio.trim().isEmpty) {
      await _prefs.remove(key);
      return;
    }
    await _prefs.setString(key, bio.trim());
  }
}
