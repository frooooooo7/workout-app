import 'package:flutter/material.dart';

import '../../../../core/units/weight_unit.dart';
import '../../domain/models/profile_details.dart';
import '../utils/profile_details_labels.dart';
import 'ruler_picker.dart';

/// Linijka masy ciała w aktualnej jednostce. [value], [initial] i
/// [onChanged] są zawsze w kilogramach.
///
/// W kilogramach kreska co 0,1 kg; w funtach co 1 lb — masa ciała leży w
/// bazie z dokładnością do 0,1 kg, więc drobniejszy krok i tak by nie wrócił.
class BodyWeightRuler extends StatelessWidget {
  const BodyWeightRuler({
    super.key,
    required this.initial,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final double initial;
  final double? value;
  final ValueChanged<double> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final unit = WeightUnits.current;
    if (unit == WeightUnit.kg) {
      return RulerPicker(
        min: kMinWeightKg,
        max: kMaxWeightKg,
        step: 0.1,
        majorEvery: 10,
        tickGap: 8,
        initial: initial,
        value: value,
        enabled: enabled,
        semanticsLabel: 'Waga',
        formatValue: formatWeightKg,
        onChanged: onChanged,
      );
    }
    double toLb(double kg) => unit.fromKg(kg).roundToDouble();
    final range = bodyWeightRange(unit);
    return RulerPicker(
      min: range.min,
      max: range.max,
      step: 1,
      majorEvery: 10,
      tickGap: 8,
      initial: toLb(initial),
      value: value == null ? null : toLb(value!),
      enabled: enabled,
      semanticsLabel: 'Waga',
      formatValue: (lb) => '${lb.round()} ${unit.label}',
      onChanged: (lb) => onChanged((unit.toKg(lb) * 10).round() / 10),
    );
  }
}
