import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/models/training_home_insights.dart';
import '../../domain/models/training_session.dart';
import '../../domain/repositories/training_stats_repository.dart';
import '../../domain/services/training_home_calculator.dart';

/// Dane ekranu startowego „Trening” z lokalnej historii (działa offline):
/// stan tygodnia, ostatnie wyniki ćwiczeń, rekordy do pobicia, typowy czas
/// planu i cel tygodniowy z profilu.
///
/// Wszystko to dodatki do planu na dziś — przy błędzie zostaje ostatni
/// znany stan, a ekran po prostu pomija brakujące elementy.
///
/// Przy dużej historii ([isolateThreshold] sesji i więcej) liczenie (rekordy
/// z całej historii) idzie do osobnego wątku, żeby zakładka nie przycinała.
class TrainingHomeCubit extends Cubit<TrainingHomeInsights> {
  TrainingHomeCubit(
    this._repository, {
    Listenable? dataChanges,
    Future<int?> Function()? weeklyGoalLoader,
    DateTime Function()? clock,
  }) : _dataChanges = dataChanges,
       _weeklyGoalLoader = weeklyGoalLoader,
       _clock = clock ?? DateTime.now,
       super(TrainingHomeInsights.empty) {
    _dataChanges?.addListener(_onDataChanged);
    unawaited(refresh());
  }

  static const _goalTimeout = Duration(seconds: 5);

  /// Od tylu sesji liczenie idzie do osobnego wątku (jak w statystykach).
  static const isolateThreshold = 300;

  final TrainingStatsRepository _repository;
  final Listenable? _dataChanges;
  final Future<int?> Function()? _weeklyGoalLoader;
  final DateTime Function() _clock;

  int? _weeklyGoal;
  List<TrainingSession>? _sessions;

  /// Numer ostatniego wczytania — starsza odpowiedź nie nadpisuje nowszej.
  int _seq = 0;

  /// Numer ostatniego liczenia — wynik starszego nie nadpisuje nowszego.
  int _computeSeq = 0;

  @override
  Future<void> close() {
    _dataChanges?.removeListener(_onDataChanged);
    return super.close();
  }

  void _onDataChanged() {
    if (isClosed) return;
    unawaited(refresh());
  }

  /// Wczytuje historię i odświeża cel tygodniowy (cel wymaga sieci, więc
  /// historia nie czeka na niego — dołącza się, gdy przyjdzie).
  Future<void> refresh() => Future.wait([_loadSessions(++_seq), _loadGoal()]);

  Future<void> _loadSessions(int seq) async {
    try {
      final sessions = await _repository.allCompletedSessions();
      if (isClosed || seq != _seq) return;
      _sessions = sessions;
      await _emitInsights();
    } catch (_) {
      // Bez historii karta planu i tak działa — zostaje ostatni stan.
    }
  }

  Future<void> _loadGoal() async {
    final loader = _weeklyGoalLoader;
    if (loader == null) return;
    try {
      final goal = await loader().timeout(_goalTimeout);
      if (isClosed || goal == _weeklyGoal) return;
      _weeklyGoal = goal;
      if (_sessions != null) await _emitInsights();
    } catch (_) {
      // Bez sieci licznik tygodnia pokaże dni zaplanowane w planach.
    }
  }

  Future<void> _emitInsights() async {
    final seq = ++_computeSeq;
    final args = _InsightsArgs(
      sessions: _sessions!,
      today: _clock(),
      weeklyGoal: _weeklyGoal,
    );
    final insights = args.sessions.length >= isolateThreshold
        ? await compute(_insightsJob, args)
        : _insightsJob(args);
    if (isClosed || seq != _computeSeq) return;
    emit(insights);
  }
}

class _InsightsArgs {
  const _InsightsArgs({
    required this.sessions,
    required this.today,
    required this.weeklyGoal,
  });

  final List<TrainingSession> sessions;
  final DateTime today;
  final int? weeklyGoal;
}

TrainingHomeInsights _insightsJob(_InsightsArgs a) =>
    TrainingHomeCalculator.compute(
      a.sessions,
      today: a.today,
      weeklyGoal: a.weeklyGoal,
    );
