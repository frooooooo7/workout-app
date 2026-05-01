import 'recent_activity.dart';

/// Nadchodząca sesja z kalendarza użytkownika (placeholder do podpięcia API).
class ScheduledSession {
  const ScheduledSession({
    required this.kind,
    required this.title,
    required this.dateLabel,
    required this.time,
    this.partnerName,
    this.placeName,
  });

  final RecentActivityKind kind;
  final String title;

  /// Np. "Jutro", "Sob, 10 maj"
  final String dateLabel;

  /// Np. "18:30"
  final String time;

  /// Opcjonalnie: współuczestnik.
  final String? partnerName;

  /// Opcjonalnie: miejsce (siłownia, trasa).
  final String? placeName;
}
