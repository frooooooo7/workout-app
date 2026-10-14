import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/notifications/data/api_notifications_repository.dart';
import 'package:gym/features/notifications/domain/models/app_notification.dart';
import 'package:gym/features/notifications/presentation/utils/notification_text.dart';

import 'support/fake_notifications_repository.dart';

String textOf(AppNotification n) =>
    notificationTextParts(n).map((p) => p.text).join();

void main() {
  group('notification text', () {
    test('kudos are grouped and gender-neutral', () {
      expect(
        textOf(kudosNotification(count: 1)),
        'Anna daje kudosa za trening Push',
      );
      expect(
        textOf(kudosNotification(count: 2)),
        'Anna i Ola dają kudosy za trening Push',
      );
      expect(
        textOf(kudosNotification(count: 3)),
        'Anna i 2 inne osoby dają kudosy za trening Push',
      );
      expect(
        textOf(kudosNotification(count: 6)),
        'Anna i 5 innych osób dają kudosy za trening Push',
      );
    });

    test('follow, plan copy and record', () {
      expect(textOf(followNotification()), 'Kuba Nowak obserwuje Cię');
      expect(
        textOf(planCopyNotification()),
        'Ola dodaje Twój plan Góra A do swoich planów',
      );
      expect(
        textOf(recordNotification()),
        'Anna bije rekord: Martwy ciąg 120 kg × 3',
      );
    });

    test('a bodyweight record shows reps', () {
      expect(
        formatNotificationRecord(
          const NotificationRecord(exerciseName: 'Podciąganie', reps: 15),
        ),
        'Podciąganie 15 powt.',
      );
    });
  });

  group('relative time', () {
    final now = DateTime(2026, 10, 14, 12);
    String at(Duration ago) =>
        formatNotificationTime(now.subtract(ago), now: now);

    test('minutes, hours, yesterday, weekday and date', () {
      expect(at(const Duration(seconds: 20)), 'teraz');
      expect(at(const Duration(minutes: 12)), '12 min temu');
      expect(at(const Duration(hours: 3)), '3 godz. temu');
      expect(at(const Duration(hours: 13)), 'wczoraj');
      expect(at(const Duration(days: 2)), 'pon, 12 paź');
      expect(
        formatNotificationTime(DateTime(2025, 12, 30), now: now),
        '30 gru 2025',
      );
    });
  });

  group('json', () {
    test('unknown kinds and items without people are skipped', () {
      final page = ApiNotificationsRepository.pageFromJson({
        'unreadCount': 1,
        'items': [
          {
            'id': 'kudos:s-1',
            'type': 'kudos',
            'createdAt': '2026-10-14T10:00:00.000Z',
            'read': false,
            'actors': [
              {
                'id': 'u-1',
                'firstName': 'Anna',
                'lastName': 'K',
                'handle': 'anna',
              },
            ],
            'actorCount': 4,
            'session': {'id': 's-1', 'title': 'Push'},
          },
          {
            'id': 'comment:c-1',
            'type': 'comment',
            'createdAt': '2026-10-14T10:00:00.000Z',
            'actors': [
              {'id': 'u-1', 'firstName': 'Anna', 'lastName': 'K'},
            ],
          },
          {
            'id': 'follow:u-2',
            'type': 'follow',
            'createdAt': '2026-10-14T10:00:00.000Z',
            'actors': <dynamic>[],
          },
        ],
      });

      expect(page.items.single.actorCount, 4);
      expect(page.items.single.sessionTitle, 'Push');
      expect(page.unreadCount, 1);
    });

    test('settings round trip with defaults', () {
      final settings = ApiNotificationsRepository.settingsFromJson({
        'kudos': false,
        'quietHours': {'enabled': true},
      });
      expect(settings.kudos, isFalse);
      expect(settings.follows, isTrue);
      expect(settings.quietHours, const QuietHours(enabled: true));
      expect(
        ApiNotificationsRepository.settingsFromJson(
          ApiNotificationsRepository.settingsToJson(settings),
        ),
        settings,
      );
    });
  });
}
