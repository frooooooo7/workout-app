import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/sync/sync_status.dart';
import 'package:gym/core/utils/polish_plural.dart';
import 'package:gym/core/widgets/sync_status_indicator.dart';

void main() {
  Future<ValueNotifier<SyncStatus>> pumpIndicator(
    WidgetTester tester, {
    VoidCallback? onSyncRequested,
  }) async {
    final status = ValueNotifier(const SyncStatus());
    addTearDown(status.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SyncStatusIndicator(
              status: status,
              onSyncRequested: onSyncRequested,
            ),
          ),
        ),
      ),
    );
    return status;
  }

  testWidgets('spins while syncing and briefly confirms success', (tester) async {
    final status = await pumpIndicator(tester);
    expect(find.byIcon(Icons.cloud_done_outlined), findsOneWidget);

    status.value = const SyncStatus(phase: SyncPhase.syncing);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.sync_rounded), findsOneWidget);

    status.value = const SyncStatus(phase: SyncPhase.idle);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.cloud_done_rounded), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.cloud_done_outlined), findsOneWidget);
  });

  testWidgets('very short syncs do not flash the spinner', (tester) async {
    final status = await pumpIndicator(tester);

    status.value = const SyncStatus(phase: SyncPhase.syncing);
    await tester.pump(const Duration(milliseconds: 100));
    status.value = const SyncStatus(phase: SyncPhase.idle);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byIcon(Icons.sync_rounded), findsNothing);
    expect(find.byIcon(Icons.cloud_done_outlined), findsOneWidget);
  });

  testWidgets('offline state opens details with a sync action', (tester) async {
    var syncRequests = 0;
    final status = await pumpIndicator(
      tester,
      onSyncRequested: () => syncRequests++,
    );

    status.value = const SyncStatus(phase: SyncPhase.offline, pendingCount: 3);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);

    await tester.tap(find.byType(SyncStatusIndicator));
    await tester.pumpAndSettle();
    expect(find.text('Brak połączenia z serwerem'), findsOneWidget);
    expect(find.text('3 zmiany'), findsOneWidget);

    await tester.tap(find.text('Synchronizuj teraz'));
    await tester.pump();
    expect(syncRequests, 1);
  });

  test('polishPlural picks the right noun form', () {
    String changes(int n) => polishPlural(n, 'zmiana', 'zmiany', 'zmian');
    expect(changes(1), 'zmiana');
    expect(changes(2), 'zmiany');
    expect(changes(4), 'zmiany');
    expect(changes(5), 'zmian');
    expect(changes(12), 'zmian');
    expect(changes(22), 'zmiany');
    expect(changes(25), 'zmian');
  });
}
