/// Szczegóły ostatniego treningu wyświetlane na karcie głównej.
class LastActivity {
  const LastActivity({
    required this.title,
    required this.date,
    required this.time,
    required this.durationLabel,
    required this.volumeKg,
    required this.caloriesKcal,
    required this.exerciseCount,
  });

  final String title;

  /// Np. "Dzisiaj", "Wczoraj", "29 kwi"
  final String date;

  /// Godzina startu, np. "18:32"
  final String time;

  /// Czas trwania sformatowany, np. "1:15:24"
  final String durationLabel;

  final int volumeKg;
  final int caloriesKcal;
  final int exerciseCount;
}
