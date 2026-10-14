import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/plan_colors.dart';
import '../../../../core/theme/plan_icons.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_pressable.dart';

/// Wybór wyglądu planu: kolor (albo „Auto” z nazwy) i znak — litera lub
/// ikona — z podglądem karty planu na żywo.
class PlanAppearanceScreen extends StatefulWidget {
  const PlanAppearanceScreen({
    super.key,
    required this.planName,
    required this.subtitle,
    required this.selectedDays,
    this.colorKey,
    this.iconKey,
  });

  final String planName;

  /// „Klatka · Barki · Ramiona” pod nazwą w podglądzie.
  final String subtitle;
  final List<int> selectedDays;
  final String? colorKey;
  final String? iconKey;

  @override
  State<PlanAppearanceScreen> createState() => _PlanAppearanceScreenState();
}

class _PlanAppearanceScreenState extends State<PlanAppearanceScreen> {
  late String? _colorKey = widget.colorKey;
  late String? _iconKey = widget.iconKey;
  late bool _useIcon = widget.iconKey != null;

  Color get _color => _colorKey == null
      ? PlanColors.automatic(widget.planName)
      : PlanColors.choices[_colorKey]!;

  void _pickColor(String? key) {
    if (key == _colorKey) return;
    HapticFeedback.selectionClick();
    setState(() => _colorKey = key);
  }

  void _pickIcon(String key) {
    HapticFeedback.selectionClick();
    setState(() {
      _iconKey = key;
      _useIcon = true;
    });
  }

  void _setMode(bool useIcon) {
    if (useIcon == _useIcon) return;
    setState(() {
      _useIcon = useIcon;
      if (useIcon) _iconKey ??= PlanIcons.choices.keys.first;
    });
  }

  void _done() {
    Navigator.of(
      context,
    ).pop((colorKey: _colorKey, iconKey: _useIcon ? _iconKey : null));
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.planName.trim().isEmpty
        ? 'Nowy plan'
        : widget.planName.trim();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: 'Wygląd planu',
              onBack: () => Navigator.of(context).maybePop(),
              actions: [_DoneButton(onTap: _done)],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
                children: [
                  TweenAnimationBuilder<Color?>(
                    tween: ColorTween(end: _color),
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    builder: (context, color, _) => _Preview(
                      name: name,
                      subtitle: widget.subtitle,
                      days: widget.selectedDays,
                      color: color ?? _color,
                      iconKey: _useIcon ? _iconKey : null,
                    ),
                  ),
                  const SizedBox(height: 26),
                  _SectionLabel(
                    'KOLOR',
                    trailing: _colorKey == null
                        ? 'Auto'
                        : PlanColors.choiceLabels[_colorKey]!,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _Swatch(
                        key: const ValueKey('plan-color-auto'),
                        color: null,
                        label: 'Auto',
                        selected: _colorKey == null,
                        onTap: () => _pickColor(null),
                      ),
                      for (final entry in PlanColors.choices.entries)
                        _Swatch(
                          key: ValueKey('plan-color-${entry.key}'),
                          color: entry.value,
                          label: PlanColors.choiceLabels[entry.key]!,
                          selected: _colorKey == entry.key,
                          onTap: () => _pickColor(entry.key),
                        ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      const Expanded(child: _SectionLabel('ZNAK PLANU')),
                      _ModeToggle(useIcon: _useIcon, onChanged: _setMode),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _useIcon ? 1 : 0.45,
                    child: GridView.count(
                      crossAxisCount: 6,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      children: [
                        for (final entry in PlanIcons.choices.entries)
                          _IconTile(
                            key: ValueKey('plan-icon-${entry.key}'),
                            icon: entry.value,
                            label: PlanIcons.labels[entry.key]!,
                            selected: _useIcon && _iconKey == entry.key,
                            color: _color,
                            onTap: () => _pickIcon(entry.key),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DoneButton extends StatelessWidget {
  const _DoneButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: AppPressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          key: const ValueKey('plan-appearance-done'),
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: const Text(
            'Gotowe',
            style: TextStyle(
              color: Color(0xFF8FB2FF),
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.trailing});

  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(text, style: AppTextStyles.eyebrow)),
        if (trailing != null)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Text(
              trailing!,
              key: ValueKey(trailing),
              style: const TextStyle(
                color: AppColors.textSubtle,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

/// Karta planu tak, jak będzie wyglądać: znak, nazwa, dni i przycisk startu
/// w wybranym kolorze.
class _Preview extends StatelessWidget {
  const _Preview({
    required this.name,
    required this.subtitle,
    required this.days,
    required this.color,
    required this.iconKey,
  });

  final String name;
  final String subtitle;
  final List<int> days;
  final Color color;
  final String? iconKey;

  static const _dayLetters = ['P', 'W', 'Ś', 'C', 'P', 'S', 'N'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderStrong),
        gradient: RadialGradient(
          center: const Alignment(0.9, -1),
          radius: 1.1,
          colors: [color.withValues(alpha: 0.16), AppColors.surface],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('PODGLĄD', style: AppTextStyles.eyebrow),
          const SizedBox(height: 12),
          Row(
            children: [
              PlanBadge(
                name: name,
                color: color,
                iconKey: iconKey,
                size: 48,
                radius: AppRadius.md,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var day = 1; day <= 7; day++)
                _DayDot(
                  letter: _dayLetters[day - 1],
                  planned: days.contains(day),
                  color: color,
                ),
            ],
          ),
          const SizedBox(height: 16),
          ExcludeSemantics(
            child: Container(
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.play_arrow_rounded,
                    size: 20,
                    color: PlanColors.onAccent(color),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Rozpocznij $name',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: PlanColors.onAccent(color),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({
    required this.letter,
    required this.planned,
    required this.color,
  });

  final String letter;
  final bool planned;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(letter, style: AppTextStyles.caption.copyWith(fontSize: 11)),
        const SizedBox(height: 6),
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: planned ? color.withValues(alpha: 0.18) : null,
            border: Border.all(
              color: planned ? color : AppColors.borderStrong,
              width: planned ? 2 : 1,
            ),
          ),
          child: planned
              ? Center(
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                    ),
                  ),
                )
              : null,
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    super.key,
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  /// `null` — „Auto”.
  final Color? color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = this.color;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Kolor: $label',
      excludeSemantics: true,
      child: AppPressable(
        onTap: onTap,
        pressedScale: 0.9,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          width: 44,
          height: 44,
          padding: EdgeInsets.all(selected ? 3 : 0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? (color ?? AppColors.textPrimary)
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color ?? AppColors.tile,
              border: color == null
                  ? Border.all(color: AppColors.borderStrong)
                  : null,
            ),
            alignment: Alignment.center,
            child: color == null
                ? const Text(
                    'Auto',
                    style: TextStyle(
                      color: AppColors.textSubtle,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : AnimatedScale(
                    scale: selected ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutBack,
                    child: Icon(
                      Icons.check_rounded,
                      size: 20,
                      color: PlanColors.onAccent(color),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.useIcon, required this.onChanged});

  final bool useIcon;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget option(String label, bool value) {
      final selected = useIcon == value;
      return Semantics(
        button: true,
        selected: selected,
        child: GestureDetector(
          key: ValueKey('plan-mark-${value ? 'icon' : 'letter'}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.surfaceVariant : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              label,
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
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.tile,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [option('Litera', false), option('Ikona', true)],
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Ikona: $label',
      excludeSemantics: true,
      child: AppPressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.tile),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.16) : AppColors.tile,
            borderRadius: BorderRadius.circular(AppRadius.tile),
            border: Border.all(
              color: selected ? color : AppColors.borderStrong,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Icon(
            icon,
            size: 22,
            color: selected ? color : AppColors.iconOnTile,
          ),
        ),
      ),
    );
  }
}
