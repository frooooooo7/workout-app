import 'package:flutter/material.dart';
import '../../domain/onboarding_data.dart';
import '../widgets/onboarding_scaffold.dart';
import '../../../../core/theme/app_colors.dart';
import 'onboarding_body_screen.dart';

class OnboardingAgeScreen extends StatefulWidget {
  const OnboardingAgeScreen({super.key, required this.data});

  final OnboardingData data;

  @override
  State<OnboardingAgeScreen> createState() => _OnboardingAgeScreenState();
}

class _OnboardingAgeScreenState extends State<OnboardingAgeScreen> {
  static const int _minAge = 14;
  static const int _maxAge = 99;
  static const int _itemCount = _maxAge - _minAge + 1;

  late final FixedExtentScrollController _controller;
  late int _selectedAge;

  @override
  void initState() {
    super.initState();
    _selectedAge = widget.data.age ?? 25;
    _controller = FixedExtentScrollController(
      initialItem: _selectedAge - _minAge,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleNext() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => OnboardingBodyScreen(
        data: widget.data.copyWith(age: _selectedAge),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      step: 2,
      totalSteps: 6,
      title: 'Ile masz lat?',
      subtitle: 'Wiek pomaga nam dobrać odpowiednią intensywność treningu.',
      onBack: () => Navigator.of(context).pop(),
      onSkip: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => OnboardingBodyScreen(data: widget.data),
      )),
      onNext: _handleNext,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _AgeDisplay(age: _selectedAge),
          const SizedBox(height: 32),
          _AgePicker(
            controller: _controller,
            itemCount: _itemCount,
            minAge: _minAge,
            onChanged: (idx) => setState(() => _selectedAge = _minAge + idx),
          ),
          const SizedBox(height: 16),
          Text(
            'lat',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _AgeDisplay extends StatelessWidget {
  const _AgeDisplay({required this.age});

  final int age;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$age',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 72,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'lat',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 20,
          ),
        ),
      ],
    );
  }
}

class _AgePicker extends StatelessWidget {
  const _AgePicker({
    required this.controller,
    required this.itemCount,
    required this.minAge,
    required this.onChanged,
  });

  final FixedExtentScrollController controller;
  final int itemCount;
  final int minAge;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
            ),
          ),
          ListWheelScrollView.useDelegate(
            controller: controller,
            itemExtent: 52,
            perspective: 0.003,
            diameterRatio: 1.6,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: onChanged,
            childDelegate: ListWheelChildBuilderDelegate(
              builder: (context, index) {
                if (index < 0 || index >= itemCount) return null;
                final age = minAge + index;
                final isSelected = controller.hasClients &&
                    controller.selectedItem == index;
                return Center(
                  child: Text(
                    '$age',
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textMuted,
                      fontSize: isSelected ? 26 : 20,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                );
              },
              childCount: itemCount,
            ),
          ),
        ],
      ),
    );
  }
}
