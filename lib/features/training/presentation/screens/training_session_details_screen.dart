import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/training_history_models.dart';
import '../../domain/repositories/training_history_repository.dart';
import '../widgets/session_details/session_exercise_card.dart';
import '../widgets/session_details/session_muscle_map.dart';
import '../widgets/session_details/session_summary_header.dart';
import '../widgets/session_details/session_timeline.dart';

/// Szczegóły zakończonej sesji, ułożone od ogółu do szczegółu:
/// nagłówek z metrykami → mapa mięśni → oś czasu → karty ćwiczeń.
///
/// Metryki całej sesji pojawiają się **wyłącznie** w nagłówku; każda kolejna
/// sekcja dokłada informację, której poprzednie nie niosą.
class TrainingSessionDetailsScreen extends StatefulWidget {
  const TrainingSessionDetailsScreen({
    super.key,
    required this.sessionId,
    required this.repository,
  });

  final String sessionId;
  final TrainingHistoryRepository repository;

  @override
  State<TrainingSessionDetailsScreen> createState() =>
      _TrainingSessionDetailsScreenState();
}

class _TrainingSessionDetailsScreenState
    extends State<TrainingSessionDetailsScreen> {
  TrainingSessionDetail? _detail;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await widget.repository.getSessionDetail(widget.sessionId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Nie udało się pobrać szczegółów sesji.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('SZCZEGÓŁY SESJI')),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : _error != null
            ? _ErrorState(message: _error!, onRetry: _load)
            : _DetailContent(detail: _detail!),
      ),
    );
  }
}

class _DetailContent extends StatefulWidget {
  const _DetailContent({required this.detail});

  final TrainingSessionDetail detail;

  @override
  State<_DetailContent> createState() => _DetailContentState();
}

class _DetailContentState extends State<_DetailContent> {
  /// Klucze kart ćwiczeń — punkt zaczepienia dla skoku z osi czasu.
  late List<GlobalKey> _exerciseKeys;
  int? _highlightedIndex;
  Timer? _highlightTimer;

  @override
  void initState() {
    super.initState();
    _exerciseKeys = List.generate(
      widget.detail.exercises.length,
      (_) => GlobalKey(),
    );
  }

  @override
  void didUpdateWidget(_DetailContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.detail.exercises.length != widget.detail.exercises.length) {
      _exerciseKeys = List.generate(
        widget.detail.exercises.length,
        (_) => GlobalKey(),
      );
    }
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    super.dispose();
  }

  Future<void> _jumpToExercise(int index) async {
    final context = _exerciseKeys[index].currentContext;
    if (context == null) return;

    setState(() => _highlightedIndex = index);
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _highlightedIndex = null);
    });

    await Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
  }

  @override
  Widget build(BuildContext context) {
    final exercises = widget.detail.exercises;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        SessionSummaryHeader(detail: widget.detail),
        const SizedBox(height: 12),
        SessionMuscleMap(detail: widget.detail),
        const SizedBox(height: 12),
        SessionTimeline(
          detail: widget.detail,
          onExerciseTap: _jumpToExercise,
        ),
        if (exercises.isNotEmpty) ...[
          const SizedBox(height: 22),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              'Ćwiczenia',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ),
          for (var i = 0; i < exercises.length; i++)
            Padding(
              key: _exerciseKeys[i],
              padding: const EdgeInsets.only(bottom: 10),
              child: SessionExerciseCard(
                exercise: exercises[i],
                index: i,
                isHighlighted: _highlightedIndex == i,
              ),
            ),
        ],
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              color: AppColors.textMuted,
              size: 34,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Spróbuj ponownie'),
            ),
          ],
        ),
      ),
    );
  }
}
