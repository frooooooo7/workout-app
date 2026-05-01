import 'package:flutter/material.dart';
import '../../domain/onboarding_data.dart';
import '../widgets/onboarding_scaffold.dart';
import '../../../../core/theme/app_colors.dart';
import 'onboarding_activity_screen.dart';

class OnboardingBodyScreen extends StatefulWidget {
  const OnboardingBodyScreen({super.key, required this.data});

  final OnboardingData data;

  @override
  State<OnboardingBodyScreen> createState() => _OnboardingBodyScreenState();
}

class _OnboardingBodyScreenState extends State<OnboardingBodyScreen> {
  late bool _metricHeight;
  late bool _metricWeight;

  // cm values internally, always
  late double _heightCm;
  late double _weightKg;

  late FixedExtentScrollController _heightController;
  late FixedExtentScrollController _weightController;

  // Height ranges
  static const int _minHeightCm = 100;
  static const int _maxHeightCm = 250;
  static const int _minHeightFtInt = 3; // 3 ft
  static const int _maxHeightFtInt = 8; // 8 ft

  // Weight ranges
  static const int _minWeightKg = 30;
  static const int _maxWeightKg = 300;
  static const int _minWeightLb = 66;
  static const int _maxWeightLb = 661;

  int get _heightIndex {
    if (_metricHeight) {
      return (_heightCm.round() - _minHeightCm).clamp(0, _maxHeightCm - _minHeightCm);
    } else {
      final ft = (_heightCm / 30.48).round();
      return (ft - _minHeightFtInt).clamp(0, _maxHeightFtInt - _minHeightFtInt);
    }
  }

  int get _weightIndex {
    if (_metricWeight) {
      return (_weightKg.round() - _minWeightKg).clamp(0, _maxWeightKg - _minWeightKg);
    } else {
      final lb = (_weightKg * 2.20462).round();
      return (lb - _minWeightLb).clamp(0, _maxWeightLb - _minWeightLb);
    }
  }

  int get _heightItemCount =>
      _metricHeight ? _maxHeightCm - _minHeightCm + 1 : _maxHeightFtInt - _minHeightFtInt + 1;

  int get _weightItemCount =>
      _metricWeight ? _maxWeightKg - _minWeightKg + 1 : _maxWeightLb - _minWeightLb + 1;

  @override
  void initState() {
    super.initState();
    _metricHeight = widget.data.useMetricHeight;
    _metricWeight = widget.data.useMetricWeight;
    _heightCm = widget.data.heightCm ?? 175;
    _weightKg = widget.data.weightKg ?? 75;
    _heightController = FixedExtentScrollController(initialItem: _heightIndex);
    _weightController = FixedExtentScrollController(initialItem: _weightIndex);
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _onHeightChanged(int index) {
    setState(() {
      if (_metricHeight) {
        _heightCm = (_minHeightCm + index).toDouble();
      } else {
        _heightCm = ((_minHeightFtInt + index) * 30.48);
      }
    });
  }

  void _onWeightChanged(int index) {
    setState(() {
      if (_metricWeight) {
        _weightKg = (_minWeightKg + index).toDouble();
      } else {
        _weightKg = ((_minWeightLb + index) / 2.20462);
      }
    });
  }

  void _toggleHeightUnit() {
    setState(() {
      _metricHeight = !_metricHeight;
      final newIndex = _heightIndex;
      _heightController.dispose();
      _heightController = FixedExtentScrollController(initialItem: newIndex);
    });
  }

  void _toggleWeightUnit() {
    setState(() {
      _metricWeight = !_metricWeight;
      final newIndex = _weightIndex;
      _weightController.dispose();
      _weightController = FixedExtentScrollController(initialItem: newIndex);
    });
  }

  String get _heightLabel {
    if (_metricHeight) {
      return '${_heightCm.round()} cm';
    } else {
      final totalInches = (_heightCm / 2.54).round();
      final ft = totalInches ~/ 12;
      final inch = totalInches % 12;
      return '$ft\'$inch"';
    }
  }

  String get _weightLabel {
    if (_metricWeight) {
      return '${_weightKg.round()} kg';
    } else {
      return '${(_weightKg * 2.20462).round()} lb';
    }
  }

  void _handleNext() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => OnboardingActivityScreen(
        data: widget.data.copyWith(
          heightCm: _heightCm,
          weightKg: _weightKg,
          useMetricHeight: _metricHeight,
          useMetricWeight: _metricWeight,
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      step: 3,
      totalSteps: 6,
      title: 'Twoje pomiary',
      subtitle: 'Wzrost i waga pomagają nam śledzić Twój progres.',
      onBack: () => Navigator.of(context).pop(),
      onSkip: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => OnboardingActivityScreen(data: widget.data),
      )),
      onNext: _handleNext,
      child: Row(
        children: [
          Expanded(
            child: _MeasurePicker(
              label: 'Wzrost',
              valueLabel: _heightLabel,
              unitA: 'cm',
              unitB: 'ft',
              isMetric: _metricHeight,
              onToggleUnit: _toggleHeightUnit,
              controller: _heightController,
              itemCount: _heightItemCount,
              onChanged: _onHeightChanged,
              buildItemLabel: (index) {
                if (_metricHeight) {
                  return '${_minHeightCm + index}';
                } else {
                  final ft = _minHeightFtInt + index;
                  return '$ft\'';
                }
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _MeasurePicker(
              label: 'Waga',
              valueLabel: _weightLabel,
              unitA: 'kg',
              unitB: 'lb',
              isMetric: _metricWeight,
              onToggleUnit: _toggleWeightUnit,
              controller: _weightController,
              itemCount: _weightItemCount,
              onChanged: _onWeightChanged,
              buildItemLabel: (index) {
                if (_metricWeight) {
                  return '${_minWeightKg + index}';
                } else {
                  return '${_minWeightLb + index}';
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MeasurePicker extends StatelessWidget {
  const _MeasurePicker({
    required this.label,
    required this.valueLabel,
    required this.unitA,
    required this.unitB,
    required this.isMetric,
    required this.onToggleUnit,
    required this.controller,
    required this.itemCount,
    required this.onChanged,
    required this.buildItemLabel,
  });

  final String label;
  final String valueLabel;
  final String unitA;
  final String unitB;
  final bool isMetric;
  final VoidCallback onToggleUnit;
  final FixedExtentScrollController controller;
  final int itemCount;
  final ValueChanged<int> onChanged;
  final String Function(int index) buildItemLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            valueLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          _UnitToggle(
            unitA: unitA,
            unitB: unitB,
            isA: isMetric,
            onToggle: onToggleUnit,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                ),
                ListWheelScrollView.useDelegate(
                  controller: controller,
                  itemExtent: 44,
                  perspective: 0.003,
                  diameterRatio: 1.4,
                  physics: const FixedExtentScrollPhysics(),
                  onSelectedItemChanged: onChanged,
                  childDelegate: ListWheelChildBuilderDelegate(
                    builder: (context, index) {
                      if (index < 0 || index >= itemCount) return null;
                      final isSel = controller.hasClients &&
                          controller.selectedItem == index;
                      return Center(
                        child: Text(
                          buildItemLabel(index),
                          style: TextStyle(
                            color:
                                isSel ? Colors.white : AppColors.textMuted,
                            fontSize: isSel ? 22 : 16,
                            fontWeight: isSel
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                      );
                    },
                    childCount: itemCount,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UnitToggle extends StatelessWidget {
  const _UnitToggle({
    required this.unitA,
    required this.unitB,
    required this.isA,
    required this.onToggle,
  });

  final String unitA;
  final String unitB;
  final bool isA;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            _UnitTab(label: unitA, active: isA),
            _UnitTab(label: unitB, active: !isA),
          ],
        ),
      ),
    );
  }
}

class _UnitTab extends StatelessWidget {
  const _UnitTab({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : AppColors.textMuted,
            fontSize: 12,
            fontWeight: active ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
