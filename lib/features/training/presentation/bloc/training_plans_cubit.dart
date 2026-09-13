import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/models/custom_training_plan.dart';
import '../../domain/repositories/training_plan_repository.dart';

class TrainingPlansState {
  const TrainingPlansState({
    this.plans = const [],
    this.isLoading = false,
  });

  final List<CustomTrainingPlan> plans;
  final bool isLoading;

  TrainingPlansState copyWith({
    List<CustomTrainingPlan>? plans,
    bool? isLoading,
  }) {
    return TrainingPlansState(
      plans: plans ?? this.plans,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class TrainingPlansCubit extends Cubit<TrainingPlansState> {
  /// [dataChanges] — sygnał synchronizacji; plany pobrane z serwera pojawiają
  /// się bez ponownego wchodzenia na ekran.
  TrainingPlansCubit(this._repository, {Listenable? dataChanges})
    : _dataChanges = dataChanges,
      super(const TrainingPlansState()) {
    _dataChanges?.addListener(_onDataChanged);
    refresh();
  }

  final TrainingPlanRepository _repository;
  final Listenable? _dataChanges;

  @override
  Future<void> close() {
    _dataChanges?.removeListener(_onDataChanged);
    return super.close();
  }

  void _onDataChanged() {
    if (isClosed) return;
    unawaited(refresh(silent: true));
  }

  Future<void> refresh({bool silent = false}) async {
    if (isClosed) return;
    if (!silent) emit(state.copyWith(isLoading: true));
    try {
      final plans = await _repository.getAll();
      if (isClosed) return;
      emit(state.copyWith(isLoading: false, plans: plans));
    } catch (_) {
      // Baza bywa chwilowo zamknięta (np. przy wylogowaniu) — nie zostawiaj
      // wiecznego wskaźnika ładowania.
      if (isClosed) return;
      emit(state.copyWith(isLoading: false));
    }
  }

  /// History items reference the server plan id, which never equals the local
  /// id kept in [state], so the lookup has to go through the repository.
  Future<CustomTrainingPlan?> findPlan(String id) => _repository.getById(id);

  Future<void> addPlan(CustomTrainingPlan plan) async {
    final saved = await _repository.create(plan);
    final newPlans = List<CustomTrainingPlan>.from(state.plans)..add(saved);
    emit(state.copyWith(plans: newPlans));
  }

  Future<void> updatePlan(CustomTrainingPlan updatedPlan) async {
    final saved = await _repository.update(updatedPlan);
    final index = state.plans.indexWhere((p) => p.id == updatedPlan.id);
    if (index != -1) {
      final newPlans = List<CustomTrainingPlan>.from(state.plans);
      newPlans[index] = saved;
      emit(state.copyWith(plans: newPlans));
    }
  }

  Future<void> removePlan(String planId) async {
    await _repository.delete(planId);
    final newPlans = state.plans.where((p) => p.id != planId).toList();
    emit(state.copyWith(plans: newPlans));
  }
}
