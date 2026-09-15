import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/services/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../auth/domain/models/auth_models.dart';
import '../../domain/models/training_history_models.dart';
import '../../domain/models/training_session.dart';
import '../../domain/repositories/training_session_repository.dart';
import '../../domain/services/training_session_detail_mapper.dart';
import '../widgets/session_details/session_muscle_map.dart';
import '../widgets/workout_summary/staggered_reveal.dart';
import '../widgets/workout_summary/workout_share_card.dart';
import '../widgets/workout_summary/workout_summary_exercise_list.dart';
import '../widgets/workout_summary/workout_summary_hero.dart';
import '../widgets/workout_summary/workout_summary_metrics_grid.dart';

class WorkoutSummaryArgs {
  const WorkoutSummaryArgs({
    required this.session,
    this.repository,
    this.user,
  });

  /// Ukończona sesja — źródło wszystkich metryk na ekranie.
  final TrainingSession session;

  /// Test seam; domyślnie [ServiceLocator.trainingSessionRepository].
  final TrainingSessionRepository? repository;

  /// Test seam; domyślnie [ServiceLocator.currentUser].
  final AuthUser? user;
}

/// Ekran po zakończeniu treningu: potwierdzenie, metryki, decyzja o
/// udostępnieniu na profil i przegląd sesji. Sesja jest już zapisana —
/// tutaj użytkownik tylko ogląda wynik i decyduje, co z nim zrobić.
class WorkoutSummaryScreen extends StatefulWidget {
  const WorkoutSummaryScreen({super.key, this.args});

  static const routePath = '/app/training/workout-summary';

  final WorkoutSummaryArgs? args;

  @override
  State<WorkoutSummaryScreen> createState() => _WorkoutSummaryScreenState();
}

class _WorkoutSummaryScreenState extends State<WorkoutSummaryScreen> {
  late TrainingSession _session;
  late TrainingSessionDetail _detail;
  WorkoutShareStatus _shareStatus = WorkoutShareStatus.notShared;

  @override
  void initState() {
    super.initState();
    final args = widget.args;
    if (args == null) return;
    _session = args.session;
    _detail = trainingSessionDetailFromSession(_session);
    _shareStatus = _session.sharedToProfile
        ? WorkoutShareStatus.shared
        : WorkoutShareStatus.notShared;
  }

  TrainingSessionRepository get _repository =>
      widget.args?.repository ?? ServiceLocator.trainingSessionRepository;

  AuthUser? get _user => widget.args?.user ?? ServiceLocator.currentUser.value;

  Future<void> _handleShareChanged(bool shared) async {
    final previous = _shareStatus;
    setState(() => _shareStatus = WorkoutShareStatus.saving);
    try {
      final updated = await _repository.setSharedToProfile(_session.id, shared);
      if (!mounted) return;
      setState(() {
        _session = updated;
        _shareStatus = updated.sharedToProfile
            ? WorkoutShareStatus.shared
            : WorkoutShareStatus.notShared;
      });
      unawaited(_syncAndRefreshProfile());
    } catch (_) {
      if (!mounted) return;
      setState(() => _shareStatus = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nie udało się zapisać zmiany. Spróbuj ponownie.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// Synchronizacja jest best-effort — profil odświeży się także wtedy, gdy
  /// wysyłka pójdzie później z kolejki offline.
  Future<void> _syncAndRefreshProfile() async {
    await ServiceLocator.flushTrainingSessionSync();
    ServiceLocator.requestProfileRefresh();
    // Udostępniony (albo schowany) trening pojawia się w feedzie.
    ServiceLocator.requestFeedRefresh();
  }

  void _handleDone() {
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.args == null) return const _MissingSummaryScreen();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _BackgroundGlow()),
          SafeArea(
            child: Column(
              children: [
                AppHeader(
                  title: 'Podsumowanie treningu',
                  actions: [
                    AppHeaderIconButton(
                      key: const ValueKey('workout-summary-close-button'),
                      icon: Icons.close_rounded,
                      onTap: _handleDone,
                    ),
                  ],
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                    children: [
                      StaggeredReveal(
                        index: 0,
                        child: WorkoutSummaryHero(
                          planName: _session.planName,
                          startedAt: _session.startedAt,
                        ),
                      ),
                      const SizedBox(height: 28),
                      StaggeredReveal(
                        index: 1,
                        child: WorkoutSummaryMetricsGrid(detail: _detail),
                      ),
                      const SizedBox(height: 14),
                      StaggeredReveal(
                        index: 2,
                        child: WorkoutShareCard(
                          status: _shareStatus,
                          user: _user,
                          onShare: () => _handleShareChanged(true),
                          onUnshare: () => _handleShareChanged(false),
                        ),
                      ),
                      const SizedBox(height: 14),
                      StaggeredReveal(
                        index: 3,
                        child: SessionMuscleMap(detail: _detail),
                      ),
                      if (_detail.exercises.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        StaggeredReveal(
                          index: 4,
                          child: WorkoutSummaryExerciseList(
                            exercises: _detail.exercises,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _BottomBar(onDone: _handleDone),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Miękka poświata u góry ekranu — ten sam gradient co na hero treningu,
/// żeby podsumowanie było wizualnie „końcem" tej samej podróży.
class _BackgroundGlow extends StatelessWidget {
  const _BackgroundGlow();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.85),
            radius: 1.1,
            colors: [
              AppColors.success.withValues(alpha: 0.14),
              AppColors.gradientHero.withValues(alpha: 0.6),
              AppColors.gradientTop,
            ],
            stops: const [0, 0.45, 1],
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.background.withValues(alpha: 0),
            AppColors.background,
          ],
          stops: const [0, 0.35],
        ),
      ),
      child: Semantics(
        button: true,
        label: 'Zakończ podsumowanie i wróć do treningu',
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: FilledButton(
            key: const ValueKey('workout-summary-done-button'),
            onPressed: onDone,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.background,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Gotowe',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MissingSummaryScreen extends StatelessWidget {
  const _MissingSummaryScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: 'Podsumowanie treningu',
              onBack: () => Navigator.of(context).maybePop(),
            ),
            const Expanded(
              child: Center(
                child: Text(
                  'Brak danych podsumowania',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
