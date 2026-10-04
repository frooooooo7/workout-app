import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../training/domain/models/workout_reminder.dart';
import '../bloc/workout_reminder_cubit.dart';

const workoutReminderSwitchKey = Key('workout-reminder-switch');
const workoutReminderTimeKey = Key('workout-reminder-time');

Key workoutReminderDayKey(int weekday) => Key('workout-reminder-day-$weekday');

/// Indeks 0 = poniedziałek.
const _weekdayShort = ['Pn', 'Wt', 'Śr', 'Cz', 'Pt', 'So', 'Nd'];

class NotificationSectionLabel extends StatelessWidget {
  const NotificationSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

/// Włącznik, dni tygodnia i godzina przypomnienia o treningu.
/// Wymaga [WorkoutReminderCubit] w kontekście.
class WorkoutReminderSection extends StatelessWidget {
  const WorkoutReminderSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<WorkoutReminderCubit, WorkoutReminderState>(
      listenWhen: (previous, current) =>
          current.error != null && previous.error != current.error,
      listener: (context, state) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.error!),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      builder: (context, state) {
        final cubit = context.read<WorkoutReminderCubit>();
        final reminder = state.reminder;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const NotificationSectionLabel('Przypomnienia'),
            Material(
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile(
                    key: workoutReminderSwitchKey,
                    value: reminder.enabled,
                    onChanged: state.loading ? null : cubit.setEnabled,
                    activeThumbColor: AppColors.primaryVariant,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    secondary: const Icon(
                      Icons.notifications_active_outlined,
                      color: AppColors.textSecondary,
                    ),
                    title: const Text(
                      'Przypomnienie o treningu',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'Powiadomienie w wybrane dni tygodnia o stałej '
                        'godzinie.',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    alignment: Alignment.topCenter,
                    child: reminder.enabled
                        ? _ReminderDetails(reminder: reminder)
                        : const SizedBox(width: double.infinity),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _footnote(state),
              style: TextStyle(
                color: state.permissionDenied
                    ? AppColors.strengthMedium
                    : AppColors.textMuted,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ],
        );
      },
    );
  }

  static String _footnote(WorkoutReminderState state) {
    final reminder = state.reminder;
    if (!reminder.enabled) {
      return 'Wybierz dni i godzinę, a telefon przypomni Ci o treningu.';
    }
    if (reminder.weekdays.isEmpty) {
      return 'Zaznacz co najmniej jeden dzień, żeby dostawać przypomnienia.';
    }
    if (state.permissionDenied) {
      return 'Powiadomienia są zablokowane. Zezwól na nie w ustawieniach '
          'telefonu, żeby dostawać przypomnienia.';
    }
    return describeWorkoutReminder(reminder);
  }
}

class _ReminderDetails extends StatelessWidget {
  const _ReminderDetails({required this.reminder});

  final WorkoutReminder reminder;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<WorkoutReminderCubit>();
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Dni',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (
                var day = DateTime.monday;
                day <= DateTime.sunday;
                day++
              ) ...[
                if (day > DateTime.monday) const SizedBox(width: 6),
                Expanded(
                  child: _DayChip(
                    key: workoutReminderDayKey(day),
                    label: _weekdayShort[day - 1],
                    selected: reminder.weekdays.contains(day),
                    onTap: () => cubit.toggleWeekday(day),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          InkWell(
            key: workoutReminderTimeKey,
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(
                  hour: reminder.hour,
                  minute: reminder.minute,
                ),
                helpText: 'Godzina przypomnienia',
              );
              if (picked != null) {
                await cubit.setTime(picked.hour, picked.minute);
              }
            },
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Godzina',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    formatReminderTime(reminder.hour, reminder.minute),
                    style: const TextStyle(
                      color: AppColors.primaryVariant,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.primaryVariant : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.onPrimary : AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

String formatReminderTime(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

/// Indeks 0 = poniedziałek; forma „w poniedziałki”.
const _weekdayPlural = [
  'poniedziałki',
  'wtorki',
  'środy',
  'czwartki',
  'piątki',
  'soboty',
  'niedziele',
];

/// „Przypomnimy Ci w poniedziałki, środy i piątki o 18:00.”
String describeWorkoutReminder(WorkoutReminder reminder) {
  final days = reminder.weekdays.toList()..sort();
  final time = formatReminderTime(reminder.hour, reminder.minute);
  final String when;
  if (days.length == DateTime.daysPerWeek) {
    when = 'codziennie';
  } else if (days.length == 5 && days.last == DateTime.friday) {
    when = 'w dni powszednie';
  } else if (days.length == 2 && days.first == DateTime.saturday) {
    when = 'w weekendy';
  } else {
    final names = [for (final d in days) _weekdayPlural[d - 1]];
    when = names.length == 1
        ? 'w ${names.single}'
        : 'w ${names.sublist(0, names.length - 1).join(', ')} i ${names.last}';
  }
  return 'Przypomnimy Ci $when o $time.';
}
