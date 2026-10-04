import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/network/api_client.dart';
import 'package:gym/features/library/data/exercise_database.dart';
import 'package:gym/features/profile/data/offline_first_body_weight_repository.dart';
import 'package:gym/features/profile/data/sync/body_weight_sync_engine.dart';
import 'package:gym/features/profile/domain/models/body_weight_entry.dart';
import 'package:gym/features/profile/domain/models/profile_details.dart';
import 'package:gym/features/profile/domain/repositories/body_weight_repository.dart';
import 'package:gym/features/profile/presentation/bloc/body_weight_cubit.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Serwer w pamięci: `PUT`/`DELETE` po dniu, jak `/profile/me/body-weight`.
class _FakeRemote implements BodyWeightRepository {
  final server = <String, double>{};
  final calls = <String>[];
  bool offline = false;
  ApiException? saveError;

  /// Wstrzymuje najbliższy `save` do czasu `complete()`.
  Completer<void>? saveGate;

  void _checkNetwork() {
    if (offline) throw const ApiException('network_error');
  }

  @override
  Future<List<BodyWeightEntry>> list({int limit = 1000}) async {
    calls.add('GET');
    _checkNetwork();
    final dates = server.keys.toList()..sort();
    return [
      for (final date in dates.reversed.take(limit).toList().reversed)
        BodyWeightEntry(date: parseIsoDate(date)!, weightKg: server[date]!),
    ];
  }

  @override
  Future<BodyWeightEntry> save(DateTime date, double weightKg) async {
    final key = formatIsoDate(date);
    calls.add('PUT $key');
    final gate = saveGate;
    if (gate != null) {
      saveGate = null;
      await gate.future;
    }
    _checkNetwork();
    if (saveError != null) throw saveError!;
    server[key] = weightKg;
    return BodyWeightEntry(date: date, weightKg: weightKg);
  }

  @override
  Future<void> delete(DateTime date) async {
    final key = formatIsoDate(date);
    calls.add('DELETE $key');
    _checkNetwork();
    server.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory dir;
  late ExerciseDatabase db;
  late _FakeRemote remote;
  late BodyWeightSyncEngine sync;
  late OfflineFirstBodyWeightRepository repo;
  late int dataChanges;
  late int uploads;

  final today = DateTime(2026, 10, 4);
  final yesterday = DateTime(2026, 10, 3);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('gym_bw');
    db = ExerciseDatabase('bw.db', directoryOverride: dir.path);
    remote = _FakeRemote();
    dataChanges = 0;
    uploads = 0;
    sync = BodyWeightSyncEngine(
      remote: remote,
      localDb: db,
      onDataChanged: () => dataChanges++,
      onUploaded: () => uploads++,
    );
    repo = OfflineFirstBodyWeightRepository(
      localDb: db,
      syncEngine: sync,
      clock: () => DateTime(2026, 10, 4, 12),
    );
  });

  tearDown(() async {
    sync.stop();
    // Zaplanowane w tle flush/pull muszą skończyć się przed zamknięciem bazy.
    await sync.flush();
    await db.close();
    await dir.delete(recursive: true);
  });

  Future<List<Map<String, Object?>>> rows() =>
      db.run((d) => d.query(ExerciseDatabase.tableBodyWeightEntries));

  test('save offline is listed at once and sent after reconnect', () async {
    remote.offline = true;

    final saved = await repo.save(today, 81.26);
    expect(saved, BodyWeightEntry(date: today, weightKg: 81.3));
    expect(await repo.list(), [saved]);
    await sync.flush();
    expect((await db.countSyncBacklog()).pending, 1);
    expect(remote.server, isEmpty);

    remote.offline = false;
    await sync.flush();

    expect(remote.server, {'2026-10-04': 81.3});
    expect((await db.countSyncBacklog()).pending, 0);
    expect((await rows()).single['pending_op'], isNull);
    expect(uploads, 1);
  });

  test('delete offline hides the entry and removes it on the server', () async {
    remote.server['2026-10-03'] = 80.0;
    remote.server['2026-10-04'] = 81.0;
    await sync.pull();
    remote.offline = true;

    await repo.delete(yesterday);

    expect(await repo.list(), [BodyWeightEntry(date: today, weightKg: 81.0)]);
    expect((await db.countSyncBacklog()).pending, 1);

    remote.offline = false;
    await sync.flush();

    expect(remote.server, {'2026-10-04': 81.0});
    expect((await rows()).map((r) => r['date']), ['2026-10-04']);
    expect((await db.countSyncBacklog()).pending, 0);
  });

  test('pull keeps unsent changes and applies the server elsewhere', () async {
    remote.server['2026-10-01'] = 79.0;
    remote.server['2026-10-02'] = 79.5;
    await sync.pull();
    remote.offline = true;
    await repo.save(DateTime(2026, 10, 2), 70.0);
    await repo.delete(DateTime(2026, 10, 1));

    // Inne urządzenie: nowy pomiar, zmiana wagi z 2.10 (lokalnie niewysłana).
    remote.server['2026-10-03'] = 80.0;
    remote.server['2026-10-02'] = 75.0;
    remote.offline = false;
    await sync.pull();

    expect(await repo.list(), [
      BodyWeightEntry(date: DateTime(2026, 10, 2), weightKg: 70.0),
      BodyWeightEntry(date: yesterday, weightKg: 80.0),
    ]);

    await sync.flush();
    expect(remote.server, {'2026-10-02': 70.0, '2026-10-03': 80.0});

    // Usunięte na innym urządzeniu znika też tutaj.
    remote.server.remove('2026-10-03');
    await sync.pull();
    expect(await repo.list(), [
      BodyWeightEntry(date: DateTime(2026, 10, 2), weightKg: 70.0),
    ]);
  });

  test('edit made while the upload is in flight is sent again', () async {
    final gate = Completer<void>();
    remote.saveGate = gate;
    await repo.save(today, 80.0);
    final flushing = sync.flush();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    await db.run(
      (d) => d.update(
        ExerciseDatabase.tableBodyWeightEntries,
        {'weight_kg': 82.0, 'updated_at': 999999999999999},
        where: 'date = ?',
        whereArgs: ['2026-10-04'],
      ),
    );
    gate.complete();
    await flushing;

    expect((await rows()).single['pending_op'], 'upsert');
    expect((await rows()).single['weight_kg'], 82.0);
    await sync.flush();
    expect(remote.server, {'2026-10-04': 82.0});
    expect((await rows()).single['pending_op'], isNull);
  });

  test('rejected entry is marked failed until retried', () async {
    remote.saveError = const ApiException('invalid_date', statusCode: 400);
    await repo.save(today, 80.0);
    await sync.flush();

    expect(await db.countSyncBacklog(), (pending: 0, failed: 1));
    await sync.flush();
    expect(remote.calls.where((c) => c.startsWith('PUT')), hasLength(1));

    remote.saveError = null;
    await db.clearSyncErrors();
    await sync.flush();
    expect(await db.countSyncBacklog(), (pending: 0, failed: 0));
    expect(remote.server, {'2026-10-04': 80.0});
  });

  test('save rejects values the server would refuse', () async {
    expect(
      () => repo.save(today, 20),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          'invalid_weight',
        ),
      ),
    );
    expect(
      () => repo.save(DateTime(2026, 10, 5), 80),
      throwsA(
        isA<ApiException>().having((e) => e.message, 'message', 'invalid_date'),
      ),
    );
    expect(await rows(), isEmpty);
  });

  test('first list waits for the server, later ones read locally', () async {
    remote.server['2026-10-03'] = 80.0;

    expect(await repo.list(), [
      BodyWeightEntry(date: yesterday, weightKg: 80.0),
    ]);
    expect(remote.calls, ['GET']);

    remote.offline = true;
    expect(await repo.list(), [
      BodyWeightEntry(date: yesterday, weightKg: 80.0),
    ]);
  });

  test('first list offline shows local entries without failing', () async {
    remote.offline = true;
    expect(await repo.list(), isEmpty);
  });

  test('cubit reloads when sync changes local data', () async {
    final changes = ValueNotifier(0);
    final cubit = BodyWeightCubit(repo, dataChanges: changes);
    await cubit.load();
    expect(cubit.state.entries, isEmpty);

    remote.server['2026-10-03'] = 80.0;
    await sync.pull();
    changes.value++;
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(cubit.state.entries, [
      BodyWeightEntry(date: yesterday, weightKg: 80.0),
    ]);
    await cubit.close();
  });

  group('database upgrade', () {
    test('v12 database gains the body weight table', () async {
      final path = p.join(dir.path, 'v12.db');
      final fresh = ExerciseDatabase('v12.db', directoryOverride: dir.path);
      await fresh.run((d) async {
        await d.execute(
          'DROP TABLE ${ExerciseDatabase.tableBodyWeightEntries}',
        );
      });
      await fresh.close();
      final raw = await openDatabase(path);
      await raw.setVersion(12);
      await raw.close();

      final upgraded = ExerciseDatabase('v12.db', directoryOverride: dir.path);
      expect(await upgraded.countSyncBacklog(), (pending: 0, failed: 0));
      await upgraded.run(
        (d) => d.insert(ExerciseDatabase.tableBodyWeightEntries, {
          'date': '2026-10-04',
          'weight_kg': 80.0,
          'updated_at': 1,
          'pending_op': 'upsert',
        }),
      );
      expect(await upgraded.countSyncBacklog(), (pending: 1, failed: 0));
      await upgraded.clearSyncErrors();
      await upgraded.close();
    });

    test('v2 database upgrades through the v9 sync_error step', () async {
      final path = p.join(dir.path, 'v2.db');
      final legacy = await openDatabase(
        path,
        version: 2,
        onCreate: (d, _) => d.execute('''
          CREATE TABLE exercises (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            muscles TEXT NOT NULL,
            category TEXT NOT NULL,
            description TEXT NOT NULL DEFAULT '',
            image_url TEXT,
            is_favourite INTEGER NOT NULL DEFAULT 0,
            is_mine INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL
          )
        '''),
      );
      await legacy.close();

      final upgraded = ExerciseDatabase('v2.db', directoryOverride: dir.path);
      expect(await upgraded.countSyncBacklog(), (pending: 0, failed: 0));
      await upgraded.close();
    });
  });
}
