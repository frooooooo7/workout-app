import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/auth/domain/models/auth_models.dart';
import 'package:gym/features/pro/domain/pro_trial.dart';
import 'package:gym/features/pro/presentation/screens/pro_trial_end_screen.dart';
import 'package:gym/features/pro/presentation/screens/pro_welcome_screen.dart';
import 'package:gym/features/pro/presentation/widgets/pro_trial_strip.dart';

void main() {
  final created = DateTime.utc(2026, 10, 1, 12);

  group('ProTrial', () {
    test('first day: 30 days left, not ending', () {
      final t = ProTrial.of(
        created,
        now: created.add(const Duration(hours: 1)),
      );
      expect(t.isActive, isTrue);
      expect(t.daysLeft, 30);
      expect(t.dayNumber, 1);
      expect(t.isEnding, isFalse);
    });

    test('last week is flagged as ending', () {
      final t = ProTrial.of(
        created,
        now: created.add(const Duration(days: 23)),
      );
      expect(t.daysLeft, 7);
      expect(t.dayNumber, 24);
      expect(t.isEnding, isTrue);
    });

    test('last day still counts as 1 day left', () {
      final t = ProTrial.of(
        created,
        now: created.add(const Duration(days: 29, hours: 20)),
      );
      expect(t.daysLeft, 1);
      expect(t.dayNumber, 30);
      expect(t.isActive, isTrue);
    });

    test('ended after 30 days', () {
      final t = ProTrial.of(
        created,
        now: created.add(const Duration(days: 30)),
      );
      expect(t.isEnded, isTrue);
      expect(t.isEnding, isFalse);
      expect(t.daysLeft, 0);
    });

    test('only the first days count as fresh', () {
      ProTrial at(int days) =>
          ProTrial.of(created, now: created.add(Duration(days: days)));
      expect(at(0).isFresh, isTrue);
      expect(at(2).isFresh, isTrue);
      expect(at(3).isFresh, isFalse);
      expect(at(40).isFresh, isFalse);
    });

    test('Polish days label', () {
      expect(proDaysLeftLabel(1), 'Został 1 dzień');
      expect(proDaysLeftLabel(2), 'Zostały 2 dni');
      expect(proDaysLeftLabel(5), 'Zostało 5 dni');
      expect(proDaysLeftLabel(7), 'Zostało 7 dni');
      expect(proDaysLeftLabel(12), 'Zostało 12 dni');
    });
  });

  group('AuthUser.createdAt', () {
    test('parses, serializes and survives copyWith', () {
      final user = AuthUser.fromJson({
        'id': 'u1',
        'email': 'a@b.c',
        'firstName': 'A',
        'lastName': 'B',
        'createdAt': '2026-10-01T12:00:00.000Z',
      });
      expect(user.createdAt, created);
      expect(user.toJson()['createdAt'], '2026-10-01T12:00:00.000Z');
      expect(user.copyWith(firstName: 'X').createdAt, created);
    });

    test('is null for older payloads', () {
      final user = AuthUser.fromJson({
        'id': 'u1',
        'email': 'a@b.c',
        'firstName': 'A',
        'lastName': 'B',
      });
      expect(user.createdAt, isNull);
      expect(user.toJson().containsKey('createdAt'), isFalse);
    });
  });

  group('screens', () {
    Future<void> pump(WidgetTester tester, Widget child) async {
      tester.view.physicalSize = const Size(780, 1688);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData.fromView(
              tester.view,
            ).copyWith(disableAnimations: true),
            child: child,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets('welcome shows the offer and closes on the button', (
      tester,
    ) async {
      var closed = 0;
      await pump(tester, ProWelcomeScreen(onClose: () => closed++));
      expect(find.text('PRO · 30 DNI ZA DARMO'), findsOneWidget);
      expect(find.text('Wykresy postępu'), findsOneWidget);
      expect(find.text('Pomiary ciała'), findsOneWidget);
      await tester.tap(find.text('Zaczynam'));
      expect(closed, 1);
    });

    testWidgets('info variant uses the "Rozumiem" button', (tester) async {
      await pump(tester, const ProWelcomeScreen(info: true));
      expect(find.text('Rozumiem'), findsOneWidget);
      expect(find.text('Zaczynam'), findsNothing);
    });

    testWidgets('end screen lists free and PRO features', (tester) async {
      var closed = 0;
      await pump(tester, ProTrialEndScreen(onClose: () => closed++));
      expect(find.text('ZOSTAJE ZA DARMO'), findsOneWidget);
      expect(find.text('W PRO'), findsOneWidget);
      await tester.tap(find.text('Zostań przy PRO'));
      await tester.pump();
      expect(find.textContaining('Subskrypcje pojawią się wkrótce'), findsOne);
      await tester.tap(find.text('Kontynuuj za darmo'));
      expect(closed, 1);
    });

    testWidgets('strip shows days left and reacts to tap', (tester) async {
      var taps = 0;
      final trial = ProTrial.of(
        created,
        now: created.add(const Duration(days: 25)),
      );
      await pump(
        tester,
        Scaffold(
          body: ProTrialStrip(trial: trial, onTap: () => taps++),
        ),
      );
      expect(find.textContaining('ZOSTAŁO 5 DNI'), findsOneWidget);
      expect(find.text('dzień 26 z 30'), findsOneWidget);
      await tester.tap(find.text('Zobacz PRO'));
      expect(taps, 1);
    });
  });
}
