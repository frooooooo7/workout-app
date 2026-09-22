import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../training/domain/repositories/training_stats_repository.dart';
import '../../domain/services/profile_week_calculator.dart';

/// Podsumowanie bieżącego tygodnia na profilu, liczone z lokalnej historii
/// (działa bez sieci). `null` do pierwszego wczytania albo gdy się nie udało.
class ProfileWeekCubit extends Cubit<ProfileWeekSummary?> {
  ProfileWeekCubit(
    this._repository, {
    Listenable? dataChanges,
    DateTime Function()? clock,
  }) : _dataChanges = dataChanges,
       _clock = clock ?? DateTime.now,
       super(null) {
    _dataChanges?.addListener(_onDataChanged);
  }

  final TrainingStatsRepository _repository;
  final Listenable? _dataChanges;
  final DateTime Function() _clock;

  Future<void> load() async {
    try {
      final now = _clock();
      final sessions = await _repository.completedSessionsSince(
        ProfileWeekCalculator.earliestStart(now),
      );
      if (isClosed) return;
      emit(ProfileWeekCalculator.summarize(sessions, now: now));
    } catch (_) {
      // Podsumowanie jest dodatkiem — przy błędzie zostaje poprzedni stan.
    }
  }

  void _onDataChanged() {
    if (isClosed) return;
    unawaited(load());
  }

  @override
  Future<void> close() {
    _dataChanges?.removeListener(_onDataChanged);
    return super.close();
  }
}
