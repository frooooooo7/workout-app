import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/account/presentation/bloc/notification_settings_cubit.dart';
import 'package:gym/features/account/presentation/screens/help_screen.dart';
import 'package:gym/features/account/presentation/screens/notification_settings_screen.dart';
import 'package:gym/features/training/data/settings_aware_rest_timer_scheduler.dart';
import 'package:gym/features/training/data/shared_preferences_rest_timer_notification_settings.dart';
import 'package:gym/features/training/domain/services/rest_timer_scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingScheduler implements RestTimerScheduler {
  final scheduled = <Duration>[];
  var cancelCalls = 0;

  @override
  Future<void> scheduleRestFinished({required Duration duration}) async =>
      scheduled.add(duration);

  @override
  Future<void> cancelRestFinished() async => cancelCalls++;

  @override
  Future<void> warmUp() async {}
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('setting defaults to enabled and persists', () async {
    const settings = SharedPreferencesRestTimerNotificationSettings();
    expect(await settings.isEnabled(), isTrue);

    await settings.setEnabled(false);

    expect(await settings.isEnabled(), isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getBool(SharedPreferencesRestTimerNotificationSettings.key),
      isFalse,
    );
  });

  test('scheduler skips notifications when disabled', () async {
    const settings = SharedPreferencesRestTimerNotificationSettings();
    final inner = _RecordingScheduler();
    final scheduler = SettingsAwareRestTimerScheduler(
      inner: inner,
      settings: settings,
    );

    await scheduler.scheduleRestFinished(duration: const Duration(seconds: 90));
    expect(inner.scheduled, [const Duration(seconds: 90)]);

    await settings.setEnabled(false);
    await scheduler.scheduleRestFinished(duration: const Duration(seconds: 60));
    expect(inner.scheduled, [const Duration(seconds: 90)]);

    await scheduler.cancelRestFinished();
    expect(inner.cancelCalls, greaterThanOrEqualTo(2));
  });

  testWidgets('switch toggles the setting and cancels pending notification', (
    tester,
  ) async {
    const settings = SharedPreferencesRestTimerNotificationSettings();
    final inner = _RecordingScheduler();

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => NotificationSettingsCubit(
            settings,
            onRestTimerNotificationsDisabled: inner.cancelRestFinished,
          ),
          child: const NotificationSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Powiadomienie o końcu przerwy'), findsOneWidget);
    SwitchListTile tile() =>
        tester.widget<SwitchListTile>(find.byKey(restTimerNotificationSwitchKey));
    expect(tile().value, isTrue);

    await tester.tap(find.byKey(restTimerNotificationSwitchKey));
    await tester.pumpAndSettle();

    expect(tile().value, isFalse);
    expect(await settings.isEnabled(), isFalse);
    expect(inner.cancelCalls, 1);

    await tester.tap(find.byKey(restTimerNotificationSwitchKey));
    await tester.pumpAndSettle();
    expect(await settings.isEnabled(), isTrue);
  });

  testWidgets('help screen lists FAQ entries and expands answers', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HelpScreen()));

    expect(find.text('Najczęstsze pytania'), findsOneWidget);
    expect(find.text(kHelpEntries.first.question), findsOneWidget);
    expect(find.text(kHelpEntries.first.answer), findsNothing);

    await tester.tap(find.text(kHelpEntries.first.question));
    await tester.pumpAndSettle();

    expect(find.text(kHelpEntries.first.answer), findsOneWidget);
    for (final entry in kHelpEntries) {
      expect(entry.answer, isNot(contains('http')));
      expect(entry.answer, isNot(contains('@')));
    }
  });
}
