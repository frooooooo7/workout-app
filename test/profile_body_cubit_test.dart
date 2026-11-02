import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/profile/domain/models/body_measurement_entry.dart';
import 'package:gym/features/profile/domain/models/body_weight_entry.dart';
import 'package:gym/features/profile/domain/repositories/body_measurements_repository.dart';
import 'package:gym/features/profile/domain/repositories/body_weight_repository.dart';
import 'package:gym/features/profile/presentation/bloc/profile_body_cubit.dart';

class _Weights implements BodyWeightRepository {
  _Weights(this.entries);
  List<BodyWeightEntry> entries;

  @override
  Future<List<BodyWeightEntry>> list({int limit = 1000}) async => entries;

  @override
  Future<BodyWeightEntry> save(DateTime date, double weightKg) =>
      throw UnimplementedError();

  @override
  Future<void> delete(DateTime date) => throw UnimplementedError();
}

class _Measurements implements BodyMeasurementsRepository {
  _Measurements(this.entries);
  List<BodyMeasurementEntry> entries;

  @override
  Future<List<BodyMeasurementEntry>> list({int limit = 1000}) async => entries;

  @override
  Future<BodyMeasurementEntry> save(BodyMeasurementEntry entry) =>
      throw UnimplementedError();

  @override
  Future<void> delete(DateTime date) => throw UnimplementedError();
}

BodyWeightEntry _w(int month, int day, double kg) =>
    BodyWeightEntry(date: DateTime(2026, month, day), weightKg: kg);

DateTime _now() => DateTime(2026, 11, 2, 12);

void main() {
  test(
    'latest weight and change against the oldest entry of 30 days',
    () async {
      final cubit = ProfileBodyCubit(
        weightRepository: _Weights([
          _w(8, 1, 90), // starszy niż 30 dni — pomijany
          _w(10, 5, 87),
          _w(10, 20, 86),
          _w(11, 1, 84.5),
        ]),
      );
      await cubit.load();

      expect(cubit.state?.weightKg, 84.5);
      expect(cubit.state?.weightDeltaKg, closeTo(-2.5, 1e-9));
      expect(cubit.state?.lastMeasurementOn, isNull);
      await cubit.close();
    },
  );

  test('a single weight entry has no change', () async {
    final cubit = ProfileBodyCubit(
      clock: _now,
      weightRepository: _Weights([_w(11, 1, 80)]),
    );
    await cubit.load();

    expect(cubit.state?.weightKg, 80);
    expect(cubit.state?.weightDeltaKg, isNull);
    await cubit.close();
  });

  test(
    'a last weigh-in older than 30 days has no change, only its date',
    () async {
      final cubit = ProfileBodyCubit(
        clock: _now,
        weightRepository: _Weights([_w(5, 10, 86), _w(6, 12, 84.5)]),
      );
      await cubit.load();

      expect(cubit.state?.weightKg, 84.5);
      expect(cubit.state?.weightOn, DateTime(2026, 6, 12));
      expect(cubit.state?.weightDeltaKg, isNull);
      await cubit.close();
    },
  );

  test('no data gives an empty summary', () async {
    final cubit = ProfileBodyCubit(
      weightRepository: _Weights(const []),
      measurementsRepository: _Measurements(const []),
    );
    await cubit.load();

    expect(cubit.state, const ProfileBodySummary());
    await cubit.close();
  });

  test('last measurement date comes from the newest entry', () async {
    final cubit = ProfileBodyCubit(
      measurementsRepository: _Measurements([
        BodyMeasurementEntry(
          date: DateTime(2026, 9, 1),
          values: {BodyMeasurementField.waist: 80},
        ),
        BodyMeasurementEntry(
          date: DateTime(2026, 10, 12),
          values: {BodyMeasurementField.waist: 79},
        ),
      ]),
    );
    await cubit.load();

    expect(cubit.state?.lastMeasurementOn, DateTime(2026, 10, 12));
    await cubit.close();
  });

  test('reloads when the weight data changes', () async {
    final changes = ValueNotifier<int>(0);
    final repo = _Weights([_w(11, 1, 80)]);
    final cubit = ProfileBodyCubit(
      clock: _now,
      weightRepository: repo,
      weightChanges: changes,
    );
    await cubit.load();
    repo.entries = [_w(11, 1, 80), _w(11, 2, 79)];
    changes.value++;
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state?.weightKg, 79);
    await cubit.close();
  });
}
