import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/polish_plural.dart';
import '../../../../core/widgets/app_pressable.dart';

const bodyMeasurementHistoryLinkKey = Key('body-measurement-history-link');

/// Karta „Historia pomiarów” — przejście do wykresów i listy wpisów.
class BodyMeasurementHistoryLink extends StatelessWidget {
  const BodyMeasurementHistoryLink({
    super.key,
    required this.entryCount,
    required this.onTap,
  });

  final int entryCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: AppPressable(
        key: bodyMeasurementHistoryLinkKey,
        onTap: onTap,
        pressedScale: 0.98,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.history_rounded,
                size: 20,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Historia pomiarów',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$entryCount '
                      '${polishPlural(entryCount, 'wpis', 'wpisy', 'wpisów')}'
                      ' · wykresy i edycja wpisów',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
