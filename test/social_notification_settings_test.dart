import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/notifications/domain/models/app_notification.dart';
import 'package:gym/features/notifications/presentation/bloc/social_notification_settings_cubit.dart';

import 'support/fake_notifications_repository.dart';

void main() {
  test('switches save right away and roll back on failure', () async {
    final repository = FakeNotificationsRepository();
    final cubit = SocialNotificationSettingsCubit(repository);
    await cubit.load();

    cubit.setKudos(false);
    expect(cubit.state.settings!.kudos, isFalse);
    await pumpEventQueue();
    expect(repository.savedSettings.single.kudos, isFalse);

    repository.failSettings = true;
    cubit.setRecords(false);
    await pumpEventQueue();

    expect(cubit.state.settings!.records, isTrue);
    expect(cubit.state.settings!.kudos, isFalse);
    expect(cubit.state.error, isNotNull);
  });

  test('changes made during a save go out in one more request', () async {
    final repository = FakeNotificationsRepository()
      ..pendingSave = Completer<void>();
    final cubit = SocialNotificationSettingsCubit(repository);
    await cubit.load();

    cubit.setKudos(false);
    await pumpEventQueue();
    cubit.setFollows(false);
    cubit.setQuietHours(const QuietHours(enabled: true));
    repository.pendingSave!.complete();
    await pumpEventQueue();

    expect(repository.savedSettings, hasLength(2));
    expect(
      repository.savedSettings.last,
      const NotificationSettings(
        kudos: false,
        follows: false,
        quietHours: QuietHours(enabled: true),
      ),
    );
    expect(cubit.state.settings, repository.savedSettings.last);
  });

  test('offline the switches stay disabled', () async {
    final repository = FakeNotificationsRepository()..failSettings = true;
    final cubit = SocialNotificationSettingsCubit(repository);
    await cubit.load();

    expect(cubit.state.loadFailed, isTrue);
    expect(cubit.state.settings, isNull);
  });
}
