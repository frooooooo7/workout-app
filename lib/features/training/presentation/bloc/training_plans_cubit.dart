import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/models/custom_training_plan.dart';

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
  TrainingPlansCubit() : super(const TrainingPlansState()) {
    _loadPlans();
  }

  void _loadPlans() {
    emit(state.copyWith(isLoading: true));
    // Symulacja ładowania (np. z bazy danych)
    Future.delayed(const Duration(milliseconds: 500), () {
      emit(state.copyWith(
        isLoading: false,
        plans: [], // Na start pusta lista
      ));
    });
  }

  void addPlan(CustomTrainingPlan plan) {
    final newPlans = List<CustomTrainingPlan>.from(state.plans)..add(plan);
    emit(state.copyWith(plans: newPlans));
  }

  void updatePlan(CustomTrainingPlan updatedPlan) {
    final index = state.plans.indexWhere((p) => p.id == updatedPlan.id);
    if (index != -1) {
      final newPlans = List<CustomTrainingPlan>.from(state.plans);
      newPlans[index] = updatedPlan;
      emit(state.copyWith(plans: newPlans));
    }
  }

  void removePlan(String planId) {
    final newPlans = state.plans.where((p) => p.id != planId).toList();
    emit(state.copyWith(plans: newPlans));
  }
}
