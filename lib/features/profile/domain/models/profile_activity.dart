import 'recent_activity.dart';
import 'profile_activity_stat.dart';

class ProfileActivity {
  const ProfileActivity({
    this.id,
    required this.kind,
    required this.title,
    required this.date,
    required this.duration,
    this.detail,
    this.timeLabel,
    this.stats = const [],
    this.kudosCount = 0,
    this.commentCount = 0,
    this.hasKudoed = false,
  });

  final String? id;
  final RecentActivityKind kind;
  final String title;
  final String date;
  final String duration;
  final String? detail;
  final String? timeLabel;
  final List<ProfileActivityStat> stats;
  final int kudosCount;
  final int commentCount;

  /// Zalogowany użytkownik dał kudosa tej aktywności.
  final bool hasKudoed;

  String get timestampLabel {
    if (timeLabel != null && timeLabel!.isNotEmpty) {
      return '$date · $timeLabel';
    }
    return date;
  }
}
