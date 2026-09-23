import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../domain/models/profile_details.dart';
import '../utils/profile_details_draft.dart';
import '../utils/profile_details_labels.dart';
import 'birth_date_sheet.dart';
import 'ruler_picker.dart';

const profileBirthDateTileKey = Key('profile-details-birth-date');
const profileHeightRulerKey = Key('profile-details-height');
const profileWeightRulerKey = Key('profile-details-weight');

Key profileGenderOptionKey(Gender gender) =>
    ValueKey('profile-gender-${gender.name}');
Key profileGoalOptionKey(TrainingGoal goal) =>
    ValueKey('profile-goal-${goal.name}');
Key profileLevelOptionKey(ExperienceLevel level) =>
    ValueKey('profile-level-${level.name}');
Key profileWeeklyDaysOptionKey(int days) => ValueKey('profile-days-$days');

const _sectionGap = 28.0;
const _labelGap = 10.0;

/// Płeć, data urodzenia, wzrost i waga.
class ProfileBodyFields extends StatelessWidget {
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
  final ValueChanged<DateTime?> onBirthDateChanged;
  final ValueChanged<int?> onHeightChanged;
  final ValueChanged<double?> onWeightChanged;
  final bool enabled;

  Future<void> _pickBirthDate(BuildContext context) async {
    final result = await showBirthDateSheet(context, initial: draft.birthDate);
    if (result != null) onBirthDateChanged(result.date);
  }

  @override
  Widget build(BuildContext context) {
    final gender = draft.gender;
    // Punkt startowy linijek — typowe wartości dla wybranej płci.
    final heightStart = switch (gender) {
      Gender.female => 165.0,
      Gender.male => 178.0,
      _ => 172.0,
    };
    final weightStart = switch (gender) {
      Gender.female => 62.0,
      Gender.male => 80.0,
      _ => 72.0,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const ProfileFieldLabel(label: 'Płeć'),
        const SizedBox(height: _labelGap),
        _SegmentedChoice<Gender>(
          values: Gender.values,
          selected: gender,
          enabled: enabled,
          labelOf: (g) => g.label,
          keyOf: profileGenderOptionKey,
          onChanged: onGenderChanged,
        ),
        const SizedBox(height: _sectionGap),
        const ProfileFieldLabel(label: 'Data urodzenia'),
        const SizedBox(height: _labelGap),
        _BirthDateTile(
          date: draft.birthDate,
          age: draft.ageOn(DateTime.now()),
          enabled: enabled,
          onTap: () => _pickBirthDate(context),
        ),
        const SizedBox(height: _sectionGap),
        _MeasureCard(
          key: profileHeightRulerKey,
          label: 'Wzrost',
          unit: 'cm',
          valueText: draft.heightCm?.toString(),
          enabled: enabled,
          onClear: () => onHeightChanged(null),
          ruler: RulerPicker(
            min: kMinHeightCm.toDouble(),
            max: kMaxHeightCm.toDouble(),
            step: 1,
            initial: heightStart,
            value: draft.heightCm?.toDouble(),
            enabled: enabled,
            semanticsLabel: 'Wzrost',
            formatValue: (v) => formatHeightCm(v.round()),
            onChanged: (v) => onHeightChanged(v.round()),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _MeasureCard(
          key: profileWeightRulerKey,
          label: 'Waga',
          unit: 'kg',
          valueText: draft.weightKg == null
              ? null
              : formatWeightValue(draft.weightKg!),
          enabled: enabled,
          onClear: () => onWeightChanged(null),
          ruler: RulerPicker(
            min: kMinWeightKg,
            max: kMaxWeightKg,
            step: 0.1,
            majorEvery: 10,
            tickGap: 8,
            initial: weightStart,
            value: draft.weightKg,
            enabled: enabled,
            semanticsLabel: 'Waga',
            formatValue: formatWeightKg,
            onChanged: onWeightChanged,
          ),
        ),
      ],
    );
  }
}

/// Cel, doświadczenie i liczba treningów w tygodniu.
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
    final goal = draft.trainingGoal;
    final level = draft.experienceLevel;
    final days = draft.weeklyTrainingDays;
    final goals = TrainingGoal.values;

    Widget goalTile(TrainingGoal option) => _GoalTile(
      key: profileGoalOptionKey(option),
      goal: option,
      selected: goal == option,
      dimmed: goal != null && goal != option,
      enabled: enabled,
      onTap: () => onGoalChanged(goal == option ? null : option),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const ProfileFieldLabel(label: 'Cel'),
        const SizedBox(height: _labelGap),
        for (var row = 0; row < goals.length; row += 2) ...[
          if (row > 0) const SizedBox(height: AppSpacing.sm),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: goalTile(goals[row])),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: goalTile(goals[row + 1])),
              ],
            ),
          ),
        ],
        const SizedBox(height: _sectionGap),
        const ProfileFieldLabel(label: 'Doświadczenie'),
        const SizedBox(height: _labelGap),
        Row(
          children: [
            for (final option in ExperienceLevel.values) ...[
              if (option != ExperienceLevel.values.first)
                const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _LevelTile(
                  key: profileLevelOptionKey(option),
                  level: option,
                  selected: level == option,
                  enabled: enabled,
                  onTap: () => onLevelChanged(level == option ? null : option),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        _Caption(
          text: level == null
              ? 'Pomoże dobrać ciężary i objętość.'
              : level.description,
        ),
        const SizedBox(height: _sectionGap),
        const ProfileFieldLabel(label: 'Treningi w tygodniu'),
        const SizedBox(height: _labelGap),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var d = 1; d <= kMaxWeeklyTrainingDays; d++)
              _DayCircle(
                key: profileWeeklyDaysOptionKey(d),
                days: d,
                selected: days == d,
                enabled: enabled,
                onTap: () => onWeeklyDaysChanged(days == d ? null : d),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        _Caption(
          text: days == null
              ? 'Ile dni w tygodniu chcesz trenować?'
              : formatWeeklyTrainingsLong(days),
        ),
      ],
    );
  }
}

/// Etykieta sekcji formularza (wielkie litery, szeroki odstęp).
class ProfileFieldLabel extends StatelessWidget {
  const ProfileFieldLabel({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      ),
    );
  }
}

/// „Widzisz to tylko Ty” — przy danych o sobie i celu.
class ProfileDetailsPrivacyNote extends StatelessWidget {
  const ProfileDetailsPrivacyNote({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(
          Icons.lock_outline_rounded,
          color: AppColors.textSecondary,
          size: 15,
        ),
        SizedBox(width: 6),
        Expanded(
          child: Text(
            'Widzisz to tylko Ty — nie pokazujemy tego innym.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 160),
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topLeft,
        children: [...previous, ?current],
      ),
      child: Text(
        text,
        key: ValueKey(text),
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
          height: 1.4,
        ),
      ),
    );
  }
}

/// Jedna pigułka z przesuwanym wskaźnikiem wyboru; ponowne stuknięcie
/// odznacza.
class _SegmentedChoice<T> extends StatelessWidget {
  const _SegmentedChoice({
    required this.values,
    required this.selected,
    required this.enabled,
    required this.labelOf,
    required this.keyOf,
    required this.onChanged,
  });

  final List<T> values;
  final T? selected;
  final bool enabled;
  final String Function(T value) labelOf;
  final Key Function(T value) keyOf;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = selected == null ? -1 : values.indexOf(selected as T);

    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segment = constraints.maxWidth / values.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                left: selectedIndex < 0 ? 0 : segment * selectedIndex,
                top: 0,
                bottom: 0,
                width: segment,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 160),
                  opacity: selectedIndex < 0 ? 0 : 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.85),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (final value in values)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: value == selected,
                        child: GestureDetector(
                          key: keyOf(value),
                          behavior: HitTestBehavior.opaque,
                          onTap: enabled
                              ? () =>
                                    onChanged(value == selected ? null : value)
                              : null,
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 160),
                              style: TextStyle(
                                fontFamily: DefaultTextStyle.of(
                                  context,
                                ).style.fontFamily,
                                color: value == selected
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                                fontSize: 14,
                                fontWeight: value == selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                              child: Text(labelOf(value), maxLines: 1),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BirthDateTile extends StatelessWidget {
  const _BirthDateTile({
    required this.date,
    required this.age,
    required this.enabled,
    required this.onTap,
  });

  final DateTime? date;
  final int? age;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasDate = date != null;
    return Semantics(
      button: true,
      label: hasDate
          ? 'Data urodzenia: ${formatBirthDate(date!)}, ${formatAge(age!)}'
          : 'Data urodzenia: nie podano',
      excludeSemantics: true,
      child: AppPressable(
        key: profileBirthDateTileKey,
        onTap: enabled ? onTap : null,
        pressedScale: 0.98,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const _IconBadge(icon: Icons.cake_outlined),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  hasDate ? formatBirthDate(date!) : 'Wybierz datę',
                  style: TextStyle(
                    color: hasDate
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontSize: 16,
                    fontWeight: hasDate ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (hasDate)
                _Pill(text: formatAge(age!))
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MeasureCard extends StatelessWidget {
  const _MeasureCard({
    super.key,
    required this.label,
    required this.unit,
    required this.valueText,
    required this.enabled,
    required this.onClear,
    required this.ruler,
  });

  final String label;
  final String unit;
  final String? valueText;
  final bool enabled;
  final VoidCallback onClear;
  final Widget ruler;

  @override
  Widget build(BuildContext context) {
    final hasValue = valueText != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: AppSpacing.minTapTarget,
            child: Row(
              children: [
                ProfileFieldLabel(label: label),
                const Spacer(),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 160),
                  opacity: hasValue ? 1 : 0,
                  child: TextButton(
                    onPressed: hasValue && enabled ? onClear : null,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      minimumSize: const Size(0, AppSpacing.minTapTarget),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('Wyczyść'),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  valueText ?? '—',
                  style: TextStyle(
                    color: hasValue
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                    fontSize: 44,
                    // Pusta wartość: cienka kreska zamiast grubej belki.
                    fontWeight: hasValue ? FontWeight.w800 : FontWeight.w300,
                    letterSpacing: -1.2,
                    height: 1.05,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  unit,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10, top: 2),
            child: Text(
              hasValue ? ' ' : 'Przesuń linijkę, aby ustawić',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          Padding(padding: const EdgeInsets.only(right: 10), child: ruler),
        ],
      ),
    );
  }
}

class _GoalTile extends StatelessWidget {
  const _GoalTile({
    super.key,
    required this.goal,
    required this.selected,
    required this.dimmed,
    required this.enabled,
    required this.onTap,
  });

  final TrainingGoal goal;
  final bool selected;
  final bool dimmed;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${goal.label}. ${goal.description}',
      excludeSemantics: true,
      child: AppPressable(
        onTap: enabled ? onTap : null,
        pressedScale: 0.97,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 2 : 1,
            ),
            boxShadow: [
              if (selected)
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.28),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xl - 1),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: dimmed ? 0.55 : 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AspectRatio(
                    aspectRatio: 1.15,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _GoalArt(goal: goal),
                        // Obraz przechodzi w tło karty pod podpisem.
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, AppColors.surface],
                              stops: [0.62, 1],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: AnimatedScale(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutBack,
                            scale: selected ? 1 : 0,
                            child: const _CheckBadge(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 2, 12, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goal.label,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          goal.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ilustracja celu; bez pliku — ikona na granatowej poświacie.
class _GoalArt extends StatelessWidget {
  const _GoalArt({required this.goal});

  final TrainingGoal goal;

  @override
  Widget build(BuildContext context) {
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.1),
          radius: 0.85,
          colors: [
            AppColors.primary.withValues(alpha: 0.30),
            AppColors.heroGlow,
            AppColors.surface,
          ],
          stops: const [0, 0.5, 1],
        ),
      ),
      child: Center(
        child: Icon(goal.icon, size: 40, color: AppColors.primaryVariant),
      ),
    );

    return Image.asset(
      goal.imageAsset,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({
    super.key,
    required this.level,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final ExperienceLevel level;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: level.label,
      excludeSemantics: true,
      child: AppPressable(
        onTap: enabled ? onTap : null,
        pressedScale: 0.97,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: 84,
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.16)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LevelBars(rank: level.rank, active: selected),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    level.shortLabel,
                    maxLines: 1,
                    style: TextStyle(
                      color: selected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Trzy rosnące kreski — ile z nich wypełnionych, taki poziom.
class _LevelBars extends StatelessWidget {
  const _LevelBars({required this.rank, required this.active});

  final int rank;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final on = active ? AppColors.primaryVariant : AppColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 1; i <= 3; i++) ...[
          if (i > 1) const SizedBox(width: 3),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 6,
            height: 8.0 + (i - 1) * 6,
            decoration: BoxDecoration(
              color: i <= rank ? on : AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ],
    );
  }
}

class _DayCircle extends StatelessWidget {
  const _DayCircle({
    super.key,
    required this.days,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final int days;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: formatWeeklyTrainingDays(days),
      excludeSemantics: true,
      child: AppPressable(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: AppSpacing.minTapTarget,
          height: AppSpacing.minTapTarget,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? AppColors.primary : AppColors.surface,
            border: Border.all(
              color: selected ? AppColors.primaryVariant : AppColors.border,
            ),
            boxShadow: [
              if (selected)
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.45),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Text(
            '$days',
            style: TextStyle(
              color: selected ? AppColors.onPrimary : AppColors.textSecondary,
              fontSize: 16,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Icon(icon, color: AppColors.primaryVariant, size: 20),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.primaryVariant,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CheckBadge extends StatelessWidget {
  const _CheckBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.surface, width: 2),
      ),
      child: const Icon(
        Icons.check_rounded,
        color: AppColors.onPrimary,
        size: 15,
      ),
    );
  }
}
