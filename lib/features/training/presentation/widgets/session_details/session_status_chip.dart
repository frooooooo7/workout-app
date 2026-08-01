import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../domain/models/training_history_models.dart';
import 'session_details_formatters.dart';

/// Chip statusu sesji (Ukończony / Anulowany / W trakcie) — używany zarówno
/// w nagłówku szczegółów sesji, jak i na liście historii.
class SessionStatusChip extends StatelessWidget {
  const SessionStatusChip({super.key, required this.status});

  final TrainingSessionStatus status;

  Color get _color => switch (status) {
    TrainingSessionStatus.completed => AppColors.primary,
    TrainingSessionStatus.cancelled => AppColors.strengthWeak,
    TrainingSessionStatus.active => AppColors.strengthMedium,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _color.withValues(alpha: 0.35)),
      ),
      child: Text(
        formatSessionStatus(status),
        style: TextStyle(
          color: _color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
