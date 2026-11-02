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
    this.weightDeltaKg,
    this.lastMeasurementOn,
  });

  /// `null`, gdy nie ma jeszcze żadnego pomiaru wagi.
  final double? weightKg;

  /// Różnica względem najstarszego pomiaru z ostatnich 30 dni; `null`, gdy
  /// nie ma z czym porównać.
  final double? weightDeltaKg;

  /// Dzień ostatniego wpisu pomiarów ciała; `null`, gdy nie ma żadnego.
  final DateTime? lastMeasurementOn;

  @override
  bool operator ==(Object other) =>
      other is ProfileBodySummary &&
      other.weightKg == weightKg &&
      other.weightDeltaKg == weightDeltaKg &&
      other.lastMeasurementOn == lastMeasurementOn;

  @override
  int get hashCode => Object.hash(weightKg, weightDeltaKg, lastMeasurementOn);
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
    double? weight;
    double? delta;
    DateTime? lastMeasurement;
    try {
      final entries = await weightRepository?.list(limit: 400);
      if (entries != null && entries.isNotEmpty) {
        final latest = entries.last;
        weight = latest.weightKg;
        final since = latest.date.subtract(const Duration(days: 30));
        for (final entry in entries) {
          if (entry.date.isBefore(since) || entry == latest) continue;
          delta = latest.weightKg - entry.weightKg;
          break;
        }
      }
    } catch (_) {
      // Skrót jest dodatkiem — bez danych kafelek zaprasza do dodania.
    }
    try {
      final entries = await measurementsRepository?.list(limit: 400);
      if (entries != null && entries.isNotEmpty) {
        lastMeasurement = entries.last.date;
      }
    } catch (_) {
      // j.w.
    }
    if (isClosed) return;
    emit(
      ProfileBodySummary(
        weightKg: weight,
        weightDeltaKg: delta,
        lastMeasurementOn: lastMeasurement,
      ),
    );
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
