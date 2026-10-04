import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/account/presentation/bloc/notification_settings_cubit.dart';
import 'package:gym/features/account/presentation/bloc/workout_reminder_cubit.dart';
import 'package:gym/features/account/presentation/screens/notification_settings_screen.dart';
import 'package:gym/features/account/presentation/widgets/workout_reminder_section.dart';
import 'package:gym/features/training/data/shared_preferences_rest_timer_notification_settings.dart';
import 'package:gym/features/training/data/shared_preferences_workout_reminder_settings.dart';
import 'package:gym/features/training/domain/models/workout_reminder.dart';
import 'package:gym/features/training/domain/services/workout_reminder_scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingReminderScheduler implements WorkoutReminderScheduler {
  _RecordingReminderScheduler({this.granted = true});

  final bool granted;
  final applied = <WorkoutReminder>[];

  @override
  Future<bool> apply(WorkoutReminder reminder) async {
    applied.add(reminder);
    return granted;
  }
}

Future<void> _pumpScreen(
  WidgetTester tester,
  WorkoutReminderScheduler scheduler,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => NotificationSettingsCubit(
              const SharedPreferencesRestTimerNotificationSettings(),
            ),
          ),
          BlocProvider(
            create: (_) => WorkoutReminderCubit(
              const SharedPreferencesWorkoutReminderSettings(),
              scheduler,
            ),
          ),
        ],
        child: const NotificationSettingsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('nextWorkoutReminderOccurrence', () {
    // 2026-10-07 to środa.
    final wednesdayNoon = DateTime(2026, 10, 7, 12);

    test('later the same day', () {
      expect(
        nextWorkoutReminderOccurrence(
          now: wednesdayNoon,
          weekday: DateTime.wednesday,
          hour: 18,
          minute: 30,
        ),
        DateTime(2026, 10, 7, 18, 30),
      );
    });

    test('same weekday but time passed jumps a week', () {
      expect(
        nextWorkoutReminderOccurrence(
          now: wednesdayNoon,
          weekday: DateTime.wednesday,
          hour: 12,
          minute: 0,
        ),
        DateTime(2026, 10, 14, 12),
      );
    });

    test('earlier weekday wraps into next week, across month end', () {
      expect(
        nextWorkoutReminderOccurrence(
          now: DateTime(2026, 10, 30, 9), // piątek
          weekday: DateTime.monday,
          hour: 7,
          minute: 15,
        ),
        DateTime(2026, 11, 2, 7, 15),
      );
    });
  });

  test('settings default to off and round-trip', () async {
    const settings = SharedPreferencesWorkoutReminderSettings();
    expect(await settings.load(), const WorkoutReminder());

    const saved = WorkoutReminder(
      enabled: true,
      weekdays: {DateTime.tuesday, DateTime.saturday},
      hour: 6,
      minute: 45,
    );
    await settings.save(saved);
    expect(await settings.load(), saved);
  });

  test('description reads naturally in Polish', () {
    expect(
      describeWorkoutReminder(const WorkoutReminder(enabled: true)),
      'Przypomnimy Ci w poniedziałki, środy i piątki o 18:00.',
    );
    expect(
      describeWorkoutReminder(
        const WorkoutReminder(weekdays: {DateTime.sunday}, hour: 9, minute: 5),
      ),
      'Przypomnimy Ci w niedziele o 09:05.',
    );
    expect(
      describeWorkoutReminder(
        const WorkoutReminder(weekdays: {1, 2, 3, 4, 5}, hour: 7),
      ),
      'Przypomnimy Ci w dni powszednie o 07:00.',
    );
    expect(
      describeWorkoutReminder(
        const WorkoutReminder(weekdays: {1, 2, 3, 4, 5, 6, 7}, hour: 7),
      ),
      'Przypomnimy Ci codziennie o 07:00.',
    );
  });

  testWidgets('enabling, picking days and time schedules the reminder', (
    tester,
  ) async {
    final scheduler = _RecordingReminderScheduler();
    await _pumpScreen(tester, scheduler);

    expect(find.text('Przypomnienie o treningu'), findsOneWidget);
    expect(find.byKey(workoutReminderDayKey(DateTime.monday)), findsNothing);

    await tester.tap(find.byKey(workoutReminderSwitchKey));
    await tester.pumpAndSettle();

    expect(find.byKey(workoutReminderDayKey(DateTime.monday)), findsOneWidget);
    expect(
      find.text('Przypomnimy Ci w poniedziałki, środy i piątki o 18:00.'),
      findsOneWidget,
    );
    expect(scheduler.applied.last.isActive, isTrue);

    await tester.tap(find.byKey(workoutReminderDayKey(DateTime.monday)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(workoutReminderDayKey(DateTime.saturday)));
    await tester.pumpAndSettle();

    expect(
      find.text('Przypomnimy Ci w środy, piątki i soboty o 18:00.'),
      findsOneWidget,
    );
    expect(scheduler.applied.last.weekdays, {
      DateTime.wednesday,
      DateTime.friday,
      DateTime.saturday,
    });

    await tester.tap(find.byKey(workoutReminderTimeKey));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    final stored = await const SharedPreferencesWorkoutReminderSettings()
        .load();
    expect(stored.enabled, isTrue);
    expect(stored.weekdays, scheduler.applied.last.weekdays);

    await tester.tap(find.byKey(workoutReminderSwitchKey));
    await tester.pumpAndSettle();
    expect(scheduler.applied.last.isActive, isFalse);
    expect(find.byKey(workoutReminderDayKey(DateTime.monday)), findsNothing);
  });

  testWidgets('no days selected asks for at least one', (tester) async {
    SharedPreferences.setMockInitialValues({
      SharedPreferencesWorkoutReminderSettings.enabledKey: true,
      SharedPreferencesWorkoutReminderSettings.weekdaysKey: ['3'],
    });
    final scheduler = _RecordingReminderScheduler();
    await _pumpScreen(tester, scheduler);

    await tester.tap(find.byKey(workoutReminderDayKey(DateTime.wednesday)));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Zaznacz co najmniej jeden dzień, żeby dostawać przypomnienia.',
      ),
      findsOneWidget,
    );
    expect(scheduler.applied.last.isActive, isFalse);
  });

  testWidgets('blocked notifications show a hint', (tester) async {
    final scheduler = _RecordingReminderScheduler(granted: false);
    await _pumpScreen(tester, scheduler);

    await tester.tap(find.byKey(workoutReminderSwitchKey));
    await tester.pumpAndSettle();

    expect(find.textContaining('Powiadomienia są zablokowane'), findsOneWidget);
  });
}
