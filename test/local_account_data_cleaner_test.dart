import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/account/data/local_account_data_cleaner.dart';
import 'package:gym/features/feed/data/shared_preferences_feed_cache.dart';
import 'package:gym/features/library/data/exercise_database.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('gym_account_cleaner');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test('wipes the per-user database and user-scoped prefs only', () async {
    SharedPreferences.setMockInitialValues({
      SharedPreferencesFeedCache.keyFor('user-1'): '{"items":[]}',
      SharedPreferencesFeedCache.keyFor('user-2'): '{"items":[]}',
      'rest_timer_notifications_enabled': false,
      'last_custom_rest_duration': 120,
    });

    final dbName = LocalAccountDataCleaner.databaseFileName('user-1');
    final otherName = LocalAccountDataCleaner.databaseFileName('user-2');
    for (final name in [dbName, otherName]) {
      final db = ExerciseDatabase(name, directoryOverride: dir.path);
      await db.countSyncBacklog();
      await db.close();
    }
    expect(await File(p.join(dir.path, dbName)).exists(), isTrue);

    await LocalAccountDataCleaner(databaseDirectory: dir.path).wipe('user-1');

    expect(await File(p.join(dir.path, dbName)).exists(), isFalse);
    expect(await File(p.join(dir.path, otherName)).exists(), isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(SharedPreferencesFeedCache.keyFor('user-1')), isFalse);
    expect(prefs.containsKey(SharedPreferencesFeedCache.keyFor('user-2')), isTrue);
    expect(prefs.getBool('rest_timer_notifications_enabled'), isFalse);
    expect(prefs.getInt('last_custom_rest_duration'), 120);
  });

  test('evicts cached avatar images of the deleted account', () async {
    SharedPreferences.setMockInitialValues({});
    final evicted = <String>[];

    await LocalAccountDataCleaner(
      databaseDirectory: dir.path,
      ownImageUrls: (userId) => userId == 'user-1'
          ? const ['/uploads/avatars/a.png', 'https://cdn.example/b.png']
          : const ['/uploads/avatars/other.png'],
      evictImage: (url) async => evicted.add(url),
    ).wipe('user-1');

    expect(evicted, hasLength(2));
    expect(evicted.first, endsWith('/uploads/avatars/a.png'));
    expect(evicted.first, isNot(contains('/api/v1')));
    expect(evicted.last, 'https://cdn.example/b.png');
  });
}
