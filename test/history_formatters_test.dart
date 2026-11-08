import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/training/presentation/widgets/workout_history/history_formatters.dart';

void main() {
  test('formats durations and counts', () {
    expect(formatHoursMinutes(52 * 60), '52 min');
    expect(formatHoursMinutes(62 * 60 + 30), '1 h 02 min');
    expect(formatWorkoutCount(1), '1 trening');
    expect(formatWorkoutCount(3), '3 treningi');
    expect(formatWorkoutCount(9), '9 treningów');
  });
}
