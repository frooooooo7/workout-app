import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/training/presentation/widgets/workout_summary/share_workout_sheet.dart';

void main() {
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showShareWorkoutSheet(
                context,
                planName: 'Push',
                statsLine: '40 min · 4 serie',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('the handle follows the finger and snaps back', (tester) async {
    await open(tester);

    final surface = find.byKey(const ValueKey('share-sheet-surface'));
    final before = tester.getTopLeft(surface).dy;
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('share-sheet-handle'))),
    );
    await gesture.moveBy(const Offset(0, 90));
    await tester.pump();

    expect(tester.getTopLeft(surface).dy, closeTo(before + 90, 1));

    await gesture.up();
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(surface).dy, closeTo(before, 1));
    expect(find.byType(ShareWorkoutSheet), findsOneWidget);
  });

  testWidgets('a downward flick closes an empty sheet', (tester) async {
    await open(tester);

    await tester.fling(
      find.byKey(const ValueKey('share-sheet-handle')),
      const Offset(0, 280),
      1400,
    );
    await tester.pumpAndSettle();

    expect(find.byType(ShareWorkoutSheet), findsNothing);
  });

  testWidgets('a flick on a draft asks instead of throwing it away', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(
      find.byKey(const ValueKey('share-sheet-title')),
      'Szkic',
    );
    await tester.pump();

    await tester.fling(
      find.byKey(const ValueKey('share-sheet-handle')),
      const Offset(0, 280),
      1400,
    );
    await tester.pumpAndSettle();

    expect(find.text('Odrzucić post?'), findsOneWidget);
    expect(find.text('Szkic'), findsOneWidget);
  });

  testWidgets('catching the sheet mid-close keeps it open', (tester) async {
    await open(tester);

    final handle = find.byKey(const ValueKey('share-sheet-handle'));
    await tester.fling(handle, const Offset(0, 280), 900);
    await tester.pump(const Duration(milliseconds: 40));
    expect(find.byType(ShareWorkoutSheet), findsOneWidget);

    final gesture = await tester.startGesture(tester.getCenter(handle));
    await gesture.moveBy(const Offset(0, -30));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.byType(ShareWorkoutSheet), findsOneWidget);
  });
}
