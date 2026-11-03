import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/library/data/exercise_database.dart';
import 'package:gym/features/library/data/exercise_dto.dart';
import 'package:gym/features/library/data/exercise_remote_data_source.dart';
import 'package:gym/features/library/domain/exercise_search.dart';
import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  const instructions = ExerciseInstructions(
    steps: ['Połóż się na ławce.', 'Wypchnij sztangę.'],
    mistakes: ['Odbijanie od klatki'],
  );

  Map<String, dynamic> apiJson() => {
    'id': 'srv-1',
    'name': 'Wyciskanie sztangi na ławce',
    'muscles': ['chest', 'triceps'],
    'category': 'compound',
    'equipment': 'barbell',
    'aliases': ['bench', 'klata sztanga'],
    'instructions': instructions.toJson(),
    'pattern': 'push_horizontal',
  };

  test('API JSON niesie sprzęt, inne nazwy, technikę i rodzaj ruchu', () {
    final e = ExerciseRemoteDataSource.fromJson(apiJson());
    expect(e.equipment, ExerciseEquipment.barbell);
    expect(e.aliases, ['bench', 'klata sztanga']);
    expect(e.instructions, instructions);
    expect(e.pattern, 'push_horizontal');
  });

  test(
    'starszy serwer bez nowych pól i nieznany sprzęt nie psują parsowania',
    () {
      final json = apiJson()
        ..remove('aliases')
        ..remove('instructions')
        ..['equipment'] = 'laser';
      final e = ExerciseRemoteDataSource.fromJson(json);
      expect(e.equipment, isNull);
      expect(e.aliases, isEmpty);
      expect(e.instructions, isNull);
    },
  );

  test('wiersz bazy zachowuje nowe pola w obie strony', () {
    final e = ExerciseRemoteDataSource.fromJson(apiJson());
    final dto = ExerciseDto.fromPulledServer(e, 'local-1');
    final back = ExerciseDto.fromMap(dto.toMap()).toDomain();
    expect(back.equipment, ExerciseEquipment.barbell);
    expect(back.aliases, ['bench', 'klata sztanga']);
    expect(back.instructions, instructions);
    expect(back.pattern, 'push_horizontal');
    expect(back.serverId, 'srv-1');
  });

  test('uszkodzony JSON w bazie daje puste pola zamiast błędu', () {
    expect(ExerciseDto.decodeAliases('{nie json'), isEmpty);
    expect(ExerciseInstructions.tryParse('{nie json'), isNull);
    expect(ExerciseInstructions.tryParse('{"steps":[],"mistakes":[]}'), isNull);
  });

  test('szukanie znajduje po innej nazwie i po sprzęcie', () {
    final bench = ExerciseRemoteDataSource.fromJson(apiJson());
    final ohp = Exercise(
      id: 'ohp',
      name: 'Wyciskanie sztangi stojąc (OHP)',
      muscles: const [MuscleGroup.frontDelts],
      category: ExerciseCategory.compound,
      aliases: const ['żołnierskie'],
      equipment: ExerciseEquipment.barbell,
    );
    final curl = Exercise(
      id: 'curl',
      name: 'Uginanie ramion',
      muscles: const [MuscleGroup.biceps],
      category: ExerciseCategory.isolation,
      equipment: ExerciseEquipment.dumbbell,
    );
    final all = [bench, ohp, curl];
    List<String> find(String q) => [
      for (final e in ExerciseSearch.rank(all, q)) e.id,
    ];
    expect(find('zolnierskie'), ['ohp']);
    expect(find('bench'), ['srv-1']);
    expect(find('hantle'), ['curl']);
    expect(find('sztanga barki'), ['ohp']);
  });

  test('baza v21 dostaje kolumny v22 przy otwarciu', () async {
    final dir = await Directory.systemTemp.createTemp('gym_v22_mig');
    final path = p.join(dir.path, 'v21.db');
    final legacy = await openDatabase(
      path,
      version: 21,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE exercises (
            local_id TEXT PRIMARY KEY NOT NULL,
            server_id TEXT UNIQUE,
            name TEXT NOT NULL,
            muscles TEXT NOT NULL,
            category TEXT NOT NULL,
            description TEXT NOT NULL DEFAULT '',
            image_url TEXT,
            is_favourite INTEGER NOT NULL DEFAULT 0,
            is_mine INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL
          )
        ''');
      },
    );
    await legacy.insert('exercises', {
      'local_id': 'a',
      'name': 'X',
      'muscles': '["biceps"]',
      'category': 'isolation',
      'created_at': 1700000000000,
    });
    await legacy.close();

    final edb = ExerciseDatabase('v21.db', directoryOverride: dir.path);
    await edb.run((db) async {
      final columns = (await db.rawQuery(
        'PRAGMA table_info(exercises)',
      )).map((r) => r['name']).toSet();
      expect(
        columns,
        containsAll(['equipment', 'aliases', 'instructions', 'pattern']),
      );
      final row = (await db.query('exercises')).single;
      expect(row['name'], 'X');
      expect(row['equipment'], isNull);
    });
    await edb.close();
    await dir.delete(recursive: true);
  });
}
