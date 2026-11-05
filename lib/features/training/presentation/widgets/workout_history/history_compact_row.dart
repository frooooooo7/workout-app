import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/utils/polish_plural.dart';
import '../../../../../core/widgets/app_pressable.dart';
import '../../../domain/services/history_feed_builder.dart';
import '../session_details/session_details_formatters.dart';
import 'history_formatters.dart';
import 'history_plan_style.dart';
import 'history_record_badge.dart';

/// Zwarty wiersz treningu w karcie miesiąca: data po lewej, pasek w kolorze
/// planu, plan z plakietką rekordu, „godzina · czas · serie” i tonaż po prawej.
///
/// Wiersze jednego miesiąca składają się w jedną kartę: [isFirst] i [isLast]
/// mówią, który z nich zaokrągla górę albo dół i rysuje krawędź.
class HistoryCompactRow extends StatelessWidget {
  const HistoryCompactRow({
    super.key,
    required this.entry,
    this.isFirst = true,
    this.isLast = true,
    this.highlighted = false,
  });

  final HistoryFeedEntry entry;
  final bool isFirst;
  final bool isLast;

  /// Krótkie podświetlenie po „Pokaż na liście” z kalendarza.
  final bool highlighted;

  static const height = 66.0;

  @override
  Widget build(BuildContext context) {
    final session = entry.item;
    final plan = HistoryPlanStyle.of(session);
    final sets = session.completedSetsCount;
    final volume = session.totalVolumeKg ?? 0;

    return AppPressable(
      onTap: () => context.push('/app/training/history/${session.id}'),
      pressedScale: 0.99,
      child: CustomPaint(
        painter: _CardSlicePainter(
          isFirst: isFirst,
          isLast: isLast,
          fill: highlighted
              ? Color.alphaBlend(
                  AppColors.primary.withValues(alpha: 0.14),
                  AppColors.surface,
                )
              : AppColors.surface,
          border: highlighted ? AppColors.primaryVariant : AppColors.border,
        ),
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                SizedBox(
                  width: 38,
                  child: Semantics(
                    label: formatSessionDay(entry.day),
                    excludeSemantics: true,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          formatDayNumber(entry.day),
                          style: AppTextStyles.number(size: 24),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          formatWeekdayShort(entry.day).toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Container(
                  width: 3,
                  height: 36,
                  decoration: BoxDecoration(
                    color: plan.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              plan.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          if (entry.recordsCount > 0) ...[
                            const SizedBox(width: AppSpacing.xs),
                            HistoryRecordBadge(count: entry.recordsCount),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${formatClock(session.startedAt)} · '
                        '${formatHoursMinutes(session.durationSec)} · '
                        '$sets ${polishPlural(sets, 'seria', 'serie', 'serii')}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(fontSize: 13),
                      ),
                    ],
                  ),
                ),
                if (volume > 0) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    formatVolumeKg(volume),
                    maxLines: 1,
                    style: AppTextStyles.number(size: 22),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Wycinek karty miesiąca: tło i krawędź całej karty, obcięte do jednego
/// wiersza, oraz linia oddzielająca od następnego wiersza. Dzięki temu karta
/// miesiąca może budować się leniwie, wiersz po wierszu.
class _CardSlicePainter extends CustomPainter {
  const _CardSlicePainter({
    required this.isFirst,
    required this.isLast,
    required this.fill,
    required this.border,
  });

  final bool isFirst;
  final bool isLast;
  final Color fill;
  final Color border;

  static const _radius = 22.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    // Cała karta jest wyższa niż wiersz: brakującą górę i dół wysuwamy poza
    // obcięty obszar.
    final card = RRect.fromLTRBR(
      0.5,
      isFirst ? 0.5 : -_radius - 1,
      size.width - 0.5,
      isLast ? size.height - 0.5 : size.height + _radius + 1,
      const Radius.circular(_radius),
    );
    canvas.drawRRect(card, Paint()..color = fill);
    canvas.drawRRect(
      card,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    if (!isLast) {
      canvas.drawLine(
        Offset(14, size.height - 0.5),
        Offset(size.width - 14, size.height - 0.5),
        Paint()
          ..color = AppColors.border
          ..strokeWidth = 1,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CardSlicePainter old) =>
      old.isFirst != isFirst ||
      old.isLast != isLast ||
      old.fill != fill ||
      old.border != border;
}
