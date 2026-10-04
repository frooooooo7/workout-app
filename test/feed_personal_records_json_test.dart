import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/feed/data/feed_json.dart';
import 'package:gym/features/training/domain/models/training_stats.dart';

void main() {
  Map<String, dynamic> postJson(Object? personalRecords) => {
    'id': 's1',
    'author': {'id': 'u1', 'firstName': 'Anna', 'lastName': 'Nowak'},
    'title': 'Push A',
    'startedAt': '2026-09-15T16:05:00.000Z',
    'personalRecords': personalRecords,
  };

  test('parses personal records and skips unknown kinds', () {
    final post = FeedJson.postFromJson(
      postJson([
        {
          'exerciseName': 'Przysiad',
          'kinds': ['weight', 'oneRepMax'],
          'weightKg': 120,
          'reps': 5,
          'oneRepMaxKg': 140,
          'improvement': 5,
        },
        {
          'exerciseName': 'Pompki',
          'kinds': ['reps'],
          'reps': 40,
        },
        // Rodzaj, którego ta wersja aplikacji nie zna.
        {
          'exerciseName': 'Wiosłowanie',
          'kinds': ['volume'],
        },
        'zepsuty wpis',
      ]),
    );

    expect(post.personalRecords, hasLength(2));
    final squat = post.personalRecords.first;
    expect(squat.exerciseName, 'Przysiad');
    expect(squat.primaryKind, PersonalRecordKind.weight);
    expect(squat.weightKg, 120);
    expect(squat.reps, 5);
    expect(squat.improvement, 5);
    expect(squat.sessionId, 's1');
    expect(post.personalRecords.last.primaryKind, PersonalRecordKind.reps);
  });

  test('older API without the field yields no records', () {
    final post = FeedJson.postFromJson(postJson(null));
    expect(post.personalRecords, isEmpty);
  });

  test('cache round-trip keeps records', () {
    final post = FeedJson.postFromJson(
      postJson([
        {
          'exerciseName': 'Przysiad',
          'kinds': ['weight'],
          'weightKg': 120.5,
          'reps': 3,
          'improvement': 2.5,
        },
      ]),
    );
    final restored = FeedJson.postFromJson(FeedJson.postToJson(post));
    final record = restored.personalRecords.single;
    expect(record.exerciseName, 'Przysiad');
    expect(record.weightKg, 120.5);
    expect(record.reps, 3);
    expect(record.improvement, 2.5);
  });
}
