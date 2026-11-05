import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/notifications/presentation/unread_notifications.dart';

import 'support/fake_notifications_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DateTime now;
  late UnreadNotificationsCounter counter;

  setUp(() {
    now = DateTime(2026, 10, 14, 12);
    counter = UnreadNotificationsCounter(
      minInterval: const Duration(seconds: 20),
      pollInterval: const Duration(hours: 1),
      clock: () => now,
    );
  });

  tearDown(() => counter.dispose());

  test('attaching fetches the count, quick refreshes are skipped', () async {
    final repository = FakeNotificationsRepository(count: 3);
    counter.attach(repository);
    await pumpEventQueue();
    expect(counter.value, 3);

    repository.count = 5;
    await counter.refresh();
    expect(repository.countCalls, 1);

    now = now.add(const Duration(seconds: 21));
    await counter.refresh();
    expect(counter.value, 5);
    expect(repository.countCalls, 2);
  });

  test('a reply from the previous account is ignored', () async {
    final first = FakeNotificationsRepository()
      ..pendingCount = Completer<int>();
    counter.attach(first);

    counter.attach(null);
    first.pendingCount!.complete(7);
    await pumpEventQueue();

    expect(counter.value, 0);
  });

  test('a local update wins over an older request', () async {
    final repository = FakeNotificationsRepository()
      ..pendingCount = Completer<int>();
    counter.attach(repository);

    counter.set(0);
    repository.pendingCount!.complete(4);
    await pumpEventQueue();

    expect(counter.value, 0);
  });
}
