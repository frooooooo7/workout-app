import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

import '../../library/data/exercise_database.dart';
import '../domain/models/post_draft.dart';

/// Zdjęcie posta czekające w kolejce na serwer.
class PendingPostPhoto {
  const PendingPostPhoto({
    required this.sessionLocalId,
    required this.op,
    required this.version,
    this.bytes,
    this.filename,
  });

  final String sessionLocalId;
  final PendingPostPhotoOp op;

  /// Znacznik zapisu (`created_at`) — rozpoznaje zmianę w trakcie wysyłki.
  final int version;
  final Uint8List? bytes;
  final String? filename;
}

enum PendingPostPhotoOp { upload, remove }

/// Kolejka zdjęć postów (tabela `pending_post_photos`). Najnowsza decyzja
/// użytkownika zastępuje poprzednią — wysyłamy tylko stan końcowy.
abstract final class PendingPostPhotoStore {
  static const _table = ExerciseDatabase.tablePendingPostPhotos;

  static Future<void> put(
    DatabaseExecutor db,
    String sessionLocalId,
    PostPhotoChange change,
  ) async {
    switch (change) {
      case KeepPostPhoto():
        return;
      case SetPostPhoto(:final photo):
        await db.insert(_table, {
          'session_local_id': sessionLocalId,
          'op': PendingPostPhotoOp.upload.name,
          'bytes': photo.bytes,
          'filename': photo.filename,
          'created_at': DateTime.now().toUtc().millisecondsSinceEpoch,
          'sync_error': null,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      case RemovePostPhoto():
        await db.insert(_table, {
          'session_local_id': sessionLocalId,
          'op': PendingPostPhotoOp.remove.name,
          'bytes': null,
          'filename': null,
          'created_at': DateTime.now().toUtc().millisecondsSinceEpoch,
          'sync_error': null,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  static Future<PendingPostPhoto?> find(
    DatabaseExecutor db,
    String sessionLocalId,
  ) async {
    final rows = await db.query(
      _table,
      where: 'session_local_id = ?',
      whereArgs: [sessionLocalId],
      limit: 1,
    );
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  /// Wszystko, co czeka na wysłanie (bez odrzuconych przez serwer).
  static Future<List<PendingPostPhoto>> all(DatabaseExecutor db) async {
    final rows = await db.query(
      _table,
      where: 'sync_error IS NULL',
      orderBy: 'created_at',
    );
    return rows.map(_fromRow).toList();
  }

  /// Usuwa wpis sesji. Z [onlyVersion] — tylko gdy od odczytu nikt go nie
  /// nadpisał (nowe zdjęcie wybrane w trakcie wysyłki zostaje w kolejce).
  static Future<void> remove(
    DatabaseExecutor db,
    String sessionLocalId, {
    int? onlyVersion,
  }) {
    return db.delete(
      _table,
      where: onlyVersion == null
          ? 'session_local_id = ?'
          : 'session_local_id = ? AND created_at = ?',
      whereArgs: [sessionLocalId, ?onlyVersion],
    );
  }

  static Future<int> markRejected(
    DatabaseExecutor db,
    String sessionLocalId,
    String reason,
  ) {
    return db.update(
      _table,
      {'sync_error': reason},
      where: 'session_local_id = ?',
      whereArgs: [sessionLocalId],
    );
  }

  static PendingPostPhoto _fromRow(Map<String, Object?> row) {
    final op = row['op'] == PendingPostPhotoOp.remove.name
        ? PendingPostPhotoOp.remove
        : PendingPostPhotoOp.upload;
    final raw = row['bytes'];
    return PendingPostPhoto(
      sessionLocalId: row['session_local_id'] as String,
      op: op,
      version: row['created_at'] as int,
      bytes: raw is Uint8List
          ? raw
          : raw is List<int>
          ? Uint8List.fromList(raw)
          : null,
      filename: row['filename'] as String?,
    );
  }
}
