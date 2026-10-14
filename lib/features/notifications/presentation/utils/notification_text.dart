import 'package:flutter/painting.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/plan_colors.dart';
import '../../../../core/units/weight_unit.dart';
import '../../../../core/utils/polish_plural.dart';
import '../../../feed/domain/models/feed_author.dart';
import '../../../training/presentation/widgets/session_details/session_details_formatters.dart';
import '../../domain/models/app_notification.dart';

/// Fragment opisu: zwykły tekst, wyróżnione imię albo nazwa w kolorze.
typedef NotificationTextPart = ({String text, bool bold, Color? color});

NotificationTextPart _plain(String text) =>
    (text: text, bold: false, color: null);
NotificationTextPart _bold(String text, [Color? color]) =>
    (text: text, bold: true, color: color);

/// Opis wpisu w czasie teraźniejszym — bez zgadywania rodzaju
/// gramatycznego: „Anna daje kudosa…”, „Kuba Nowak obserwuje Cię”.
List<NotificationTextPart> notificationTextParts(AppNotification n) {
  final actor = n.actor;
  final name = _nameOf(actor);
  switch (n.type) {
    case AppNotificationType.kudos:
      final title = n.sessionTitle ?? 'Trening';
      final others = n.actorCount - 1;
      return [
        _bold(name),
        if (others == 1 && n.actors.length > 1) ...[
          _plain(' i '),
          _bold(_nameOf(n.actors[1])),
        ] else if (others > 0) ...[
          _plain(' i '),
          _bold(
            '$others ${polishPlural(others, 'inna osoba', 'inne osoby', 'innych osób')}',
          ),
        ],
        _plain(
          others == 0 ? ' daje kudosa za trening ' : ' dają kudosy za trening ',
        ),
        _bold(title, PlanColors.of(title)),
      ];
    case AppNotificationType.follow:
      return [
        _bold(actor.fullName.isNotEmpty ? actor.fullName : name),
        _plain(' obserwuje Cię'),
      ];
    case AppNotificationType.planCopy:
      final plan = n.planName ?? 'plan';
      return [
        _bold(name),
        _plain(' dodaje Twój plan '),
        _bold(plan, PlanColors.of(plan)),
        _plain(' do swoich planów'),
      ];
    case AppNotificationType.record:
      return [
        _bold(name),
        _plain(' bije rekord: '),
        _bold(formatNotificationRecord(n.record), AppColors.record),
      ];
  }
}

String _nameOf(FeedAuthor author) =>
    author.firstName.isNotEmpty ? author.firstName : author.handle;

/// `Martwy ciąg 120 kg × 3`, bez ciężaru `Podciąganie 15 powt.`
String formatNotificationRecord(NotificationRecord? record) {
  if (record == null) return 'nowy rekord';
  final weight = record.weightKg;
  final reps = record.reps;
  final value = weight != null
      ? formatWeightWithUnit(weight) + (reps != null ? ' × $reps' : '')
      : reps != null
      ? '$reps powt.'
      : null;
  return value == null ? record.exerciseName : '${record.exerciseName} $value';
}

/// `teraz`, `12 min temu`, `3 godz. temu`, `wczoraj`, `pon, 12 paź`,
/// spoza bieżącego roku `12 paź 2025`.
String formatNotificationTime(DateTime at, {DateTime? now}) {
  final local = at.toLocal();
  final current = (now ?? DateTime.now()).toLocal();
  final diff = current.difference(local);
  if (diff.inMinutes < 1) return 'teraz';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min temu';
  final days = DateTime.utc(
    current.year,
    current.month,
    current.day,
  ).difference(DateTime.utc(local.year, local.month, local.day)).inDays;
  if (days <= 0) return '${diff.inHours} godz. temu';
  if (days == 1) return 'wczoraj';
  final date = '${local.day} ${formatMonthShort(local)}';
  if (local.year != current.year) return '$date ${local.year}';
  return '${formatWeekdayShort(local)}, $date';
}
