import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_tab_header.dart';
import '../../../../core/widgets/sync_status_indicator.dart';
import 'stats/stats_format.dart';
import 'training_day_status.dart';

/// Nagłówek ekranu startowego: data jako nadtytuł, powitanie po imieniu
/// oraz kafelki biblioteki ćwiczeń i stanu synchronizacji.
class TrainingHeader extends StatelessWidget {
  const TrainingHeader({
    super.key,
    this.firstName,
    this.onLibraryTap,
    this.today,
    this.showSync = true,
  });

  /// Imię z konta; bez niego samo „Cześć”.
  final String? firstName;
  final VoidCallback? onLibraryTap;

  /// Test seam; domyślnie [DateTime.now].
  final DateTime? today;

  /// Test seam — wskaźnik synchronizacji wymaga zainicjalizowanego
  /// `ServiceLocator`.
  final bool showSync;

  @override
  Widget build(BuildContext context) {
    final name = firstName?.trim() ?? '';
    final greeting = name.isEmpty ? 'Cześć' : 'Cześć, $name';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageGutter,
        12,
        AppSpacing.pageGutter,
        0,
      ),
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    trainingHeaderDate(today ?? DateTime.now()).toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.eyebrow,
                  ),
                  const SizedBox(height: 2),
                  Semantics(
                    header: true,
                    child: Text(
                      greeting,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.screenTitle.copyWith(
                        letterSpacing: -0.52,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (onLibraryTap != null) ...[
              const SizedBox(width: AppSpacing.xs),
              AppTabHeaderButton(
                tooltip: 'Biblioteka ćwiczeń',
                icon: Icons.menu_book_rounded,
                onPressed: onLibraryTap!,
              ),
            ],
            if (showSync) ...[
              const SizedBox(width: AppSpacing.xs),
              const SyncStatusIndicator(size: AppSpacing.minTapTarget),
            ],
          ],
        ),
      ),
    );
  }
}

/// „Czwartek, 15 października”.
String trainingHeaderDate(DateTime date) =>
    '${kTrainingWeekdayFullNames[date.weekday - 1]}, '
    '${date.day} ${statsMonthsGenitive[date.month - 1]}';
