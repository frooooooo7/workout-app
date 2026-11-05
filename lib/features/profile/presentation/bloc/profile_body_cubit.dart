import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/body_measurements_repository.dart';
import '../../domain/repositories/body_weight_repository.dart';

/// Skrót danych o ciele na profilu: ostatnia waga ze zmianą w ostatnich
/// 30 dniach i data ostatnich pomiarów obwodów.
@immutable
class ProfileBodySummary {
  const ProfileBodySummary({
    this.weightKg,
    this.weightOn,
    this.weightDeltaKg,
    this.lastMeasurementOn,
  });

  /// `null`, gdy nie ma jeszcze żadnego pomiaru wagi.
  final double? weightKg;

  /// Dzień ostatniego pomiaru wagi.
  final DateTime? weightOn;

  /// Zmiana wagi w ostatnich 30 dniach (liczonych od dziś): różnica między
  /// ostatnim pomiarem a najstarszym z tego okna. `null`, gdy ostatni pomiar
  /// jest starszy niż 30 dni albo nie ma z czym porównać.
  final double? weightDeltaKg;

  /// Dzień ostatniego wpisu pomiarów ciała; `null`, gdy nie ma żadnego.
  final DateTime? lastMeasurementOn;

  @override
  bool operator ==(Object other) =>
      other is ProfileBodySummary &&
      other.weightKg == weightKg &&
      other.weightOn == weightOn &&
      other.weightDeltaKg == weightDeltaKg &&
      other.lastMeasurementOn == lastMeasurementOn;

  @override
  int get hashCode =>
      Object.hash(weightKg, weightOn, weightDeltaKg, lastMeasurementOn);
}

/// Stan kafelków „Masa ciała” i „Pomiary” na profilu, liczony z lokalnych
/// danych (działa bez sieci). `null` do pierwszego wczytania.
class ProfileBodyCubit extends Cubit<ProfileBodySummary?> {
  ProfileBodyCubit({
    this.weightRepository,
    this.measurementsRepository,
    Listenable? weightChanges,
    Listenable? measurementsChanges,
    DateTime Function()? clock,
  }) : _weightChanges = weightChanges,
       _measurementsChanges = measurementsChanges,
       _clock = clock ?? DateTime.now,
       super(null) {
    _weightChanges?.addListener(_onChanged);
    _measurementsChanges?.addListener(_onChanged);
  }

  final BodyWeightRepository? weightRepository;
  final BodyMeasurementsRepository? measurementsRepository;
  final Listenable? _weightChanges;
  final Listenable? _measurementsChanges;
  final DateTime Function() _clock;

  Future<void> load() async {
    // Oba odczyty idą równolegle — każdy może czekać na pierwsze pobranie.
    final results = await Future.wait([_readWeight(), _readLastMeasurement()]);
    if (isClosed) return;
    final weight = results[0] as _WeightReading?;
    emit(
      ProfileBodySummary(
        weightKg: weight?.kg,
        weightOn: weight?.on,
        weightDeltaKg: weight?.delta,
        lastMeasurementOn: results[1] as DateTime?,
      ),
    );
  }

  Future<_WeightReading?> _readWeight() async {
    try {
      final entries = await weightRepository?.list(limit: 400);
      if (entries == null || entries.isEmpty) return null;
      final latest = entries.last;
      final windowStart = today.subtract(const Duration(days: 30));
      double? delta;
      // Ostatni pomiar sprzed okna: zmiana „w 30 dni” byłaby nieprawdziwa.
      if (!latest.date.isBefore(windowStart)) {
        for (final entry in entries) {
          if (entry.date.isBefore(windowStart) || entry == latest) continue;
          delta = latest.weightKg - entry.weightKg;
          break;
        }
      }
      return _WeightReading(latest.weightKg, latest.date, delta);
    } catch (_) {
      // Skrót jest dodatkiem — bez danych kafelek zaprasza do dodania.
      return null;
    }
  }

  Future<DateTime?> _readLastMeasurement() async {
    try {
      // Lista to najnowsze N wpisów od najstarszego, więc ostatni jest
      // najnowszy; wystarczy jeden.
      final entries = await measurementsRepository?.list(limit: 1);
      if (entries == null || entries.isEmpty) return null;
      return entries.last.date;
    } catch (_) {
      return null;
    }
  }

  void _onChanged() {
    if (isClosed) return;
    unawaited(load());
  }

  /// Dzień „dziś” (lokalna północ) — do podpisów względnych.
  DateTime get today {
    final now = _clock();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  Future<void> close() {
    _weightChanges?.removeListener(_onChanged);
    _measurementsChanges?.removeListener(_onChanged);
    return super.close();
  }
}

class _WeightReading {
  const _WeightReading(this.kg, this.on, this.delta);

  final double kg;
  final DateTime on;
  final double? delta;
}
