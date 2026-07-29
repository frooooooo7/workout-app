enum RecentActivityKind { strength }

class RecentActivity {
  const RecentActivity({
    required this.kind,
    required this.title,
    required this.date,
    required this.duration,
    this.detail,
  });

  final RecentActivityKind kind;
  final String title;
  final String date;
  final String duration;
  final String? detail;
}
