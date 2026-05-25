import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/offline_first_training_session_repository.dart';
import '../../domain/models/custom_training_plan.dart';
import '../../domain/models/training_session.dart';
import '../../domain/repositories/training_session_repository.dart';

class TrainingSessionState {
  const TrainingSessionState({
    this.activeSession,
    this.isLoading = false,
    this.activeConflict,
  });

  final TrainingSession? activeSession;
  final bool isLoading;
  final TrainingSession? activeConflict;

  TrainingSessionState copyWith({
    TrainingSession? activeSession,
    bool? isLoading,
    TrainingSession? activeConflict,
    bool clearActiveSession = false,
    bool clearActiveConflict = false,
  }) {
    return TrainingSessionState(
      activeSession: clearActiveSession
          ? null
          : (activeSession ?? this.activeSession),
      isLoading: isLoading ?? this.isLoading,
      activeConflict: clearActiveConflict
          ? null
          : (activeConflict ?? this.activeConflict),
    );
  }
}

class TrainingSessionCubit extends Cubit<TrainingSessionState> {
  TrainingSessionCubit(this._repository, {bool autoRefresh = true})
    : super(const TrainingSessionState()) {
    if (autoRefresh) refresh();
  }

  final TrainingSessionRepository _repository;

  void _emitIfOpen(TrainingSessionState next) {
    if (!isClosed) emit(next);
  }

  Future<void> refresh() async {
    _emitIfOpen(state.copyWith(isLoading: true, clearActiveConflict: true));
    final active = await _repository.getActive();
    _emitIfOpen(
      state.copyWith(
        activeSession: active,
        isLoading: false,
        clearActiveSession: active == null,
      ),
    );
  }

  Future<TrainingSession?> startFromPlan(CustomTrainingPlan plan) async {
    try {
      final session = await _repository.startFromPlan(plan);
      _emitIfOpen(
        state.copyWith(activeSession: session, clearActiveConflict: true),
      );
      return session;
    } on ActiveTrainingSessionException catch (e) {
      _emitIfOpen(state.copyWith(activeConflict: e.session));
      return null;
    }
  }

  Future<TrainingSession?> startCustom({
    String planName = TrainingSession.defaultCustomName,
  }) async {
    try {
      final session = await _repository.startCustom(planName: planName);
      _emitIfOpen(
        state.copyWith(activeSession: session, clearActiveConflict: true),
      );
      return session;
    } on ActiveTrainingSessionException catch (e) {
      _emitIfOpen(state.copyWith(activeConflict: e.session));
      return null;
    }
  }

  Future<void> save(TrainingSession session) async {
    final saved = await _repository.save(session);
    _emitIfOpen(state.copyWith(activeSession: saved));
  }

  Future<void> finish(String sessionId) async {
    await _repository.finish(sessionId);
    _emitIfOpen(state.copyWith(clearActiveSession: true));
  }

  Future<void> cancel(String sessionId) async {
    await _repository.cancel(sessionId);
    _emitIfOpen(state.copyWith(clearActiveSession: true));
  }
}
