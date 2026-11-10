import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../training/domain/models/custom_training_plan.dart';
import '../../../training/domain/repositories/training_plan_repository.dart';

/// Moje plany na profilu, czytane z lokalnej bazy (działa bez sieci).
/// `null` do pierwszego wczytania albo gdy się nie udało.
class ProfilePlansCubit extends Cubit<List<CustomTrainingPlan>?> {
  ProfilePlansCubit(this._repository) : super(null);

  final TrainingPlanRepository _repository;

  Future<void> load() async {
    try {
      final plans = await _repository.getAll();
      if (isClosed) return;
      emit(plans);
    } catch (_) {
      // Sekcja jest dodatkiem — przy błędzie zostaje poprzedni stan.
    }
  }
}
