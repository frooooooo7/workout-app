import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../training/domain/models/custom_training_plan.dart';
import '../../../training/domain/repositories/training_plan_repository.dart';

/// Moje plany na profilu, czytane z lokalnej bazy (działa bez sieci).
/// `null` do pierwszego wczytania albo gdy się nie udało. Odświeża się, gdy
/// zmienią się plany (np. po synchronizacji).
class ProfilePlansCubit extends Cubit<List<CustomTrainingPlan>?> {
  ProfilePlansCubit(this._repository, {Listenable? dataChanges})
    : _dataChanges = dataChanges,
      super(null) {
    _dataChanges?.addListener(_onDataChanged);
  }

  final TrainingPlanRepository _repository;
  final Listenable? _dataChanges;

  Future<void> load() async {
    try {
      final plans = await _repository.getAll();
      if (isClosed) return;
      emit(plans);
    } catch (_) {
      // Sekcja jest dodatkiem — przy błędzie zostaje poprzedni stan.
    }
  }

  void _onDataChanged() {
    if (isClosed) return;
    load();
  }

  @override
  Future<void> close() {
    _dataChanges?.removeListener(_onDataChanged);
    return super.close();
  }
}
