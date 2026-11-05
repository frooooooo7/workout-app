import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/training/presentation/widgets/ongoing_workout/rest_timer_controller.dart';

void main() {
  group('RestTimerController', () {
    testWidgets('counts down from the wall clock, not from ticks', (
      tester,
    ) async {
      var now = DateTime(2026, 10, 14, 12);
      final rest = RestTimerController(clock: () => now);
      await rest.start(const Duration(seconds: 90));
      expect(rest.remaining.value, const Duration(seconds: 90));

      now = now.add(const Duration(seconds: 10));
      await tester.pump(const Duration(seconds: 10));
      expect(rest.remaining.value, const Duration(seconds: 80));

      // Zablokowany ekran: zegar idzie, timery stoją.
      now = now.add(const Duration(seconds: 45));
      rest.sync();
      expect(rest.remaining.value, const Duration(seconds: 35));
      expect(rest.isActive, isTrue);

      rest.dispose();
    });

    testWidgets('ends the rest on resume when it already ran out', (
      tester,
    ) async {
      var now = DateTime(2026, 10, 14, 12);
      final rest = RestTimerController(clock: () => now);
      await rest.start(const Duration(seconds: 60));

      now = now.add(const Duration(minutes: 3));
      rest.sync();
      expect(rest.isActive, isFalse);
      expect(rest.remaining.value, Duration.zero);

      rest.dispose();
    });

    testWidgets('catches up when the app comes back to the foreground', (
      tester,
    ) async {
      var now = DateTime(2026, 10, 14, 12);
      final rest = RestTimerController(clock: () => now);
      await rest.start(const Duration(seconds: 90));

      now = now.add(const Duration(seconds: 30));
      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(rest.remaining.value, const Duration(seconds: 60));

      rest.dispose();
    });

    testWidgets('+15 s moves the end time', (tester) async {
      var now = DateTime(2026, 10, 14, 12);
      final rest = RestTimerController(clock: () => now);
      await rest.start(const Duration(seconds: 30));

      now = now.add(const Duration(seconds: 20));
      await rest.extend(const Duration(seconds: 15));
      expect(rest.remaining.value, const Duration(seconds: 25));
      expect(rest.total, const Duration(seconds: 45));

      now = now.add(const Duration(seconds: 24));
      await tester.pump(const Duration(seconds: 1));
      expect(rest.remaining.value, const Duration(seconds: 1));

      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(rest.isActive, isFalse);

      rest.dispose();
    });

    testWidgets('stays on screen at 0:00 after the rest ends', (tester) async {
      var now = DateTime(2026, 10, 14, 12);
      final rest = RestTimerController(clock: () => now);
      await rest.start(const Duration(seconds: 30));
      expect(rest.isFinished, isFalse);
      expect(rest.isVisible, isTrue);

      now = now.add(const Duration(seconds: 31));
      await tester.pump(const Duration(milliseconds: 250));
      expect(rest.isActive, isFalse);
      expect(rest.isFinished, isTrue);
      expect(rest.isVisible, isTrue);
      expect(rest.remaining.value, Duration.zero);

      // „+15 s” po końcu przerwy odlicza jeszcze chwilę.
      await rest.extend(const Duration(seconds: 15));
      expect(rest.isActive, isTrue);
      expect(rest.isFinished, isFalse);
      expect(rest.remaining.value, const Duration(seconds: 15));
      expect(rest.selectedDuration, const Duration(seconds: 30));

      now = now.add(const Duration(seconds: 16));
      await tester.pump(const Duration(milliseconds: 250));
      expect(rest.isFinished, isTrue);

      // „OK” zamyka panel.
      rest.stop();
      expect(rest.isFinished, isFalse);
      expect(rest.isVisible, isFalse);

      // Kolejna przerwa też czyści stan końca.
      await rest.start(const Duration(seconds: 5));
      now = now.add(const Duration(seconds: 6));
      rest.sync();
      expect(rest.isFinished, isTrue);
      await rest.start(const Duration(seconds: 5));
      expect(rest.isFinished, isFalse);

      rest.dispose();
    });

    testWidgets('shows every second once with a running clock', (tester) async {
      final rest = RestTimerController(clock: () => tester.binding.clock.now());
      await rest.start(const Duration(seconds: 5));
      final seen = <int>[rest.remaining.value.inSeconds];
      rest.remaining.addListener(
        () => seen.add(rest.remaining.value.inSeconds),
      );

      for (var i = 0; i < 24; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(seen, [5, 4, 3, 2, 1, 0]);
      expect(rest.isActive, isFalse);

      rest.dispose();
    });
  });
}
