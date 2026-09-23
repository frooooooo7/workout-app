import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../domain/models/profile_details.dart';
import '../utils/profile_details_draft.dart';
import '../utils/profile_details_labels.dart';

const profileBirthDateFieldKey = Key('profile-details-birth-date');
const profileHeightFieldKey = Key('profile-details-height');
const profileWeightFieldKey = Key('profile-details-weight');

/// Płeć, data urodzenia, wzrost i waga. Pola tekstowe startują z [draft]
/// z chwili zbudowania; dalej źródłem prawdy są callbacki.
class ProfileBodyFields extends StatefulWidget {
  const ProfileBodyFields({
    super.key,
    required this.draft,
    required this.onGenderChanged,
    required this.onBirthDateChanged,
    required this.onHeightChanged,
    required this.onWeightChanged,
    this.enabled = true,
  });

  final ProfileDetailsDraft draft;
  final ValueChanged<Gender?> onGenderChanged;
  final ValueChanged<String> onBirthDateChanged;
  final ValueChanged<String> onHeightChanged;
  final ValueChanged<String> onWeightChanged;
  final bool enabled;

  @override
  State<ProfileBodyFields> createState() => _ProfileBodyFieldsState();
}

class _ProfileBodyFieldsState extends State<ProfileBodyFields> {
  late final _birthDateController = TextEditingController(
    text: widget.draft.birthDateText,
  );
  late final _heightController = TextEditingController(
    text: widget.draft.heightText,
  );
  late final _weightController = TextEditingController(
    text: widget.draft.weightText,
  );

  @override
  void dispose() {
    _birthDateController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final age = draft.age;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const ProfileFieldLabel(label: 'Płeć'),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            for (final gender in Gender.values) ...[
              if (gender != Gender.values.first)
                const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _ChoicePill(
                  label: gender.label,
                  selected: draft.gender == gender,
                  enabled: widget.enabled,
                  onTap: () => widget.onGenderChanged(
                    draft.gender == gender ? null : gender,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        const ProfileFieldLabel(label: 'Data urodzenia'),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          key: profileBirthDateFieldKey,
          controller: _birthDateController,
          enabled: widget.enabled,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          inputFormatters: [BirthDateInputFormatter()],
          onChanged: widget.onBirthDateChanged,
          style: _inputStyle,
          decoration: InputDecoration(
            hintText: 'DD.MM.RRRR',
            prefixIcon: const Icon(
              Icons.cake_outlined,
              color: AppColors.textMuted,
              size: 20,
            ),
            suffixText: age == null ? null : formatAge(age),
            suffixStyle: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
            errorText: draft.birthDateError,
            errorMaxLines: 2,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const ProfileFieldLabel(label: 'Wzrost i waga'),
        const SizedBox(height: AppSpacing.xs),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                key: profileHeightFieldKey,
                controller: _heightController,
                enabled: widget.enabled,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(3),
                ],
                onChanged: widget.onHeightChanged,
                style: _inputStyle,
                decoration: InputDecoration(
                  hintText: 'Wzrost',
                  prefixIcon: const Icon(
                    Icons.height_rounded,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                  suffixText: 'cm',
                  errorText: draft.heightError,
                  errorMaxLines: 3,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: TextField(
                key: profileWeightFieldKey,
                controller: _weightController,
                enabled: widget.enabled,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.done,
                inputFormatters: [_WeightInputFormatter()],
                onChanged: widget.onWeightChanged,
                style: _inputStyle,
                decoration: InputDecoration(
                  hintText: 'Waga',
                  prefixIcon: const Icon(
                    Icons.monitor_weight_outlined,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                  suffixText: 'kg',
                  errorText: draft.weightError,
                  errorMaxLines: 3,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Cel, poziom zaawansowania i dni treningowe w tygodniu.
class ProfileGoalFields extends StatelessWidget {
  const ProfileGoalFields({
    super.key,
    required this.draft,
    required this.onGoalChanged,
    required this.onLevelChanged,
    required this.onWeeklyDaysChanged,
    this.enabled = true,
  });

  final ProfileDetailsDraft draft;
  final ValueChanged<TrainingGoal?> onGoalChanged;
  final ValueChanged<ExperienceLevel?> onLevelChanged;
  final ValueChanged<int?> onWeeklyDaysChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final level = draft.experienceLevel;
    final goals = TrainingGoal.values;

    Widget goalCard(TrainingGoal goal) => _GoalCard(
          goal: goal,
          selected: draft.trainingGoal == goal,
          enabled: enabled,
          onTap: () =>
              onGoalChanged(draft.trainingGoal == goal ? null : goal),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const ProfileFieldLabel(label: 'Cel'),
        const SizedBox(height: AppSpacing.xs),
        for (var row = 0; row < goals.length; row += 2) ...[
          if (row > 0) const SizedBox(height: AppSpacing.xs),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: goalCard(goals[row])),
                const SizedBox(width: AppSpacing.xs),
                Expanded(child: goalCard(goals[row + 1])),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        const ProfileFieldLabel(label: 'Doświadczenie'),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            for (final option in ExperienceLevel.values) ...[
              if (option != ExperienceLevel.values.first)
                const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _ChoicePill(
                  label: _shortLevelLabel(option),
                  selected: level == option,
                  enabled: enabled,
                  onTap: () => onLevelChanged(level == option ? null : option),
                ),
              ),
            ],
          ],
        ),
        if (level != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${level.label} · ${level.description}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        const ProfileFieldLabel(label: 'Treningi w tygodniu'),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            for (var days = 1; days <= kMaxWeeklyTrainingDays; days++) ...[
              if (days > 1) const SizedBox(width: 6),
              Expanded(
                child: _ChoicePill(
                  label: '$days',
                  semanticsLabel: formatWeeklyTrainingDays(days),
                  selected: draft.weeklyTrainingDays == days,
                  enabled: enabled,
                  onTap: () => onWeeklyDaysChanged(
                    draft.weeklyTrainingDays == days ? null : days,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  static String _shortLevelLabel(ExperienceLevel level) => switch (level) {
        ExperienceLevel.intermediate => 'Średni',
        _ => level.label,
      };
}

/// „Widzisz to tylko Ty” — przy danych o sobie i celu.
class ProfileDetailsPrivacyNote extends StatelessWidget {
  const ProfileDetailsPrivacyNote({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(Icons.lock_outline_rounded, color: AppColors.textMuted, size: 16),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Widzisz to tylko Ty — nie pokazujemy tych danych innym.',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

/// Etykieta sekcji formularza (wielkie litery, wyciszona).
class ProfileFieldLabel extends StatelessWidget {
  const ProfileFieldLabel({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: AppColors.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      ),
    );
  }
}

/// Wpisywanie daty jako `DD.MM.RRRR` — kropki dostawiane automatycznie.
class BirthDateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 8) digits = digits.substring(0, 8);

    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 2 || i == 4) buffer.write('.');
      buffer.write(digits[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Do 3 cyfr i jedna cyfra po przecinku/kropce.
class _WeightInputFormatter extends TextInputFormatter {
  static final _pattern = RegExp(r'^\d{0,3}([.,]\d?)?$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return _pattern.hasMatch(newValue.text) ? newValue : oldValue;
  }
}

const _inputStyle = TextStyle(color: AppColors.textPrimary, fontSize: 15);

class _ChoicePill extends StatelessWidget {
  const _ChoicePill({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.semanticsLabel,
  });

  final String label;
  final String? semanticsLabel;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: semanticsLabel,
      excludeSemantics: semanticsLabel != null,
      child: AppPressable(
        onTap: enabled ? onTap : null,
        pressedScale: 0.97,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: AppSpacing.minTapTarget,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.16)
                : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final TrainingGoal goal;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: AppPressable(
        onTap: enabled ? onTap : null,
        pressedScale: 0.97,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.12)
                : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(
                    alpha: selected ? 0.28 : 0.14,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(goal.icon, color: AppColors.primaryVariant, size: 18),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                goal.label,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                goal.description,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
