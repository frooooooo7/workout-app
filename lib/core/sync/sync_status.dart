import 'package:flutter/foundation.dart';

enum SyncPhase {
  /// Wszystko wysłane.
  idle,

  /// Trwa wysyłanie lub pobieranie.
  syncing,

  /// Są zmiany do wysłania, ostatnia próba nie wskazywała na brak sieci.
  pending,

  /// Są zmiany do wysłania, a serwer jest nieosiągalny.
  offline,

  /// Serwer odrzucił część zmian — wymaga uwagi użytkownika.
  error,
}

@immutable
class SyncStatus {
  const SyncStatus({
    this.phase = SyncPhase.idle,
    this.pendingCount = 0,
    this.failedCount = 0,
    this.lastSyncedAt,
  });

  final SyncPhase phase;

  /// Lokalne zmiany czekające na wysłanie.
  final int pendingCount;

  /// Zmiany odrzucone przez serwer (nie są ponawiane automatycznie).
  final int failedCount;

  /// Moment, w którym ostatnio wszystko było zsynchronizowane.
  final DateTime? lastSyncedAt;

  bool get isSyncing => phase == SyncPhase.syncing;

  SyncStatus copyWith({
    SyncPhase? phase,
    int? pendingCount,
    int? failedCount,
    DateTime? lastSyncedAt,
  }) {
    return SyncStatus(
      phase: phase ?? this.phase,
      pendingCount: pendingCount ?? this.pendingCount,
      failedCount: failedCount ?? this.failedCount,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SyncStatus &&
      other.phase == phase &&
      other.pendingCount == pendingCount &&
      other.failedCount == failedCount &&
      other.lastSyncedAt == lastSyncedAt;

  @override
  int get hashCode =>
      Object.hash(phase, pendingCount, failedCount, lastSyncedAt);
}
