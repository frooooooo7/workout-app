import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/training_history_models.dart';
import '../../domain/repositories/training_history_repository.dart';

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
      appBar: AppBar(
        title: const Text('SZCZEGÓŁY SESJI'),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : _error != null
                ? _ErrorState(
                    message: _error!,
                    onRetry: _load,
                  )
                : _DetailContent(detail: _detail!),
      ),
    );
  }
}

class _DetailContent extends StatelessWidget {
  const _DetailContent({required this.detail});

  final TrainingSessionDetail detail;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        _SummaryCard(detail: detail),
        const SizedBox(height: 14),
        ...detail.exercises.map(
          (exercise) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ExerciseCard(exercise: exercise),
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.detail});

  final TrainingSessionDetail detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            detail.plan.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaChip(label: _formatStatus(detail.status)),
              _MetaChip(label: _formatDuration(detail.durationSec)),
              _MetaChip(label: _formatDate(detail.startedAt)),
            ],
          ),
          if (detail.note != null && detail.note!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              detail.note!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.exercise});

  final TrainingExerciseDetail exercise;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            exercise.exerciseName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ...exercise.sets.map(
            (set) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SetRow(set: set),
            ),
          ),
        ],
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({required this.set});

  final TrainingExerciseSetDetail set;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${set.setIndex}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Plan: ${_formatMetrics(set.planned)}  •  Wykonanie: ${_formatMetrics(set.actual)}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          set.completed ? Icons.check_circle_rounded : Icons.cancel_outlined,
          color: set.completed ? AppColors.success : AppColors.textMuted,
          size: 18,
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

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
            const Icon(Icons.wifi_off_rounded, color: AppColors.textMuted, size: 34),
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

String _formatMetrics(TrainingSetMetrics? metrics) {
  if (metrics == null) return '-';
  final chunks = <String>[
    if (metrics.weightKg != null) '${metrics.weightKg}kg',
    if (metrics.reps != null) '${metrics.reps} powt',
    if (metrics.rir != null) 'RIR ${metrics.rir}',
    if (metrics.tempo != null && metrics.tempo!.isNotEmpty) metrics.tempo!,
  ];
  if (chunks.isEmpty) return '-';
  return chunks.join(' · ');
}

String _formatDuration(int durationSec) {
  final duration = Duration(seconds: durationSec);
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours == 0) return '${minutes} min';
  return '${hours}h ${minutes} min';
}

String _formatStatus(TrainingSessionStatus status) {
  return switch (status) {
    TrainingSessionStatus.completed => 'Ukończony',
    TrainingSessionStatus.cancelled => 'Anulowany',
    TrainingSessionStatus.active => 'Aktywny',
  };
}

String _formatDate(DateTime date) {
  final local = date.toLocal();
  return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year}';
}

