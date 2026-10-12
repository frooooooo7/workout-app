import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/training/presentation/widgets/training_day_status.dart';

void main() {
  // Fixed "today": Wednesday 2026-07-29
  final today = DateTime(2026, 7, 29);

  group('isCalendarDateBefore', () {
    test('true for yesterday, false for today and tomorrow', () {
      expect(isCalendarDateBefore(DateTime(2026, 7, 28), today), isTrue);
      expect(isCalendarDateBefore(DateTime(2026, 7, 29), today), isFalse);
      expect(isCalendarDateBefore(DateTime(2026, 7, 30), today), isFalse);
    });
  });

  group('isCalendarDateAfter', () {
    test('true for tomorrow, false for today and yesterday', () {
      expect(isCalendarDateAfter(DateTime(2026, 7, 30), today), isTrue);
      expect(isCalendarDateAfter(DateTime(2026, 7, 29), today), isFalse);
      expect(isCalendarDateAfter(DateTime(2026, 7, 28), today), isFalse);
    });
  });
}
