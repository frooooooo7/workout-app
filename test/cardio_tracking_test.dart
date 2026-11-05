import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/library/presentation/widgets/exercise_tracking_picker.dart';
import 'package:gym/features/training/domain/models/training_history_models.dart';
import 'package:gym/features/training/domain/models/training_session.dart';
import 'package:gym/features/training/domain/services/cardio_insights.dart';
import 'package:gym/features/training/presentation/widgets/ongoing_workout/cardio_stopwatch.dart';
import 'package:gym/features/training/presentation/widgets/session_details/session_details_formatters.dart';
import 'package:gym/features/training/presentation/widgets/session_details/session_exercise_card.dart';

TrainingSessionSet _segment(int? seconds, int? meters, {bool done = true}) =>
    TrainingSessionSet(
      actualDurationSeconds: seconds,
      actualDistanceM: meters,
      completed: done,
    );

TrainingSession _run(
  List<TrainingSessionSet> sets, {
  String name = 'Bieżnia',
}) => TrainingSession(
  planName: 'Kardio',
  status: TrainingSessionStatus.completed,
  exercises: [
    TrainingSessionExercise(
      exerciseId: 'treadmill',
      exerciseName: name,
      exerciseMuscles: const ['legs'],
      exerciseCategory: 'cardio',
      tracking: ExerciseTracking.durationDistance,
      sets: sets,
    ),
  ],
);

void main() {
  group('tracking mode', () {
    test('unknown or missing API value falls back to weight × reps', () {
      expect(ExerciseTracking.fromApi(null), ExerciseTracking.weightReps);
      expect(ExerciseTracking.fromApi('nope'), ExerciseTracking.weightReps);
      expect(
        ExerciseTracking.fromApi('duration_distance'),
        ExerciseTracking.durationDistance,
      );
      expect(DistanceUnit.fromApi('m'), DistanceUnit.m);
      expect(DistanceUnit.fromApi(null), DistanceUnit.km);
    });

    test('columns follow the mode', () {
      expect(ExerciseTracking.reps.tracksWeight, isFalse);
      expect(ExerciseTracking.reps.tracksReps, isTrue);
      expect(ExerciseTracking.duration.isCardio, isTrue);
      expect(ExerciseTracking.duration.tracksDistance, isFalse);
      expect(ExerciseTracking.weightReps.isCardio, isFalse);
    });
  });

  group('duration', () {
    test('formats as m:ss and h:mm:ss', () {
      expect(formatSetDuration(0), '0:00');
      expect(formatSetDuration(767), '12:47');
      expect(formatSetDuration(3723), '1:02:03');
    });

    test('parses clock text and plain minutes', () {
      expect(parseSetDuration('12:47'), 767);
      expect(parseSetDuration('1:02:03'), 3723);
      expect(parseSetDuration('15'), 900);
      expect(parseSetDuration('7,5'), 450);
      expect(parseSetDuration(''), isNull);
      expect(parseSetDuration('1:75'), isNull);
      expect(parseSetDuration('abc'), isNull);
      expect(parseSetDuration('25:00:00'), isNull);
    });
  });

  group('distance', () {
    test('km keeps up to two decimals with a comma, m stays whole', () {
      expect(DistanceUnit.km.format(2000), '2');
      expect(DistanceUnit.km.format(2100), '2,1');
      expect(DistanceUnit.km.format(2125), '2,13');
      expect(DistanceUnit.m.formatWithUnit(2000), '2000 m');
    });

    test('parses to metres', () {
      expect(DistanceUnit.km.parse('2,5'), 2500);
      expect(DistanceUnit.km.parse('2.5'), 2500);
      expect(DistanceUnit.m.parse('500'), 500);
      expect(DistanceUnit.km.parse('-1'), isNull);
      expect(DistanceUnit.km.parse('2000'), isNull);
    });

    test('pace is per km, or per 500 m for metres', () {
      expect(DistanceUnit.km.pace(seconds: 900, meters: 2500), '6:00');
      expect(DistanceUnit.m.pace(seconds: 480, meters: 2000), '2:00');
      expect(DistanceUnit.km.pace(seconds: 0, meters: 2500), isNull);
      expect(formatPacePerKm(360, DistanceUnit.km), '6:00 /km');
      expect(formatPacePerKm(240, DistanceUnit.m), '2:00 /500 m');
    });

    test('segment count is declined', () {
      expect(cardioSegmentsLabel(1), '1 odcinek');
      expect(cardioSegmentsLabel(3), '3 odcinki');
      expect(cardioSegmentsLabel(5), '5 odcinków');
      expect(cardioSegmentsLabel(12), '12 odcinków');
    });
  });

  group('cardio insights', () {
    test('totals count done segments, or all typed ones on request', () {
      final sets = [_segment(900, 2500), _segment(300, 800, done: false)];
      final done = cardioTotals(sets);
      expect((done.seconds, done.meters), (900, 2500));
      final typed = cardioTotals(sets, completedOnly: false);
      expect((typed.seconds, typed.meters), (1200, 3300));
      expect(
        formatCardioTotals(
          typed,
          ExerciseTracking.durationDistance,
          DistanceUnit.km,
          withPace: true,
        ),
        '3,3 km · 20:00 · 6:04 /km',
      );
      expect(
        formatCardioTotals(
          CardioTotals.zero,
          ExerciseTracking.durationDistance,
          DistanceUnit.km,
        ),
        isNull,
      );
    });

    test('best pace skips warm-ups and unfinished segments', () {
      final history = [
        _run([
          _segment(900, 2500),
          TrainingSessionSet(
            setType: SetType.warmup,
            actualDurationSeconds: 100,
            actualDistanceM: 1000,
            completed: true,
          ),
          _segment(100, 1000, done: false),
        ]),
        _run([_segment(1000, 3000)]),
      ];
      expect(bestPacesByExercise(history), {'name:bieżnia': 333});
    });

    test('last result of a cardio exercise is its totals', () {
      final exercise = _run([_segment(900, 2500)]).exercises.single;
      expect(
        formatCardioTotals(
          cardioTotals(exercise.sets),
          exercise.tracking,
          exercise.distanceUnit,
        ),
        '2,5 km · 15:00',
      );
    });
  });

  group('stopwatch', () {
    test('counts from a timestamp, pauses and hands the time to save', () {
      var now = DateTime(2026, 10, 14, 18);
      final stopwatch = CardioStopwatchController(clock: () => now);
      addTearDown(stopwatch.dispose);
      Duration? saved;

      stopwatch.start(
        'set-1',
        from: const Duration(seconds: 30),
        onSave: (value) => saved = value,
      );
      expect(stopwatch.isRunning, isTrue);
      now = now.add(const Duration(minutes: 2));
      expect(stopwatch.current, const Duration(minutes: 2, seconds: 30));

      stopwatch.pause();
      now = now.add(const Duration(minutes: 10));
      expect(stopwatch.current, const Duration(minutes: 2, seconds: 30));

      stopwatch.resume();
      now = now.add(const Duration(seconds: 15));
      stopwatch.save();

      expect(saved, const Duration(minutes: 2, seconds: 45));
      expect(stopwatch.isActive, isFalse);
      expect(stopwatch.elapsed.value, Duration.zero);
    });
  });

  group('history', () {
    const detail = TrainingExerciseDetail(
      exerciseId: 'treadmill',
      exerciseName: 'Bieżnia',
      tracking: ExerciseTracking.durationDistance,
      sets: [
        TrainingExerciseSetDetail(
          setIndex: 0,
          actual: TrainingSetMetrics(durationSeconds: 900, distanceM: 2500),
          completed: true,
        ),
        TrainingExerciseSetDetail(
          setIndex: 1,
          actual: TrainingSetMetrics(durationSeconds: 600, distanceM: 2000),
          completed: true,
        ),
        TrainingExerciseSetDetail(
          setIndex: 2,
          planned: TrainingSetMetrics(durationSeconds: 300),
          completed: false,
        ),
      ],
    );

    test('summary shows distance, time and pace of done segments', () {
      expect(detail.bestPaceSecondsPerKm, 300);
      expect(formatCardioSummary(detail), '4,5 km · 25:00 · 5:33 /km');
      expect(
        formatCardioSummary(
          const TrainingExerciseDetail(
            exerciseId: 'bench',
            exerciseName: 'Bench',
            sets: [],
          ),
        ),
        isNull,
      );
    });

    testWidgets('session card lists segments as time, distance and pace', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SessionExerciseCard(exercise: detail, index: 0),
            ),
          ),
        ),
      );

      expect(find.text('CZAS'), findsOneWidget);
      expect(find.text('DYSTANS'), findsOneWidget);
      expect(find.text('TEMPO'), findsOneWidget);
      expect(find.text('CIĘŻAR'), findsNothing);
      expect(find.text('2,5 km'), findsOneWidget);
      expect(find.text('6:00'), findsOneWidget);
      expect(find.text('Najlepsze tempo: 5:00 /km'), findsOneWidget);
      expect(find.textContaining('2/3 odcinki'), findsOneWidget);
    });
  });

  testWidgets('tracking picker switches mode and shows the unit for distance', (
    tester,
  ) async {
    var tracking = ExerciseTracking.weightReps;
    var unit = DistanceUnit.km;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) => ExerciseTrackingPicker(
                tracking: tracking,
                distanceUnit: unit,
                onTrackingChanged: (v) => setState(() => tracking = v),
                onDistanceUnitChanged: (v) => setState(() => unit = v),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('distance-unit-m')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('tracking-duration_distance')));
    await tester.pumpAndSettle();
    expect(tracking, ExerciseTracking.durationDistance);

    await tester.tap(find.byKey(const ValueKey('distance-unit-m')));
    await tester.pumpAndSettle();
    expect(unit, DistanceUnit.m);
    expect(
      find.byKey(const ValueKey('tracking-preview-duration_distance')),
      findsOneWidget,
    );
  });
}
