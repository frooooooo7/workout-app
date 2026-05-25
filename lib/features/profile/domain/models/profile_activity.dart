import '../../../home/domain/models/recent_activity.dart';
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

  String get timestampLabel {
    if (timeLabel != null && timeLabel!.isNotEmpty) {
      return '$date · $timeLabel';
    }
    return date;
  }
}
