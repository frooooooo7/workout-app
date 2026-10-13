import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/network/api_client.dart';
import 'package:gym/core/theme/app_colors.dart';
import 'package:gym/features/body_highlighter/data/body_highlighter_asset_loader.dart';
import 'package:gym/features/body_highlighter/models/body_gender.dart';
import 'package:gym/features/body_highlighter/models/body_view.dart';
import 'package:gym/features/library/data/exercise_database.dart';
import 'package:gym/features/profile/data/api_body_measurements_repository.dart';
import 'package:gym/features/profile/data/offline_first_body_measurements_repository.dart';
import 'package:gym/features/profile/data/sync/body_measurements_sync_engine.dart';
import 'package:gym/features/profile/domain/models/body_measurement_entry.dart';
import 'package:gym/features/profile/domain/models/profile_details.dart';
import 'package:gym/features/profile/domain/repositories/body_measurements_repository.dart';
import 'package:gym/features/profile/presentation/bloc/body_measurements_cubit.dart';
import 'package:gym/features/profile/presentation/screens/body_measurements_screen.dart';
import 'package:gym/features/profile/presentation/utils/body_measurement_comparison.dart';
import 'package:gym/features/profile/presentation/utils/body_measurement_format.dart';
import 'package:gym/features/profile/presentation/utils/body_measurement_trend.dart';
import 'package:gym/features/profile/presentation/widgets/body_fat_summary.dart';
import 'package:gym/features/profile/presentation/widgets/body_measurement_change_card.dart';
import 'package:gym/features/profile/presentation/widgets/body_measurement_chart.dart';
import 'package:gym/features/profile/presentation/widgets/body_measurement_compare_pill.dart';
import 'package:gym/features/profile/presentation/widgets/body_measurement_compare_sheet.dart';
import 'package:gym/features/profile/presentation/widgets/body_measurement_entry_sheet.dart';
import 'package:gym/features/profile/presentation/widgets/body_measurement_entry_tile.dart';
import 'package:gym/features/profile/presentation/widgets/body_measurement_silhouette.dart';
import 'package:gym/features/profile/presentation/widgets/body_measurement_trend_card.dart';
import 'package:gym/features/profile/presentation/widgets/body_measurements_empty_state.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _waist = BodyMeasurementField.waist;
const _chest = BodyMeasurementField.chest;
const _fat = BodyMeasurementField.bodyFat;
const _arm = BodyMeasurementField.arm;

BodyMeasurementEntry _e(
  int month,
  int day,
  Map<BodyMeasurementField, double> values,
) => BodyMeasurementEntry(date: DateTime(2026, month, day), values: values);

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

/// Serwer w pamięci, jak `/profile/me/body-measurements`; służy też jako
/// repozytorium dla kubita i ekranu.
class _FakeRepository implements BodyMeasurementsRepository {
  _FakeRepository([List<BodyMeasurementEntry>? entries]) {
    for (final e in entries ?? const <BodyMeasurementEntry>[]) {
      server[formatIsoDate(e.date)] = e;
    }
  }

  final server = <String, BodyMeasurementEntry>{};
  final saved = <BodyMeasurementEntry>[];
  final deleted = <DateTime>[];
  bool offline = false;
  Object? listError;
  Object? saveError;

  void _checkNetwork() {
    if (offline) throw const ApiException('network_error');
  }

  @override
  Future<List<BodyMeasurementEntry>> list({int limit = 1000}) async {
    _checkNetwork();
    if (listError != null) throw listError!;
    final dates = server.keys.toList()..sort();
    return [for (final d in dates) server[d]!];
  }

  @override
  Future<BodyMeasurementEntry> save(BodyMeasurementEntry entry) async {
    _checkNetwork();
    if (saveError != null) throw saveError!;
    saved.add(entry);
    server[formatIsoDate(entry.date)] = entry;
    return entry;
  }

  @override
  Future<void> delete(DateTime date) async {
    _checkNetwork();
    deleted.add(date);
    server.remove(formatIsoDate(date));
  }
}

void main() {
  group('BodyMeasurementEntry', () {
    test('reads only measured values and writes all keys back', () {
      final entry = BodyMeasurementEntry.fromJson({
        'date': '2026-10-01',
        'waistCm': 84.5,
        'chestCm': null,
        'bodyFatPct': 15,
      });
      expect(entry.values, {_waist: 84.5, _fat: 15.0});
      expect(entry.toJson(), {
        'waistCm': 84.5,
        'chestCm': null,
        'hipsCm': null,
        'neckCm': null,
        'armCm': null,
        'thighCm': null,
        'calfCm': null,
        'bodyFatPct': 15.0,
      });
      expect(entry, _e(10, 1, {_fat: 15, _waist: 84.5}));
    });

    test('series skips entries without the measurement', () {
      final series = bodyMeasurementSeries([
        _e(9, 1, {_waist: 86}),
        _e(9, 15, {_chest: 100}),
        _e(10, 1, {_waist: 84.5}),
      ], _waist);
      expect([for (final s in series) s.value], [86, 84.5]);
    });

    test('formats values and signed changes', () {
      expect(formatMeasurement(_waist, 84.5), '84,5 cm');
      expect(formatMeasurement(_fat, 15), '15%');
      expect(formatMeasurementChange(_waist, -1.5), '−1,5 cm');
      expect(formatMeasurementChange(_fat, 0.4), '+0,4%');
      expect(parseMeasurementInput(' 84,5 '), 84.5);
      expect(parseMeasurementInput(''), isNull);
      expect(parseMeasurementInput('8,4,5')!.isNaN, isTrue);
    });
  });

  group('ApiBodyMeasurementsRepository', () {
    test(
      'lists sorted, saves the whole day and ignores missing deletes',
      () async {
        final api = _FakeApiClient()
          ..response = {
            'entries': [
              {'date': '2026-10-01', 'waistCm': 84},
              {'date': '2026-09-01', 'waistCm': 86},
            ],
          };
        final repo = ApiBodyMeasurementsRepository(api);

        final entries = await repo.list();
        expect(entries.map((e) => e.date.month), [9, 10]);
        expect(api.calls.last, 'GET /profile/me/body-measurements?limit=1000');

        api.response = {'date': '2026-10-04', 'waistCm': 84.3};
        final saved = await repo.save(_e(10, 4, {_waist: 84.3}));
        expect(saved, _e(10, 4, {_waist: 84.3}));
        expect(api.calls.last, 'PUT /profile/me/body-measurements/2026-10-04');
        expect(api.lastBody!['waistCm'], 84.3);
        expect(api.lastBody!.containsKey('chestCm'), isTrue);

        api.error = const ApiException('entry_not_found', statusCode: 404);
        await repo.delete(DateTime(2026, 10, 4));
        expect(
          api.calls.last,
          'DELETE /profile/me/body-measurements/2026-10-04',
        );
      },
    );
  });

  group('offline sync', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    late Directory dir;
    late ExerciseDatabase db;
    late _FakeRepository remote;
    late BodyMeasurementsSyncEngine sync;
    late OfflineFirstBodyMeasurementsRepository repo;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('gym_bm');
      db = ExerciseDatabase('bm.db', directoryOverride: dir.path);
      remote = _FakeRepository();
      sync = BodyMeasurementsSyncEngine(remote: remote, localDb: db);
      repo = OfflineFirstBodyMeasurementsRepository(
        localDb: db,
        syncEngine: sync,
        clock: () => DateTime(2026, 10, 4, 12),
      );
    });

    tearDown(() async {
      sync.stop();
      await sync.flush();
      await db.close();
      await dir.delete(recursive: true);
    });

    test('save offline is listed at once and sent after reconnect', () async {
      remote.offline = true;

      final saved = await repo.save(_e(10, 4, {_waist: 84.26, _fat: 15}));
      expect(saved, _e(10, 4, {_waist: 84.3, _fat: 15}));
      expect(await repo.list(), [saved]);
      await sync.flush();
      expect((await db.countSyncBacklog()).pending, 1);

      remote.offline = false;
      await sync.flush();

      expect(remote.server.values, [saved]);
      expect((await db.countSyncBacklog()).pending, 0);
    });

    test('rejects empty, out of range and future entries locally', () async {
      expect(
        () => repo.save(_e(10, 4, {})),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'no_measurements',
          ),
        ),
      );
      expect(
        () => repo.save(_e(10, 4, {_fat: 80})),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'invalid_measurement',
          ),
        ),
      );
      expect(
        () => repo.save(_e(10, 5, {_waist: 80})),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'invalid_date',
          ),
        ),
      );
    });

    test(
      'delete offline hides the entry and removes it on the server',
      () async {
        remote.server['2026-10-03'] = _e(10, 3, {_waist: 85});
        remote.server['2026-10-04'] = _e(10, 4, {_waist: 84});
        await sync.pull();
        remote.offline = true;

        await repo.delete(DateTime(2026, 10, 3));
        expect(await repo.list(), [
          _e(10, 4, {_waist: 84}),
        ]);

        remote.offline = false;
        await sync.flush();
        expect(remote.server.keys, ['2026-10-04']);
        expect((await db.countSyncBacklog()).pending, 0);
      },
    );

    test(
      'pull keeps unsent changes and applies the server elsewhere',
      () async {
        remote.server['2026-10-01'] = _e(10, 1, {_waist: 86});
        remote.server['2026-10-02'] = _e(10, 2, {_waist: 85});
        await sync.pull();
        remote.offline = true;
        await repo.save(_e(10, 2, {_waist: 84, _chest: 101}));

        // Inne urządzenie: nowy wpis, zmiana 2.10 (lokalnie niewysłana),
        // usunięcie 1.10.
        remote.server['2026-10-03'] = _e(10, 3, {_fat: 16});
        remote.server['2026-10-02'] = _e(10, 2, {_waist: 90});
        remote.server.remove('2026-10-01');
        remote.offline = false;
        await sync.pull();

        expect(await repo.list(), [
          _e(10, 2, {_waist: 84, _chest: 101}),
          _e(10, 3, {_fat: 16}),
        ]);

        await sync.flush();
        expect(
          remote.server['2026-10-02'],
          _e(10, 2, {_waist: 84, _chest: 101}),
        );
      },
    );

    test('v13 database gains the body measurements table', () async {
      final path = p.join(dir.path, 'v13.db');
      final fresh = ExerciseDatabase('v13.db', directoryOverride: dir.path);
      await fresh.run(
        (d) => d.execute(
          'DROP TABLE ${ExerciseDatabase.tableBodyMeasurementEntries}',
        ),
      );
      await fresh.close();
      final raw = await openDatabase(path);
      await raw.setVersion(13);
      await raw.close();

      final upgraded = ExerciseDatabase('v13.db', directoryOverride: dir.path);
      await upgraded.run(
        (d) => d.insert(ExerciseDatabase.tableBodyMeasurementEntries, {
          'date': '2026-10-04',
          'waist_cm': 84.0,
          'updated_at': 1,
          'pending_op': 'upsert',
        }),
      );
      expect(await upgraded.countSyncBacklog(), (pending: 1, failed: 0));
      await upgraded.close();
    });
  });

  group('BodyMeasurementsCubit', () {
    test(
      'selects a measured field and keeps the list sorted on save',
      () async {
        final repo = _FakeRepository([
          _e(9, 1, {_chest: 100}),
        ]);
        final cubit = BodyMeasurementsCubit(repo);
        await cubit.load();
        expect(cubit.state.selectedField, _chest);

        await cubit.save(_e(8, 1, {_chest: 102}));
        expect(cubit.state.entries!.map((e) => e.date.month), [8, 9]);
        expect(cubit.state.message, 'Zapisano pomiary.');
        await cubit.close();
      },
    );

    test('save failure explains the range', () async {
      final repo = _FakeRepository()
        ..saveError = const ApiException(
          'invalid_measurement',
          statusCode: 400,
        );
      final cubit = BodyMeasurementsCubit(repo);
      await cubit.load();
      expect(await cubit.save(_e(10, 1, {_waist: 5})), isFalse);
      expect(
        cubit.state.message,
        'Obwody: 10–300 cm, tkanka tłuszczowa: 2–75%.',
      );
      await cubit.close();
    });
  });

  group('trend and comparison', () {
    test('colors a change by the goal of the measurement', () {
      expect(measurementTrend(_waist, -1), MeasurementTrend.good);
      expect(measurementTrend(_waist, 0.5), MeasurementTrend.bad);
      expect(measurementTrend(_fat, -0.4), MeasurementTrend.good);
      expect(measurementTrend(_arm, 1.3), MeasurementTrend.good);
      expect(measurementTrend(_chest, -1), MeasurementTrend.bad);
      expect(
        measurementTrend(BodyMeasurementField.neck, 1),
        MeasurementTrend.neutral,
      );
      expect(measurementTrend(_arm, 0), MeasurementTrend.neutral);
      expect(MeasurementTrend.good.color, AppColors.success);
    });

    test('compares first with latest unless two entries are picked', () {
      final entries = [
        _e(8, 1, {_waist: 88, _arm: 38}),
        _e(9, 1, {_waist: 86.5, _chest: 101}),
        _e(10, 1, {_waist: 85, _chest: 100}),
      ];
      final all = BodyMeasurementComparison.of(entries)!;
      expect(all.from, DateTime(2026, 8, 1));
      expect(all.deltas[_waist], (value: 85.0, change: -3.0));
      expect(all.deltas[_chest], (value: 100.0, change: -1.0));
      // Ramię zmierzone raz — wartość bez zmiany.
      expect(all.deltas[_arm], (value: 38.0, change: null));

      final picked = BodyMeasurementComparison.of(
        entries,
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 10, 1),
      )!;
      expect(picked.deltas[_waist], (value: 85.0, change: -1.5));
      expect(picked.deltas.containsKey(_arm), isFalse);

      // Usunięty wpis — wraca do pierwszego z ostatnim.
      final missing = BodyMeasurementComparison.of(
        entries,
        from: DateTime(2026, 8, 15),
        to: DateTime(2026, 10, 1),
      )!;
      expect(missing.from, DateTime(2026, 8, 1));
      expect(BodyMeasurementComparison.of(const []), isNull);
      expect(BodyMeasurementComparison.of([entries.first])!.hasRange, isFalse);
    });

    test('formats fixed values, deltas and dates', () {
      expect(formatMeasurementFixed(39), '39,0');
      expect(formatMeasurementDelta(1.3), '+1,3');
      expect(formatMeasurementDelta(-3.5), '−3,5');
      expect(formatMeasurementDelta(0), '0,0');
      final today = DateTime(2026, 10, 12);
      expect(formatMeasurementDate(DateTime(2026, 8, 3), today), '3 sie');
      expect(formatMeasurementDate(DateTime(2025, 8, 3), today), '3 sie 2025');
    });
  });

  group('BodyMeasurementsScreen', () {
    DateTime now() => DateTime(2026, 10, 4, 9);

    Future<void> pump(WidgetTester tester, _FakeRepository repo) async {
      await tester.binding.setSurfaceSize(const Size(430, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      // Rysunek sylwetki wczytuje się z assetów poza zegarem testu.
      await tester.runAsync(
        () => BodyHighlighterAssetLoader.instance.loadModelData(
          BodyGender.male,
          BodyView.front,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider(
            create: (_) => BodyMeasurementsCubit(repo),
            child: BodyMeasurementsScreen(clock: now),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Finder label(BodyMeasurementField field, String text) => find.descendant(
      of: find.byKey(bodyMeasurementLabelKey(field)),
      matching: find.text(text),
    );

    Finder changeRow(BodyMeasurementField field) =>
        find.byKey(bodyMeasurementChangeRowKey(field));

    final history = [
      _e(8, 1, {_waist: 88, _fat: 18, _arm: 38}),
      _e(9, 1, {_waist: 86.5, _chest: 101, _arm: 38.5}),
      _e(10, 1, {_waist: 85, _fat: 16.5, _arm: 39, _chest: 100}),
    ];

    testWidgets('compares the first and latest entry on the silhouette', (
      tester,
    ) async {
      await pump(tester, _FakeRepository(history));

      expect(
        find.descendant(
          of: find.byKey(bodyMeasurementComparePillKey),
          matching: find.text('1 sie'),
        ),
        findsOneWidget,
      );
      expect(label(_waist, '85,0 −3,0'), findsOneWidget);
      expect(label(_arm, '39,0 +1,0'), findsOneWidget);
      expect(label(_chest, '100,0 −1,0'), findsOneWidget);
      expect(
        find.byKey(bodyMeasurementLabelKey(BodyMeasurementField.neck)),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(bodyFatSummaryKey),
          matching: find.text('16,5%'),
        ),
        findsOneWidget,
      );
      expect(find.text('↓ 1,5'), findsOneWidget);

      expect(find.text('Zmiana od 1 sie'), findsOneWidget);
      expect(changeRow(_waist), findsOneWidget);
      expect(changeRow(_chest), findsOneWidget);
      // Tłuszcz ma własne miejsce nad sylwetką.
      expect(changeRow(_fat), findsNothing);
      expect(
        tester.getTopLeft(changeRow(_waist)).dy,
        lessThan(tester.getTopLeft(changeRow(_arm)).dy),
      );
      expect(find.text('3 wpisy · wykresy i edycja wpisów'), findsOneWidget);
    });

    testWidgets('picks the compared entries from the sheet', (tester) async {
      await pump(tester, _FakeRepository(history));

      await tester.tap(find.byKey(bodyMeasurementComparePillKey));
      await tester.pumpAndSettle();
      expect(find.text('Porównaj pomiary'), findsOneWidget);
      await tester.tap(
        find.byKey(
          bodyMeasurementCompareDateKey(from: true, date: DateTime(2026, 9, 1)),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(bodyMeasurementCompareApplyKey));
      await tester.pumpAndSettle();

      expect(find.text('Zmiana od 1 wrz'), findsOneWidget);
      expect(label(_waist, '85,0 −1,5'), findsOneWidget);
      expect(label(_chest, '100,0 −1,0'), findsOneWidget);
      // Tłuszczu nie mierzono 1 wrz — sama wartość.
      expect(find.text('↓ 1,5'), findsNothing);
    });

    testWidgets('a single entry shows values without a comparison', (
      tester,
    ) async {
      await pump(
        tester,
        _FakeRepository([
          _e(10, 1, {_waist: 84.5}),
        ]),
      );

      expect(label(_waist, '84,5'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsNothing);
      expect(changeRow(_waist), findsNothing);
      expect(
        find.text(
          'Dodaj kolejne pomiary, a zobaczysz tu, jak zmienia się '
          'każdy obwód.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('adds measurements from the sheet', (tester) async {
      final repo = _FakeRepository();
      await pump(tester, repo);
      expect(find.text('Brak pomiarów'), findsOneWidget);

      await tester.tap(find.byKey(bodyMeasurementsEmptyAddKey));
      await tester.pumpAndSettle();
      expect(find.text('Nowe pomiary'), findsOneWidget);

      // Pusty formularz — komunikat zamiast zapisu.
      await tester.tap(find.byKey(bodyMeasurementSheetSaveKey));
      await tester.pumpAndSettle();
      expect(find.text('Wpisz co najmniej jeden pomiar.'), findsOneWidget);

      await tester.enterText(
        find.byKey(bodyMeasurementFieldKey(_waist)),
        '84,5',
      );
      await tester.enterText(find.byKey(bodyMeasurementFieldKey(_fat)), '90');
      await tester.tap(find.byKey(bodyMeasurementSheetSaveKey));
      await tester.pumpAndSettle();
      expect(find.text('Od 2 do 75%'), findsOneWidget);

      await tester.enterText(find.byKey(bodyMeasurementFieldKey(_fat)), '15');
      await tester.tap(find.byKey(bodyMeasurementSheetSaveKey));
      await tester.pumpAndSettle();

      expect(repo.saved, [
        _e(10, 4, {_waist: 84.5, _fat: 15}),
      ]);
      expect(find.text('Zapisano pomiary.'), findsOneWidget);
      expect(label(_waist, '84,5'), findsOneWidget);

      // Kolejne pomiary z przycisku w nagłówku.
      await tester.tap(find.byKey(bodyMeasurementsAddButtonKey));
      await tester.pumpAndSettle();
      expect(find.text('Nowe pomiary'), findsOneWidget);
    });

    testWidgets('history shows the chart and edits or deletes entries', (
      tester,
    ) async {
      final repo = _FakeRepository(history);
      await pump(tester, repo);

      // Dotknięcie obwodu otwiera jego wykres.
      await tester.tap(find.byKey(bodyMeasurementLabelKey(_waist)));
      await tester.pumpAndSettle();
      expect(find.text('Historia pomiarów'), findsOneWidget);
      expect(find.byType(BodyMeasurementChart), findsOneWidget);
      expect(find.text('−3 cm od 1 sie'), findsOneWidget);

      await tester.tap(find.byKey(bodyMeasurementFieldChipKey(_fat)));
      await tester.pumpAndSettle();
      expect(find.text('−1,5% od 1 sie'), findsOneWidget);

      // Klatkę zmierzono dwa razy — wystarczy na wykres.
      await tester.tap(find.byKey(bodyMeasurementFieldChipKey(_chest)));
      await tester.pumpAndSettle();
      expect(find.byType(BodyMeasurementChart), findsOneWidget);

      final latest = find.byKey(bodyMeasurementEntryKey(DateTime(2026, 10, 1)));
      expect(
        find.descendant(of: latest, matching: find.text('16,5%')),
        findsOneWidget,
      );

      await tester.tap(
        find.descendant(of: latest, matching: find.byTooltip('Więcej')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Usuń pomiary'));
      await tester.pumpAndSettle();

      expect(repo.deleted, [DateTime(2026, 10, 1)]);
      expect(find.text('1 października 2026'), findsNothing);

      // Ekran główny porównuje teraz z nowym ostatnim wpisem.
      await tester.tap(find.byTooltip('Wstecz'));
      await tester.pumpAndSettle();
      expect(label(_waist, '86,5 −1,5'), findsOneWidget);
    });
  });
}
