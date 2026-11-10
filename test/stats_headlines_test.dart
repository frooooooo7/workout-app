import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:gym/features/training/domain/models/training_stats.dart';
import 'package:gym/features/training/presentation/widgets/stats/overview/stats_headlines.dart';

ExerciseProgress _exercise(String name, List<double> oneRepMax) =>
    ExerciseProgress(
      exerciseKey: name,
      exerciseName: name,
      exerciseId: name,
      sessions: oneRepMax.length,
      sets: oneRepMax.length * 3,
      volumeKg: 1000,
      points: [
        for (var i = 0; i < oneRepMax.length; i++)
          ExerciseProgressPoint(
            date: DateTime(2026, 8, 1 + i),
            sets: 3,
            volumeKg: 300,
            oneRepMaxKg: oneRepMax[i],
          ),
      ],
    );

ExerciseProgress _bodyweight(String name, List<int> reps) => ExerciseProgress(
  exerciseKey: name,
  exerciseName: name,
  exerciseId: name,
  sessions: reps.length,
  sets: reps.length * 3,
  volumeKg: 0,
  points: [
    for (var i = 0; i < reps.length; i++)
      ExerciseProgressPoint(
        date: DateTime(2026, 8, 1 + i),
        sets: 3,
        volumeKg: 0,
        maxReps: reps[i],
      ),
  ],
);

void main() {
  group('strength headline', () {
    test('counts the exercises that grew among the main ones', () {
      final trends = StatsHeadlines.strengthTrends([
        _exercise('Martwy ciąg', [160, 172]),
        _exercise('Przysiad', [120, 126]),
        _exercise('Wiosłowanie', [98, 98]),
      ]);
      expect(
        StatsHeadlines.strength(trends),
        'Rośniesz w 2 z 3 głównych ćwiczeń',
      );
    });

    test('everything growing reads as "we wszystkich"', () {
      final trends = StatsHeadlines.strengthTrends([
        _exercise('A', [100, 110]),
        _exercise('B', [50, 55]),
      ]);
      expect(
        StatsHeadlines.strength(trends),
        'Rośniesz we wszystkich 2 głównych ćwiczeniach',
      );
    });

    test('nothing growing and nothing comparable', () {
      expect(
        StatsHeadlines.strength(
          StatsHeadlines.strengthTrends([
            _exercise('A', [100, 100]),
          ]),
        ),
        'Bez wzrostu w głównych ćwiczeniach',
      );
      expect(
        StatsHeadlines.strength(
          StatsHeadlines.strengthTrends([
            _exercise('A', [100]),
          ]),
        ),
        isNull,
      );
    });

    test('only the eight most frequent exercises count', () {
      final trends = StatsHeadlines.strengthTrends([
        for (var i = 0; i < 12; i++) _exercise('E$i', [100, 110]),
      ]);
      expect(trends, hasLength(8));
    });

    test('trend labels: kg for weights, reps for bodyweight', () {
      final kg = StatsExerciseTrend.of(_exercise('Martwy ciąg', [160, 172]));
      expect(kg.currentLabel, 'szac. 1RM 172 kg');
      expect(kg.changeLabel, '12 kg');
      expect(kg.direction, 1);

      final reps = StatsExerciseTrend.of(_bodyweight('Podciąganie', [8, 11]));
      expect(reps.currentLabel, 'max 11 powt.');
      expect(reps.changeLabel, '3 powt.');
      expect(reps.direction, 1);

      final flat = StatsExerciseTrend.of(_exercise('A', [98, 98.02]));
      expect(flat.direction, 0);
    });
  });

  group('records headline', () {
    test('polish plural forms', () {
      expect(StatsHeadlines.records(0), 'Brak nowych rekordów');
      expect(StatsHeadlines.records(1), '1 ćwiczenie z rekordem');
      expect(StatsHeadlines.records(3), '3 ćwiczenia z rekordem');
      expect(StatsHeadlines.records(9), '9 ćwiczeń z rekordem');
      expect(StatsHeadlines.records(12), '12 ćwiczeń z rekordem');
    });
  });

  group('regularity headline', () {
    test('averages read naturally', () {
      expect(StatsHeadlines.perWeek(3.8), 'Średnio 3,8 treningu w tygodniu');
      expect(StatsHeadlines.perWeek(4), 'Średnio 4 treningi w tygodniu');
      expect(StatsHeadlines.perWeek(5), 'Średnio 5 treningów w tygodniu');
      expect(StatsHeadlines.perWeek(1), 'Średnio 1 trening w tygodniu');
      expect(StatsHeadlines.perWeek(null), isNull);
      expect(StatsHeadlines.perWeek(0), isNull);
    });

    test('favourite day and time of day', () {
      const habits = TrainingHabits(
        weekdayCounts: [4, 1, 0, 0, 0, 0, 0],
        timeOfDayCounts: {
          TrainingTimeOfDay.evening: 4,
          TrainingTimeOfDay.morning: 1,
        },
      );
      expect(
        StatsHeadlines.favorite(habits),
        'Najczęściej w poniedziałki, wieczorem',
      );
      expect(StatsHeadlines.favorite(TrainingHabits.empty), isNull);
    });

    test('streak pill', () {
      expect(StatsHeadlines.streak(7), '7 tyg.');
    });
  });

  group('muscles headline', () {
    MuscleDistribution distribution({List<MuscleGroup> neglected = const []}) =>
        MuscleDistribution(
          muscles: const [],
          regions: const [
            RegionStat(region: MuscleRegion.back, sets: 23, share: 0.23),
            RegionStat(region: MuscleRegion.legs, sets: 22, share: 0.22),
          ],
          neglected: neglected,
        );

    test('a skipped muscle comes first', () {
      expect(
        StatsHeadlines.muscles(distribution(neglected: [MuscleGroup.abs]), []),
        'Brzuch bez ani jednej serii w tym okresie',
      );
    });

    test('a long break is named in weeks', () {
      final recovery = [
        MuscleRecoveryStat(
          muscle: MuscleGroup.abs,
          lastTrainedAt: DateTime(2026, 8, 20),
          daysSince: 21,
          setsPerWeek: 0,
        ),
      ];
      expect(
        StatsHeadlines.muscles(
          distribution(neglected: [MuscleGroup.abs]),
          recovery,
        ),
        'Brzuch bez ani jednej serii od 3 tygodni',
      );
    });

    test('several skipped muscles are counted', () {
      expect(
        StatsHeadlines.muscles(
          distribution(neglected: [MuscleGroup.abs, MuscleGroup.glutes]),
          [],
        ),
        'Brzuch i Pośladki bez ani jednej serii',
      );
      expect(
        StatsHeadlines.muscles(
          distribution(
            neglected: [
              MuscleGroup.abs,
              MuscleGroup.glutes,
              MuscleGroup.calves,
            ],
          ),
          [],
        ),
        '3 mięśni bez ani jednej serii',
      );
    });

    test('nothing skipped names the busiest region', () {
      expect(
        StatsHeadlines.muscles(distribution(), []),
        'Najwięcej serii: Plecy · 23%',
      );
    });
  });
}
