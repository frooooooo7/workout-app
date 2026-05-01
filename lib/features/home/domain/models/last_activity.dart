import 'recent_activity.dart';

/// Szczegóły ostatniej aktywności wyświetlanej na karcie głównej.
sealed class LastActivity {
  const LastActivity({
    required this.kind,
    required this.title,
    required this.date,
    required this.time,
    required this.durationLabel,
  });

  final RecentActivityKind kind;
  final String title;

  /// Np. "Dzisiaj", "Wczoraj", "29 kwi"
  final String date;

  /// Godzina startu, np. "18:32"
  final String time;

  /// Czas trwania sformatowany, np. "1:15:24"
  final String durationLabel;
}

/// Trening siłowy – objętość [kg] + kalorie [kcal].
class StrengthActivity extends LastActivity {
  const StrengthActivity({
    required super.title,
    required super.date,
    required super.time,
    required super.durationLabel,
    required this.volumeKg,
    required this.caloriesKcal,
  }) : super(kind: RecentActivityKind.strength);

  final int volumeKg;
  final int caloriesKcal;
}

/// Cardio (bieg, rower…) – dystans [km] + średni puls [bpm].
class CardioActivity extends LastActivity {
  const CardioActivity({
    required super.kind,
    required super.title,
    required super.date,
    required super.time,
    required super.durationLabel,
    required this.distanceKm,
    required this.avgPulseBpm,
  });

  final double distanceKm;
  final int avgPulseBpm;
}
