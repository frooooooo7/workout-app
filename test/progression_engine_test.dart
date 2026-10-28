import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/units/weight_unit.dart';
import 'package:gym/features/training/data/progression_settings_store.dart';
import 'package:gym/features/training/domain/models/custom_training_plan.dart';
import 'package:gym/features/training/domain/models/progression_settings.dart';
import 'package:gym/features/training/domain/models/training_session.dart';
import 'package:gym/features/training/domain/services/progression_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

TrainingSessionSet _done(String weight, String reps, {String? rir}) =>
    TrainingSessionSet(
      actualWeight: weight,
      actualReps: reps,
      actualRir: rir,
      completed: true,
    );

TrainingSessionSet _todo(String planned) =>
    TrainingSessionSet(plannedReps: planned);

const _fixed = ProgressionSettings(method: ProgressionMethod.fixed);

class _FakeRemote implements ProgressionSettingsRemote {
  _FakeRemote({this.stored, this.failSave = false});

  ProgressionSettings? stored;
  bool failSave;
  int saves = 0;

  @override
  Future<ProgressionSettings?> fetch() async => stored;

  @override
  Future<void> save(ProgressionSettings settings) async {
    saves++;
    if (failSave) throw StateError('offline');
    stored = settings;
  }
}

void main() {
  setUp(() => WeightUnits.notifier.value = WeightUnit.kg);

  group('methods', () {
    test('off: repeats the last weight, no tag', () {
      final hint = progressionHintFor(_todo('8'), _done('60', '8'));
      expect(hint?.weightKg, 60);
      expect(hint?.isIncrease, isFalse);
      expect(hint?.reps, isNull);
    });

    test('fixed: +step when all reps were done, bigger step for legs', () {
      final settings = _fixed.copyWith(step: 1.25, legStep: 5);
      expect(
        progressionHintFor(
          _todo('8'),
          _done('60', '8'),
          settings: settings,
        )?.weightKg,
        61.25,
      );
      expect(
        progressionHintFor(
          _todo('5'),
          _done('100', '5'),
          settings: settings,
          legs: true,
        )?.weightKg,
        105,
      );
      expect(
        progressionHintFor(
          _todo('8'),
          _done('60', '7'),
          settings: settings,
        )?.isIncrease,
        isFalse,
      );
    });

    test('fixed in pounds: 5 lb stays exactly 5 lb', () {
      const settings = ProgressionSettings(
        method: ProgressionMethod.fixed,
        unit: WeightUnit.lb,
        step: 5,
      );
      final lastKg = WeightUnit.lb.toKg(135);
      final hint = progressionHintFor(
        _todo('8'),
        _done('$lastKg', '8'),
        settings: settings,
      );
      expect(WeightUnit.lb.fromKg(hint!.weightKg), closeTo(140, 0.01));
    });

    test('percent: rounds to the plate step, at least one step', () {
      const settings = ProgressionSettings(
        method: ProgressionMethod.percent,
        percent: 2.5,
        step: 1.25,
      );
      // 60 × 1,025 = 61,5 → 61,25.
      expect(
        progressionHintFor(
          _todo('8'),
          _done('60', '8'),
          settings: settings,
        )?.weightKg,
        61.25,
      );
      // 20 × 1,025 = 20,5 → zaokrąglone do 20 — wtedy minimum jeden krok.
      expect(
        progressionHintFor(
          _todo('8'),
          _done('20', '8'),
          settings: settings,
        )?.weightKg,
        21.25,
      );
    });

    test('double: reps first, then weight and back to the bottom', () {
      const settings = ProgressionSettings(
        method: ProgressionMethod.doubleProgression,
        step: 2,
      );
      final more = progressionHintFor(
        _todo('8-12'),
        _done('10', '10'),
        settings: settings,
      );
      expect(more?.weightKg, 10);
      expect(more?.reps, 11);
      expect(more?.repsDelta, 1);
      expect(more?.addsReps, isTrue);

      final up = progressionHintFor(
        _todo('8-12'),
        _done('10', '12'),
        settings: settings,
      );
      expect(up?.weightKg, 12);
      expect(up?.reps, 8);
      expect(up?.addsReps, isFalse);
    });

    test('double without a range behaves like a fixed step', () {
      const settings = ProgressionSettings(
        method: ProgressionMethod.doubleProgression,
      );
      final hint = progressionHintFor(
        _todo('8'),
        _done('60', '8'),
        settings: settings,
      );
      expect(hint?.weightKg, 62.5);
      expect(hint?.reps, isNull);
    });

    test('RIR: raises with enough reps in reserve, falls back to reps', () {
      const settings = ProgressionSettings(method: ProgressionMethod.rir);
      expect(
        progressionHintFor(
          _todo('8'),
          _done('60', '8', rir: '3'),
          settings: settings,
        )?.weightKg,
        62.5,
      );
      expect(
        progressionHintFor(
          _todo('8'),
          _done('60', '8', rir: '0'),
          settings: settings,
        )?.weightKg,
        60,
      );
      expect(
        progressionHintFor(
          _todo('8'),
          _done('60', '8'),
          settings: settings,
        )?.weightKg,
        62.5,
      );
    });
  });

  group('history', () {
    test('two successful workouts in a row before a raise', () {
      final settings = _fixed.copyWith(sessionsToIncrease: 2);
      expect(
        progressionHintFor(
          _todo('8'),
          _done('60', '8'),
          settings: settings,
          earlier: [_done('57,5', '8')],
        )?.isIncrease,
        isFalse,
        reason: 'the earlier workout was at a lower weight',
      );
      expect(
        progressionHintFor(
          _todo('8'),
          _done('60', '8'),
          settings: settings,
          earlier: [_done('60', '8')],
        )?.weightKg,
        62.5,
      );
    });

    test('deload after three failed workouts at the same weight', () {
      final settings = _fixed.copyWith(deload: true);
      final hint = progressionHintFor(
        _todo('5'),
        _done('100', '3'),
        settings: settings,
        earlier: [_done('100', '4'), _done('100', '3')],
      );
      expect(hint?.weightKg, 90);
      expect(hint?.isDeload, isTrue);
      expect(hint?.deltaKg, -10);

      expect(
        progressionHintFor(
          _todo('5'),
          _done('100', '3'),
          settings: settings,
          earlier: [_done('100', '5'), _done('100', '3')],
        )?.isDeload,
        isFalse,
      );
      expect(
        progressionHintFor(
          _todo('5'),
          _done('100', '3'),
          settings: _fixed,
          earlier: [_done('100', '4'), _done('100', '3')],
        )?.isDeload,
        isFalse,
        reason: 'deload is off by default',
      );
    });
  });

  group('settings', () {
    test('JSON round trip and defaults for missing fields', () {
      const settings = ProgressionSettings(
        method: ProgressionMethod.doubleProgression,
        unit: WeightUnit.lb,
        step: 5,
        legStep: 10,
        percent: 1,
        rirThreshold: 3,
        sessionsToIncrease: 2,
        deload: true,
      );
      expect(
        ProgressionSettings.fromJson(jsonDecode(jsonEncode(settings.toJson()))),
        settings,
      );
      expect(settings.toJson()['method'], 'double');
      expect(
        ProgressionSettings.fromJson({'method': 'fixed'}),
        const ProgressionSettings(method: ProgressionMethod.fixed),
      );
      expect(ProgressionSettings.fromJson(null), isNull);
    });

    test('unit change converts the step to the nearest preset', () {
      final lb = _fixed.copyWith(legStep: 5).inUnit(WeightUnit.lb);
      expect(lb.unit, WeightUnit.lb);
      expect(lb.step, 5);
      expect(lb.legStep, 10);
      expect(lb.summary, 'Stały krok · +5 lb');
    });

    test('a plan with an old step keeps it as its own fixed step', () {
      final plan = CustomTrainingPlan(name: 'FBW', progressionStepKg: 1.25);
      expect(plan.planProgression, ProgressionSettings.legacyStep(1.25));
      expect(plan.style.progression?.method, ProgressionMethod.fixed);
      expect(CustomTrainingPlan(name: 'FBW').planProgression, isNull);
    });
  });

  group('store', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('loads the account setting from the server and caches it', () async {
      final remote = _FakeRemote(stored: _fixed);
      final store = ProgressionSettingsStore();
      await store.attach('u1', remote);
      expect(store.current, _fixed);

      // Offline start: the cached copy is used.
      final offline = ProgressionSettingsStore();
      await offline.attach('u1', null);
      expect(offline.current, _fixed);
    });

    test('unsent change wins over the server on the next start', () async {
      final remote = _FakeRemote(failSave: true);
      final store = ProgressionSettingsStore();
      await store.attach('u1', remote);
      expect(store.current, ProgressionSettings.off);

      await store.set(_fixed);
      await store.idle;
      expect(remote.stored, isNull);

      remote.failSave = false;
      final next = ProgressionSettingsStore();
      await next.attach('u1', remote);
      expect(next.current, _fixed);
      expect(remote.stored, _fixed);
    });

    test('logout resets to off; accounts do not share settings', () async {
      final store = ProgressionSettingsStore();
      await store.attach('u1', _FakeRemote(stored: _fixed));
      await store.attach(null, null);
      expect(store.current, ProgressionSettings.off);
      await store.attach('u2', _FakeRemote());
      expect(store.current, ProgressionSettings.off);
    });
  });
}
