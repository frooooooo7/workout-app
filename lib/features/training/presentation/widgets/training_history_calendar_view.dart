import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/training_history_models.dart';
import '../bloc/training_history_cubit.dart';
import 'training_history_session_card.dart';

class TrainingHistoryCalendarView extends StatelessWidget {
  const TrainingHistoryCalendarView({
    super.key,
    required this.state,
  });

  final TrainingHistoryState state;

  static const List<String> _polishMonths = [
    'Styczeń', 'Luty', 'Marzec', 'Kwiecień', 'Maj', 'Czerwiec',
    'Lipiec', 'Sierpień', 'Wrzesień', 'Październik', 'Listopad', 'Grudzień'
  ];

  static const List<String> _weekdays = [
    'Pn', 'Wt', 'Śr', 'Czw', 'Pt', 'Sb', 'Nd'
  ];

  @override
  Widget build(BuildContext context) {
    final year = state.focusedMonth.year;
    final month = state.focusedMonth.month;

    // Start day of the week (1 = Monday, 7 = Sunday)
    final firstDayOfMonth = DateTime(year, month, 1);
    final startWeekday = firstDayOfMonth.weekday;

    // Number of days in current month
    final daysInMonth = DateTime(year, month + 1, 0).day;

    // Total cells = empty offset cells + month days
    final emptyCells = startWeekday - 1;
    final totalCells = emptyCells + daysInMonth;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        children: [
          // Nav bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, color: Colors.white),
                onPressed: () => context.read<TrainingHistoryCubit>().changeMonth(-1),
              ),
              Text(
                '${_polishMonths[month - 1]} $year',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, color: Colors.white),
                onPressed: () => context.read<TrainingHistoryCubit>().changeMonth(1),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Weekday headers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _weekdays.map((day) {
              return Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          if (state.isCalendarLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 2.2,
                ),
              ),
            )
          else ...[
            // Days grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.0,
              ),
              itemCount: totalCells,
              itemBuilder: (context, index) {
                if (index < emptyCells) {
                  return const SizedBox.shrink();
                }

                final dayNumber = index - emptyCells + 1;
                final date = DateTime(year, month, dayNumber);
                final today = DateTime.now();
                final isToday = date.year == today.year &&
                    date.month == today.month &&
                    date.day == today.day;

                // Find sessions for this day
                final sessionsForDay = state.calendarSessions.where((s) {
                  final sLocal = s.startedAt.toLocal();
                  return sLocal.year == year &&
                      sLocal.month == month &&
                      sLocal.day == dayNumber;
                }).toList();

                final hasWorkout = sessionsForDay.isNotEmpty;

                return GestureDetector(
                  onTap: () {
                    if (hasWorkout) {
                      _showDaySessionsBottomSheet(context, date, sessionsForDay);
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isToday
                            ? AppColors.primaryVariant
                            : AppColors.border,
                        width: isToday ? 1.5 : 1.0,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$dayNumber',
                          style: TextStyle(
                            color: hasWorkout ? Colors.white : AppColors.textSecondary,
                            fontSize: 15,
                            fontWeight: isToday || hasWorkout
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                        if (hasWorkout) ...[
                          const SizedBox(height: 4),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  void _showDaySessionsBottomSheet(
    BuildContext context,
    DateTime date,
    List<TrainingSessionListItem> sessions,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final formattedDate =
            '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 8),
                // Drag handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Treningi z dnia $formattedDate',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(color: AppColors.border, height: 1),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    itemCount: sessions.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = sessions[index];
                      return TrainingHistorySessionCard(
                        item: item,
                        onTap: () {
                          final router = GoRouter.of(context);
                          Navigator.pop(context);
                          router.push('/app/training/history/${item.id}');
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
