import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

import '../../library/data/exercise_database.dart';
import '../domain/models/post_draft.dart';
import 'pending_post_photo_store.dart' show PendingPostPhotoOp;

/// Okładka planu czekająca w kolejce na serwer.
class PendingPlanCover {
  const PendingPlanCover({
    required this.planLocalId,
    required this.op,
    required this.version,
    this.bytes,
    this.filename,
  });

  final String planLocalId;
  final PendingPostPhotoOp op;

  /// Znacznik zapisu (`created_at`) — rozpoznaje zmianę w trakcie wysyłki.
  final int version;
  final Uint8List? bytes;
  final String? filename;
}

/// Kolejka okładek planów (tabela `pending_plan_covers`). Najnowsza decyzja
/// użytkownika zastępuje poprzednią — wysyłamy tylko stan końcowy.
abstract final class PendingPlanCoverStore {
  static const _table = ExerciseDatabase.tablePendingPlanCovers;

  static int _lastVersion = 0;

  /// Rosnący znacznik zapisu (mikrosekundy) — dwa zapisy w tej samej
  /// milisekundzie nie mogą dostać tej samej wersji.
  static int _nextVersion() {
    final now = DateTime.now().toUtc().microsecondsSinceEpoch;
    _lastVersion = now > _lastVersion ? now : _lastVersion + 1;
    return _lastVersion;
  }

  static Future<void> put(
    DatabaseExecutor db,
    String planLocalId,
    PostPhotoChange change,
  ) async {
    switch (change) {
      case KeepPostPhoto():
        return;
      case SetPostPhoto(:final photo):
        await db.insert(_table, {
          'plan_local_id': planLocalId,
          'op': PendingPostPhotoOp.upload.name,
          'bytes': photo.bytes,
          'filename': photo.filename,
          'created_at': _nextVersion(),
          'sync_error': null,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      case RemovePostPhoto():
        await db.insert(_table, {
          'plan_local_id': planLocalId,
          'op': PendingPostPhotoOp.remove.name,
          'bytes': null,
          'filename': null,
          'created_at': _nextVersion(),
          'sync_error': null,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  static Future<PendingPlanCover?> find(
    DatabaseExecutor db,
    String planLocalId,
  ) async {
    final rows = await db.query(
      _table,
      where: 'plan_local_id = ?',
      whereArgs: [planLocalId],
      limit: 1,
    );
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  /// Wszystko, co czeka na wysłanie (bez odrzuconych przez serwer) — bez
  /// bajtów zdjęć; te czyta [bytesOf] tylko dla wysyłanego wpisu.
  static Future<List<PendingPlanCover>> all(DatabaseExecutor db) async {
    final rows = await db.query(
      _table,
      columns: ['plan_local_id', 'op', 'filename', 'created_at'],
      where: 'sync_error IS NULL',
      orderBy: 'created_at',
    );
    return rows.map(_fromRow).toList();
  }

  /// Bajty zdjęcia w wersji [version]; `null`, gdy wpis zmieniono albo
  /// usunięto w międzyczasie.
  static Future<Uint8List?> bytesOf(
    DatabaseExecutor db,
    String planLocalId,
    int version,
  ) async {
    final rows = await db.query(
      _table,
      columns: ['bytes'],
      where: 'plan_local_id = ? AND created_at = ?',
      whereArgs: [planLocalId, version],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _bytes(rows.first['bytes']);
  }

  /// Usuwa wpis planu. Z [onlyVersion] — tylko gdy od odczytu nikt go nie
  /// nadpisał (nowe okładka wybrana w trakcie wysyłki zostaje w kolejce).
  static Future<void> remove(
    DatabaseExecutor db,
    String planLocalId, {
    int? onlyVersion,
  }) {
    return db.delete(
      _table,
      where: onlyVersion == null
          ? 'plan_local_id = ?'
          : 'plan_local_id = ? AND created_at = ?',
      whereArgs: [planLocalId, ?onlyVersion],
    );
  }

  /// Oznacza wpis jako odrzucony przez serwer — tylko w wersji
  /// [onlyVersion], więc nowsza okładka nie dziedziczy cudzego błędu.
  static Future<int> markRejected(
    DatabaseExecutor db,
    String planLocalId,
    String reason, {
    required int onlyVersion,
  }) {
    return db.update(
      _table,
      {'sync_error': reason},
      where: 'plan_local_id = ? AND created_at = ?',
      whereArgs: [planLocalId, onlyVersion],
    );
  }

  static PendingPlanCover _fromRow(Map<String, Object?> row) {
    final op = row['op'] == PendingPostPhotoOp.remove.name
        ? PendingPostPhotoOp.remove
        : PendingPostPhotoOp.upload;
    return PendingPlanCover(
      planLocalId: row['plan_local_id'] as String,
      op: op,
      version: row['created_at'] as int,
      bytes: _bytes(row['bytes']),
      filename: row['filename'] as String?,
    );
  }

  static Uint8List? _bytes(Object? raw) => raw is Uint8List
      ? raw
      : raw is List<int>
      ? Uint8List.fromList(raw)
      : null;
}
