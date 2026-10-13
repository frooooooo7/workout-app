import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/network/api_client.dart';
import 'package:gym/features/profile/data/api_body_weight_repository.dart';
import 'package:gym/features/profile/domain/models/body_weight_entry.dart';
import 'package:gym/features/profile/domain/models/profile_details.dart';
import 'package:gym/features/profile/domain/models/profile_stats.dart';
import 'package:gym/features/profile/domain/models/user_profile.dart';
import 'package:gym/features/profile/domain/repositories/body_weight_repository.dart';
import 'package:gym/features/profile/domain/repositories/profile_repository.dart';
import 'package:gym/features/profile/domain/services/body_weight_trend.dart';
import 'package:gym/features/profile/presentation/bloc/body_weight_cubit.dart';
import 'package:gym/features/profile/presentation/utils/body_weight_format.dart';
import 'package:gym/features/profile/presentation/widgets/body_weight_chart.dart';

BodyWeightEntry _e(int month, int day, double kg) =>
    BodyWeightEntry(date: DateTime(2026, month, day), weightKg: kg);

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(baseUrl: 'http://test.local');

  final calls = <String>[];
  Map<String, dynamic>? lastBody;
  Object? response;
  ApiException? error;

  Future<dynamic> _respond(String key) async {
    calls.add(key);
    if (error != null) throw error!;
    return response;
  }

  @override
  Future<dynamic> get(String path, {bool auth = false}) =>
      _respond('GET $path');

  @override
  Future<dynamic> put(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) {
    lastBody = body;
    return _respond('PUT $path');
  }

  @override
  Future<dynamic> delete(String path, {bool auth = false}) =>
      _respond('DELETE $path');
}

class FakeBodyWeightRepository implements BodyWeightRepository {
  FakeBodyWeightRepository([List<BodyWeightEntry>? entries])
    : entries = [...?entries];

  List<BodyWeightEntry> entries;
  Object? listError;
  Object? saveError;
  Object? deleteError;
  final saved = <BodyWeightEntry>[];
  final deleted = <DateTime>[];

  @override
  Future<List<BodyWeightEntry>> list({int limit = 1000}) async {
    if (listError != null) throw listError!;
    return [...entries];
  }

  @override
  Future<BodyWeightEntry> save(DateTime date, double weightKg) async {
    if (saveError != null) throw saveError!;
    final entry = BodyWeightEntry(date: date, weightKg: weightKg);
    saved.add(entry);
    entries = [
      for (final e in entries)
        if (e.date != date) e,
      entry,
    ]..sort((a, b) => a.date.compareTo(b.date));
    return entry;
  }

  @override
  Future<void> delete(DateTime date) async {
    if (deleteError != null) throw deleteError!;
    deleted.add(date);
    entries = [
      for (final e in entries)
        if (e.date != date) e,
    ];
  }
}

/// Profil z celem masy ciała — tylko to, czego używa ekran masy ciała.
class FakeGoalProfileRepository extends Fake implements ProfileRepository {
  FakeGoalProfileRepository([this.goalKg]);

  double? goalKg;
  Object? error;
  final updates = <double?>[];

  UserProfile get _profile => UserProfile(
    id: 'me',
    firstName: 'Jan',
    lastName: 'Kowalski',
    handle: 'jan',
    stats: const ProfileStats(
      followingCount: 0,
      followersCount: 0,
      workoutsCount: 0,
    ),
    isOwnProfile: true,
    details: ProfileDetails(heightCm: 180, targetWeightKg: goalKg),
  );

  @override
  Future<UserProfile> getOwnProfile() async {
    if (error != null) throw error!;
    return _profile;
  }

  @override
  Future<UserProfile> updateTargetWeight(double? kg) async {
    if (error != null) throw error!;
    updates.add(kg);
    goalKg = kg;
    return _profile;
  }
}

void main() {
  group('body weight trend', () {
    final entries = [
      _e(8, 1, 88),
      _e(9, 10, 85.4),
      _e(9, 30, 84),
      _e(10, 3, 83.5),
    ];

    test('range start counts the end day itself', () {
      expect(
        BodyWeightRange.days30.startFor(DateTime(2026, 10, 4)),
        DateTime(2026, 9, 5),
      );
      expect(BodyWeightRange.all.startFor(DateTime(2026, 10, 4)), isNull);
    });

    test('filters entries by inclusive day bounds', () {
      expect(
        bodyWeightEntriesBetween(
          entries,
          start: DateTime(2026, 9, 10),
          end: DateTime(2026, 9, 30),
        ),
        [_e(9, 10, 85.4), _e(9, 30, 84)],
      );
      expect(bodyWeightEntriesBetween(entries), entries);
    });

    test('change is last minus first, rounded to 0.1 kg', () {
      final trend = bodyWeightTrend(entries.sublist(1))!;
      expect(trend.first, _e(9, 10, 85.4));
      expect(trend.changeKg, -1.9);
      expect(bodyWeightTrend([_e(9, 1, 80)]), isNull);
    });

    test('smoothed trend follows the entries without their noise', () {
      final noisy = [
        _e(9, 1, 84),
        _e(9, 2, 85),
        _e(9, 3, 83.8),
        _e(9, 4, 84.9),
        _e(9, 5, 83.7),
      ];
      final trend = bodyWeightSmoothedTrend(noisy);
      expect(trend.first, 84);
      expect(trend, hasLength(5));
      for (final t in trend) {
        expect(t, inInclusiveRange(84, 84.5));
      }
      // Po długiej przerwie trend prawie dogania nowy pomiar.
      final gap = bodyWeightSmoothedTrend([_e(6, 1, 90), _e(9, 1, 80)]);
      expect(gap.last, closeTo(80, 0.01));
    });

    test('recent average uses the 7 days ending with the last entry', () {
      expect(
        bodyWeightRecentAverage([
          _e(9, 1, 90),
          _e(9, 24, 82),
          _e(9, 28, 81),
          _e(9, 30, 80),
        ]),
        81,
      );
      expect(bodyWeightRecentAverage(const []), isNull);
    });

    test('weekly pace is the fitted slope over the last 4 weeks', () {
      final steady = [
        for (var d = 0; d <= 21; d += 3)
          BodyWeightEntry(
            date: DateTime(2026, 9, 1 + d),
            weightKg: 85 - d * 0.5 / 7,
          ),
      ];
      expect(bodyWeightWeeklyPace(steady), closeTo(-0.5, 1e-9));
      // Mniej niż tydzień danych — bez tempa.
      expect(bodyWeightWeeklyPace([_e(9, 1, 80), _e(9, 5, 79)]), isNull);
    });

    test('goal progress, direction and projected date', () {
      const losing = BodyWeightGoalProgress(
        startKg: 84.9,
        currentKg: 81.3,
        goalKg: 80,
      );
      expect(losing.fraction, closeTo(0.735, 0.001));
      expect(losing.remainingKg, closeTo(1.3, 1e-9));
      expect(losing.reached, isFalse);
      expect(losing.isTowardGoal(-0.4), isTrue);
      expect(losing.isTowardGoal(0.4), isFalse);

      const gaining = BodyWeightGoalProgress(
        startKg: 70,
        currentKg: 76,
        goalKg: 75,
      );
      expect(gaining.reached, isTrue);
      expect(gaining.fraction, 1);
      expect(gaining.remainingKg, 0);

      final from = DateTime(2026, 10, 12);
      expect(
        bodyWeightGoalDate(
          fromKg: 81.5,
          goalKg: 80,
          pacePerWeekKg: -0.5,
          from: from,
        ),
        DateTime(2026, 11, 2),
      );
      // Trend w złą stronę albo w miejscu — bez prognozy.
      expect(
        bodyWeightGoalDate(
          fromKg: 81.5,
          goalKg: 80,
          pacePerWeekKg: 0.3,
          from: from,
        ),
        isNull,
      );
      expect(
        bodyWeightGoalDate(
          fromKg: 81.5,
          goalKg: 80,
          pacePerWeekKg: 0,
          from: from,
        ),
        isNull,
      );
    });

    test('groups entries into weeks with average and change', () {
      final weeks = bodyWeightWeeks([
        _e(9, 28, 82),
        _e(10, 1, 81.6),
        _e(10, 4, 81.8),
        _e(10, 6, 81.4),
        _e(10, 9, 81.2),
        _e(10, 12, 81.3),
      ]);
      expect(
        [for (final w in weeks) w.start],
        [DateTime(2026, 10, 12), DateTime(2026, 10, 5), DateTime(2026, 9, 28)],
      );
      expect(weeks.last.averageKg, closeTo(81.8, 1e-9));
      expect(weeks.last.changeKg, isNull);
      expect(weeks[1].entries, [_e(10, 9, 81.2), _e(10, 6, 81.4)]);
      expect(weeks[1].changeKg, -0.5);
      expect(weeks.first.changeKg, 0);
    });

    test('screen labels', () {
      final today = DateTime(2026, 10, 12);
      expect(formatBodyWeightEyebrow(today, today), 'DZIŚ · 12 PAŹ');
      expect(
        formatBodyWeightEyebrow(DateTime(2026, 10, 9), today),
        'PT · 9 PAŹ',
      );
      expect(
        formatBodyWeightWeek(DateTime(2026, 10, 12), DateTime(2026, 10, 18)),
        '12–18 paź',
      );
      expect(
        formatBodyWeightWeek(DateTime(2026, 9, 28), DateTime(2026, 10, 4)),
        '28 wrz – 4 paź',
      );
      expect(formatBodyWeightCount(1), '1 pomiar');
      expect(formatBodyWeightCount(42), '42 pomiary');
      expect(formatBodyWeightCount(15), '15 pomiarów');
      expect(formatBodyWeightPace(-0.44), '−0,4');
      expect(formatBodyWeightPace(0.2), '+0,2');
      expect(formatBodyWeightGoalDate(DateTime(2027, 2, 3), today), 'lut 2027');
    });

    test('formats signed changes', () {
      expect(formatWeightChange(-1.9), '−1,9 kg');
      expect(formatWeightChange(2), '+2 kg');
      expect(formatWeightChange(0), '0 kg');
    });
  });

  group('ApiBodyWeightRepository', () {
    test('lists entries sorted oldest first', () async {
      final api = _FakeApiClient()
        ..response = {
          'entries': [
            {'date': '2026-10-01', 'weightKg': 81},
            {'date': '2026-09-01', 'weightKg': 82.5},
          ],
        };
      final entries = await ApiBodyWeightRepository(api).list(limit: 50);
      expect(api.calls, ['GET /profile/me/body-weight?limit=50']);
      expect(entries, [_e(9, 1, 82.5), _e(10, 1, 81)]);
    });

    test('saves by local calendar day', () async {
      final api = _FakeApiClient()
        ..response = {'date': '2026-10-04', 'weightKg': 80.2};
      final entry = await ApiBodyWeightRepository(
        api,
      ).save(DateTime(2026, 10, 4), 80.2);
      expect(api.calls, ['PUT /profile/me/body-weight/2026-10-04']);
      expect(api.lastBody, {'weightKg': 80.2});
      expect(entry, _e(10, 4, 80.2));
    });

    test('treats a missing entry on delete as done', () async {
      final api = _FakeApiClient()
        ..error = const ApiException('entry_not_found', statusCode: 404);
      await ApiBodyWeightRepository(api).delete(DateTime(2026, 10, 4));
      expect(api.calls, ['DELETE /profile/me/body-weight/2026-10-04']);

      api.error = const ApiException('network_error');
      expect(
        () => ApiBodyWeightRepository(api).delete(DateTime(2026, 10, 4)),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('BodyWeightCubit', () {
    test('loads entries and reports offline load errors', () async {
      final repo = FakeBodyWeightRepository([_e(9, 1, 82)]);
      final cubit = BodyWeightCubit(repo);
      await cubit.load();
      expect(cubit.state.entries, [_e(9, 1, 82)]);
      expect(cubit.state.latest, _e(9, 1, 82));

      repo.listError = const ApiException('network_error');
      await cubit.load();
      expect(cubit.state.offline, isTrue);
      expect(cubit.state.loadError, contains('Brak połączenia'));
      // Wczytane wcześniej pomiary zostają.
      expect(cubit.state.entries, [_e(9, 1, 82)]);
    });

    test('save replaces the same day and keeps the list sorted', () async {
      var changes = 0;
      final repo = FakeBodyWeightRepository([_e(9, 1, 82), _e(10, 1, 81)]);
      final cubit = BodyWeightCubit(repo, onChanged: () => changes++);
      await cubit.load();

      expect(await cubit.save(DateTime(2026, 9, 15), 81.5), isTrue);
      expect(await cubit.save(DateTime(2026, 10, 1), 80.6), isTrue);

      expect(cubit.state.entries, [
        _e(9, 1, 82),
        _e(9, 15, 81.5),
        _e(10, 1, 80.6),
      ]);
      expect(cubit.state.message, 'Zapisano pomiar.');
      expect(changes, 2);
    });

    test('save failure keeps entries and explains why', () async {
      final repo = FakeBodyWeightRepository([_e(9, 1, 82)])
        ..saveError = const ApiException('network_error');
      final cubit = BodyWeightCubit(repo);
      await cubit.load();
      final before = cubit.state.messageId;

      expect(await cubit.save(DateTime(2026, 9, 2), 81), isFalse);
      expect(cubit.state.entries, [_e(9, 1, 82)]);
      expect(cubit.state.saving, isFalse);
      expect(cubit.state.message, contains('nie został zapisany'));
      expect(cubit.state.messageId, before + 1);
    });

    test('loads the goal from the profile and saves or clears it', () async {
      final profile = FakeGoalProfileRepository(80);
      final cubit = BodyWeightCubit(
        FakeBodyWeightRepository([_e(9, 1, 82)]),
        profile: profile,
      );
      await cubit.load();
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.goalLoaded, isTrue);
      expect(cubit.state.goalKg, 80);

      expect(await cubit.saveGoal(78.5), isTrue);
      expect(cubit.state.goalKg, 78.5);
      expect(cubit.state.message, 'Zapisano cel.');

      expect(await cubit.saveGoal(null), isTrue);
      expect(cubit.state.goalKg, isNull);
      expect(profile.updates, [78.5, null]);
    });

    test('without the profile offline the goal stays unknown', () async {
      final profile = FakeGoalProfileRepository(80)
        ..error = const ApiException('network_error');
      final cubit = BodyWeightCubit(
        FakeBodyWeightRepository([_e(9, 1, 82)]),
        profile: profile,
      );
      await cubit.load();
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.entries, [_e(9, 1, 82)]);
      expect(cubit.state.goalLoaded, isFalse);

      expect(await cubit.saveGoal(79), isFalse);
      expect(cubit.state.message, 'Brak połączenia — cel nie został zapisany.');
      expect(cubit.state.savingGoal, isFalse);
    });

    test('delete removes at once and restores on failure', () async {
      final repo = FakeBodyWeightRepository([_e(9, 1, 82), _e(10, 1, 81)]);
      final cubit = BodyWeightCubit(repo);
      await cubit.load();

      repo.deleteError = const ApiException('network_error');
      expect(await cubit.delete(_e(10, 1, 81)), isFalse);
      expect(cubit.state.entries, [_e(9, 1, 82), _e(10, 1, 81)]);

      repo.deleteError = null;
      expect(await cubit.delete(_e(10, 1, 81)), isTrue);
      expect(cubit.state.entries, [_e(9, 1, 82)]);
      expect(repo.deleted, [DateTime(2026, 10, 1)]);
    });
  });

  group('logProfileWeightChange', () {
    final now = DateTime(2026, 10, 4, 23, 50);

    test('logs a changed weight for today', () async {
      final repo = FakeBodyWeightRepository();
      await logProfileWeightChange(
        repo,
        previous: 80,
        current: 81.5,
        clock: () => now,
      );
      expect(repo.saved, [_e(10, 4, 81.5)]);
    });

    test('skips unchanged or cleared weight and swallows errors', () async {
      final repo = FakeBodyWeightRepository();
      await logProfileWeightChange(repo, previous: 80, current: 80);
      await logProfileWeightChange(repo, previous: 80, current: null);
      await logProfileWeightChange(null, previous: 80, current: 81);
      expect(repo.saved, isEmpty);

      repo.saveError = const ApiException('network_error');
      await logProfileWeightChange(repo, previous: null, current: 70);
    });
  });
}
