import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

enum PasswordStrength { none, weak, medium, strong }

class PasswordStrengthBar extends StatelessWidget {
  const PasswordStrengthBar({super.key, required this.strength});

  final PasswordStrength strength;

  Color get _color => switch (strength) {
        PasswordStrength.weak => AppColors.strengthWeak,
        PasswordStrength.medium => AppColors.strengthMedium,
        PasswordStrength.strong => AppColors.strengthStrong,
        PasswordStrength.none => AppColors.border,
      };

  String get _label => switch (strength) {
        PasswordStrength.weak => 'Słabe',
        PasswordStrength.medium => 'Średnie',
        PasswordStrength.strong => 'Silne',
        PasswordStrength.none => '',
      };

  double get _progress => switch (strength) {
        PasswordStrength.none => 0.0,
        PasswordStrength.weak => 0.33,
        PasswordStrength.medium => 0.66,
        PasswordStrength.strong => 1.0,
      };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _progress,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(_color),
              minHeight: 4,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          _label,
          style: TextStyle(
            color: _color,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class PasswordRequirementsCard extends StatelessWidget {
  const PasswordRequirementsCard({
    super.key,
    required this.hasMinLength,
    required this.hasUpperCase,
    required this.hasDigit,
  });

  final bool hasMinLength;
  final bool hasUpperCase;
  final bool hasDigit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          PasswordRequirementRow(label: 'Minimum 8 znaków', met: hasMinLength),
          const SizedBox(height: 8),
          PasswordRequirementRow(
            label: 'Jedna wielka litera',
            met: hasUpperCase,
          ),
          const SizedBox(height: 8),
          PasswordRequirementRow(label: 'Jedna cyfra', met: hasDigit),
        ],
      ),
    );
  }
}

class PasswordRequirementRow extends StatelessWidget {
  const PasswordRequirementRow({
    super.key,
    required this.label,
    required this.met,
  });

  final String label;
  final bool met;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          met
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          color: met ? AppColors.success : AppColors.textMuted,
          size: 18,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: met ? AppColors.textPrimary : AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

PasswordStrength passwordStrengthFor(String password) {
  final hasMinLength = password.length >= 8;
  final hasUpperCase = password.contains(RegExp(r'[A-Z]'));
  final hasDigit = password.contains(RegExp(r'[0-9]'));
  final score =
      [hasMinLength, hasUpperCase, hasDigit].where((v) => v).length;
  if (score == 3) return PasswordStrength.strong;
  if (score == 2) return PasswordStrength.medium;
  if (score == 1) return PasswordStrength.weak;
  return PasswordStrength.none;
}
