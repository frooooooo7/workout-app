import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/sync/sync_engine_base.dart';
import '../../../../core/sync/sync_failure.dart';
import '../../../library/data/exercise_database.dart';
import '../../domain/models/body_weight_entry.dart';
import '../../domain/models/profile_details.dart';
import '../../domain/repositories/body_weight_repository.dart';

/// Synchronizacja dziennika masy ciała. Pomiar ma naturalny klucz — dzień —
/// a `PUT` i `DELETE` na serwerze są idempotentne, więc nie potrzeba
/// `clientId` ani `server_id`: wysyłka powtarza ostatnią wersję dnia.
class BodyWeightSyncEngine extends SyncEngineBase {
  BodyWeightSyncEngine({
    required BodyWeightRepository remote,
    required ExerciseDatabase localDb,
    super.onDataChanged,
    VoidCallback? onUploaded,
  }) : _remote = remote,
       _localDb = localDb,
       _onUploaded = onUploaded;

  final BodyWeightRepository _remote;
  final ExerciseDatabase _localDb;

  /// Po wysłaniu pomiaru — serwer przestawia wtedy też aktualną wagę profilu.
  final VoidCallback? _onUploaded;

  static const _table = ExerciseDatabase.tableBodyWeightEntries;

  /// Klucz [ExerciseDatabase.tableSyncState]: czas pierwszego udanego pobrania.
  static const pulledAtKey = 'body_weight_pulled_at';

  /// Maksimum `limit` w `GET /profile/me/body-weight`.
  static const pullLimit = 1000;

  Future<void> flush() => runCoalesced('flush', _flushImpl);

  Future<void> pull() => runCoalesced('pull', _pullImpl);

  Future<void> pullIfDue({Duration maxAge = SyncEngineBase.defaultPullMaxAge}) {
    return runCoalesced('pull-if-due', () async {
      if (isPullDue(maxAge)) await _pullImpl();
    });
  }

  /// Przed pierwszym pobraniem lokalna tabela jest pusta (np. zaraz po
  /// aktualizacji aplikacji) — ekran poczeka na serwer zamiast pokazać pusty
  /// dziennik. Offline czeka tylko na jedną próbę na [maxAge].
  Future<void> ensureInitialPull({
    Duration maxAge = SyncEngineBase.defaultPullMaxAge,
  }) {
    return runCoalesced('initial-pull', () async {
      if (!isPullDue(maxAge)) return;
      if (await _localDb.readSyncState(pulledAtKey) != null) return;
      await _pullImpl();
    });
  }

  static String _attemptKey(String date) => 'body_weight:$date';

  Future<void> _handleFailure(
    String date,
    String op,
    ApiException error,
  ) async {
    await _localDb.recordSyncAttemptFailure(
      localId: _attemptKey(date),
      op: '${op}_body_weight',
      message: error.message,
    );
    if (registerFailure(error) == SyncFailureKind.permanent) {
      await _localDb.run(
        (db) => db.update(
          _table,
          {'sync_error': error.message},
          where: 'date = ?',
          whereArgs: [date],
        ),
      );
    }
  }

  // ── Flush ─────────────────────────────────────────────────────────────────

  Future<void> _flushImpl() async {
    if (isStopped) return;
    final List<Map<String, Object?>> rows;
    try {
      rows = await _localDb.run(
        (db) => db.query(
          _table,
          where: 'pending_op IS NOT NULL AND sync_error IS NULL',
          orderBy: 'date ASC',
        ),
      );
    } on StateError {
      return; /* DB closing */
    }
    if (rows.isEmpty) return;

    final networkMark = networkFailureMark;
    var uploaded = false;
    for (final row in rows) {
      if (isStopped) return;
      final date = row['date'] as String;
      try {
        if (await _flushRow(row)) uploaded = true;
      } on StateError {
        return; /* DB closing */
      } catch (error, stackTrace) {
        // Jeden uszkodzony wiersz nie może zablokować wysyłki pozostałych.
        logUnexpected('Body weight $date sync failed', error, stackTrace);
      }
      if (networkFailedSince(networkMark)) break;
    }
    if (uploaded) {
      notifyDataChanged();
      _onUploaded?.call();
    }
  }

  Future<bool> _flushRow(Map<String, Object?> row) async {
    final date = row['date'] as String;
    final op = row['pending_op'] as String;
    final updatedAt = row['updated_at'] as int;
    final day = parseIsoDate(date);
    if (day == null) {
      throw FormatException('Invalid body weight date: $date');
    }

    if (op == 'delete') {
      try {
        await _remote.delete(day);
      } on ApiException catch (e) {
        await _handleFailure(date, op, e);
        return false;
      }
      // Nowy pomiar z tego dnia w trakcie żądania zostaje w kolejce.
      await _localDb.run(
        (db) => db.delete(
          _table,
          where: "date = ? AND updated_at = ? AND pending_op = 'delete'",
          whereArgs: [date, updatedAt],
        ),
      );
    } else {
      final double weight = (row['weight_kg'] as num).toDouble();
      final BodyWeightEntry saved;
      try {
        saved = await _remote.save(day, weight);
      } on ApiException catch (e) {
        await _handleFailure(date, op, e);
        return false;
      }
      // Serwer zaokrągla wagę; edycja w trakcie żądania wyśle się jeszcze raz.
      await _localDb.run(
        (db) => db.update(
          _table,
          {'weight_kg': saved.weightKg, 'pending_op': null, 'sync_error': null},
          where: 'date = ? AND updated_at = ?',
          whereArgs: [date, updatedAt],
        ),
      );
    }
    await _localDb.clearSyncAttempts(_attemptKey(date));
    return true;
  }

  // ── Pull ──────────────────────────────────────────────────────────────────

  Future<void> _pullImpl() async {
    if (isStopped) return;
    markPullAttempt();
    try {
      final entries = await _remote.list(limit: pullLimit);
      if (isStopped) return;
      final changed = await _localDb.run(
        (db) => db.transaction((txn) => _storePulled(txn, entries)),
      );
      await _localDb.writeSyncState(
        pulledAtKey,
        DateTime.now().toUtc().toIso8601String(),
      );
      if (changed) notifyDataChanged();
    } on ApiException catch (e) {
      registerFailure(e);
    } on StateError {
      /* DB closing */
    }
  }

  /// Zastępuje lokalne pomiary wersją z serwera. Wiersze z niewysłanymi
  /// zmianami zostają nietknięte. Zwraca, czy coś się zmieniło.
  Future<bool> _storePulled(
    Transaction txn,
    List<BodyWeightEntry> entries,
  ) async {
    final local = {
      for (final row in await txn.query(_table)) row['date'] as String: row,
    };
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    var changed = false;

    final serverDates = <String>{};
    for (final entry in entries) {
      final date = formatIsoDate(entry.date);
      serverDates.add(date);
      final existing = local[date];
      if (existing != null) {
        if (existing['pending_op'] != null) continue;
        if ((existing['weight_kg'] as num).toDouble() == entry.weightKg) {
          continue;
        }
      }
      await txn.insert(_table, {
        'date': date,
        'weight_kg': entry.weightKg,
        'updated_at': now,
        'pending_op': null,
        'sync_error': null,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      changed = true;
    }

    // Pełna lista — brak dnia na serwerze to usunięcie na innym urządzeniu.
    // Przy obciętej liście nie wiadomo nic o dniach starszych niż najstarszy
    // zwrócony, więc je zostawiamy.
    final truncated = entries.length >= pullLimit;
    final oldest = entries.isEmpty ? null : formatIsoDate(entries.first.date);
    final removed = <String>[
      for (final MapEntry(key: date, value: row) in local.entries)
        if (row['pending_op'] == null &&
            !serverDates.contains(date) &&
            (!truncated || oldest == null || date.compareTo(oldest) >= 0))
          date,
    ];
    for (final date in removed) {
      await txn.delete(_table, where: 'date = ?', whereArgs: [date]);
      changed = true;
    }
    return changed;
  }
}
