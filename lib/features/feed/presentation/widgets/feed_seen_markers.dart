import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../bloc/feed_messages.dart';

/// Podsumowanie nad postami: ile nowych od ostatniej wizyty albo „brak
/// nowych”. Nie pokazuje się przy pierwszym otwarciu feedu.
class FeedSeenSummaryBanner extends StatelessWidget {
  const FeedSeenSummaryBanner({
    super.key,
    required this.newCount,
    this.capped = false,
  });

  final int newCount;

  /// Cała pierwsza strona jest nowa — licznik „20+”.
  final bool capped;

  @override
  Widget build(BuildContext context) {
    final hasNew = newCount > 0;
    final accent = hasNew ? AppColors.primaryVariant : AppColors.success;

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: hasNew
                ? [
                    AppColors.primary.withValues(alpha: 0.2),
                    AppColors.primary.withValues(alpha: 0.06),
                  ]
                : [
                    AppColors.surfaceVariant.withValues(alpha: 0.7),
                    AppColors.surfaceVariant.withValues(alpha: 0.35),
                  ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasNew
                ? AppColors.primary.withValues(alpha: 0.4)
                : AppColors.border.withValues(alpha: 0.7),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasNew
                    ? Icons.fiber_new_rounded
                    : Icons.check_circle_outline_rounded,
                size: 19,
                color: accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasNew
                        ? feedNewPostsLabel(newCount, capped: capped)
                        : 'Brak nowych treningów',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasNew
                        ? 'od Twojej ostatniej wizyty'
                        : 'Jesteś na bieżąco — poniżej wcześniejsze treningi',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            if (hasNew)
              Icon(
                Icons.arrow_downward_rounded,
                size: 18,
                color: accent.withValues(alpha: 0.8),
              ),
          ],
        ),
      ),
    );
  }
}

/// Granica między nowymi a obejrzanymi postami.
class FeedSeenDivider extends StatelessWidget {
  const FeedSeenDivider({super.key});

  @override
  Widget build(BuildContext context) {
    Widget line(Alignment begin, Alignment end) => Expanded(
      child: Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: begin,
            end: end,
            colors: [
              AppColors.success.withValues(alpha: 0),
              AppColors.success.withValues(alpha: 0.45),
            ],
          ),
        ),
      ),
    );

    return Semantics(
      label: 'Przejrzałeś wszystkie nowe treningi. Dalej wcześniejsze.',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          children: [
            Row(
              children: [
                line(Alignment.centerLeft, Alignment.centerRight),
                // Etykieta bierze większość szerokości, linie resztę; na
                // wąskim ekranie tekst skraca się zamiast przepełniać wiersz.
                Flexible(
                  flex: 6,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.35),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.done_all_rounded,
                          size: 15,
                          color: AppColors.success,
                        ),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Przejrzałeś wszystkie nowe',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.success,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                line(Alignment.centerRight, Alignment.centerLeft),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'WCZEŚNIEJSZE TRENINGI',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Plakietka „Nowy” w nagłówku karty posta.
class FeedNewBadge extends StatelessWidget {
  const FeedNewBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: AppColors.primaryVariant,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryVariant.withValues(alpha: 0.7),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          const Text(
            'NOWY',
            style: TextStyle(
              color: AppColors.primaryVariant,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
