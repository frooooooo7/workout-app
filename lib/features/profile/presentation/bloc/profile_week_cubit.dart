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
    Future<int?> Function()? weeklyGoalLoader,
  }) : _weeklyGoalLoader = weeklyGoalLoader,
       _dataChanges = dataChanges,
       _clock = clock ?? DateTime.now,
       super(null) {
    _dataChanges?.addListener(_onDataChanged);
  }

  final TrainingStatsRepository _repository;
  final Listenable? _dataChanges;
  final DateTime Function() _clock;
  final Future<int?> Function()? _weeklyGoalLoader;

  static const _goalTimeout = Duration(seconds: 5);

  Future<void> load() async {
    try {
      final now = _clock();
      final sessions = await _repository.completedSessionsSince(
        ProfileWeekCalculator.earliestStart(now),
      );
      final goal = await _loadGoal();
      if (isClosed) return;
      emit(ProfileWeekCalculator.summarize(sessions, now: now, goal: goal));
    } catch (_) {
      // Podsumowanie jest dodatkiem — przy błędzie zostaje poprzedni stan.
    }
  }

  /// Passa liczy się od celu tygodniowego; bez niego (brak sieci i kopii
  /// profilu) wraca do „tygodnia z jakimkolwiek treningiem”.
  Future<int?> _loadGoal() async {
    final loader = _weeklyGoalLoader;
    if (loader == null) return null;
    try {
      return await loader().timeout(_goalTimeout);
    } catch (_) {
      return null;
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
