import 'dart:ui';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/body_measurement_entry.dart';

/// Kierunek zmiany, który jest „w stronę celu”.
enum MeasurementGoal { lower, higher, none }

/// Ocena konkretnej zmiany pomiaru.
enum MeasurementTrend { good, bad, neutral }

/// Jedyne miejsce, które mówi, w którą stronę dany pomiar ma iść: talia,
/// biodra i tłuszcz w dół, mięśnie (ramię, klatka, udo, łydka) w górę,
/// szyja bez oceny.
extension BodyMeasurementGoal on BodyMeasurementField {
  MeasurementGoal get goal => switch (this) {
    BodyMeasurementField.waist ||
    BodyMeasurementField.hips ||
    BodyMeasurementField.bodyFat => MeasurementGoal.lower,
    BodyMeasurementField.chest ||
    BodyMeasurementField.arm ||
    BodyMeasurementField.thigh ||
    BodyMeasurementField.calf => MeasurementGoal.higher,
    BodyMeasurementField.neck => MeasurementGoal.none,
  };
}

/// Czy [change] pomiaru [field] idzie w stronę celu.
MeasurementTrend measurementTrend(BodyMeasurementField field, double change) {
  if (change == 0) return MeasurementTrend.neutral;
  return switch (field.goal) {
    MeasurementGoal.lower =>
      change < 0 ? MeasurementTrend.good : MeasurementTrend.bad,
    MeasurementGoal.higher =>
      change > 0 ? MeasurementTrend.good : MeasurementTrend.bad,
    MeasurementGoal.none => MeasurementTrend.neutral,
  };
}

extension MeasurementTrendColor on MeasurementTrend {
  /// Zielony — w stronę celu, czerwony — od celu, szary — bez zmiany.
  Color get color => switch (this) {
    MeasurementTrend.good => AppColors.success,
    MeasurementTrend.bad => AppColors.trendDown,
    MeasurementTrend.neutral => AppColors.textMuted,
  };
}
