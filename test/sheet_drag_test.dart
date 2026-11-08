import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/motion/sheet_drag.dart';

void main() {
  group('nextSheetOffset', () {
    test('tracks the finger 1:1 while the sheet is open', () {
      expect(nextSheetOffset(0, 40), 40);
      expect(nextSheetOffset(40, -15), 25);
    });

    test('rubber-bands above the resting position', () {
      expect(nextSheetOffset(0, -10), -2);
      expect(nextSheetOffset(-4, -10), -6);
    });

    test('returns from the rubber band 1:1 until rest, then tracks', () {
      expect(nextSheetOffset(-4, 10), -2);
      expect(nextSheetOffset(-4, 30), 10);
    });

    test('entering the rubber band keeps only the elastic part', () {
      expect(nextSheetOffset(20, -30), -2);
    });
  });

  group('shouldDismissSheet', () {
    test('a fast downward flick dismisses before half the travel', () {
      expect(
        shouldDismissSheet(offset: 24, travel: 400, velocity: 700),
        isTrue,
      );
    });

    test('passing half the travel dismisses without a flick', () {
      expect(shouldDismissSheet(offset: 200, travel: 400, velocity: 0), isTrue);
    });

    test('a short slow drag snaps back', () {
      expect(
        shouldDismissSheet(offset: 80, travel: 400, velocity: 200),
        isFalse,
      );
    });

    test('an upward flick does not dismiss', () {
      expect(
        shouldDismissSheet(offset: -8, travel: 400, velocity: 1200),
        isFalse,
      );
    });
  });
}
