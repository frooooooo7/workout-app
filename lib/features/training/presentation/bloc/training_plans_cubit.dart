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
  TrainingPlansCubit(this._repository) : super(const TrainingPlansState()) {
    refresh();
  }

  final TrainingPlanRepository _repository;

  Future<void> refresh() async {
    emit(state.copyWith(isLoading: true));
    final plans = await _repository.getAll();
    emit(state.copyWith(isLoading: false, plans: plans));
  }

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
